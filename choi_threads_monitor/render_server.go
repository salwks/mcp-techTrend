package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"sort"
	"sync"
	"time"
)

type cacheState struct {
	mu      sync.Mutex
	at      time.Time
	body    []byte
	errText string
}

var cache cacheState
var archiveMu sync.Mutex
var archive = map[string]map[string]any{}

func rawPosts(payload any) []map[string]any {
	var src []any
	switch v := payload.(type) {
	case []any:
		src = v
	case map[string]any:
		for _, key := range []string{"posts", "items", "data", "results"} {
			if arr, ok := v[key].([]any); ok {
				src = arr
				break
			}
		}
		if src == nil {
			src = []any{v}
		}
	}
	out := make([]map[string]any, 0, len(src))
	for _, item := range src {
		if m, ok := item.(map[string]any); ok {
			out = append(out, m)
		}
	}
	return out
}

func pick(m map[string]any, keys ...string) any {
	for _, key := range keys {
		if v, ok := m[key]; ok && v != nil && fmt.Sprint(v) != "" {
			return v
		}
	}
	return nil
}

func rememberPosts(payload any, seenAt string) int {
	posts := rawPosts(payload)
	newCount := 0

	archiveMu.Lock()
	defer archiveMu.Unlock()

	for _, post := range posts {
		id := pick(post, "post_id", "id", "pk", "code")
		link := pick(post, "permalink", "url", "link")
		key := fmt.Sprint(id)
		if key == "<nil>" || key == "" {
			key = fmt.Sprint(link)
		}
		if key == "<nil>" || key == "" {
			continue
		}

		firstSeen := seenAt
		if existing, ok := archive[key]; ok {
			if v, ok := existing["first_seen_at"]; ok && fmt.Sprint(v) != "" {
				firstSeen = fmt.Sprint(v)
			}
		} else {
			newCount++
		}

		archive[key] = map[string]any{
			"post_id":      id,
			"published_at": pick(post, "published_at", "timestamp", "taken_at", "created_at", "created_time"),
			"text":         pick(post, "text", "caption", "body", "content"),
			"permalink":    link,
			"media":        pick(post, "media_urls", "media", "image_urls", "video_url"),
			"engagement": map[string]any{
				"likes":   pick(post, "like_count", "likes"),
				"replies": pick(post, "reply_count", "replies"),
				"reposts": pick(post, "repost_count", "reposts"),
				"quotes":  pick(post, "quote_count", "quotes"),
			},
			"first_seen_at": firstSeen,
			"last_seen_at":  seenAt,
		}
	}
	return newCount
}

func archiveSnapshot() []map[string]any {
	archiveMu.Lock()
	defer archiveMu.Unlock()

	out := make([]map[string]any, 0, len(archive))
	for _, post := range archive {
		copyPost := make(map[string]any, len(post))
		for k, v := range post {
			copyPost[k] = v
		}
		out = append(out, copyPost)
	}

	sort.Slice(out, func(i, j int) bool {
		return fmt.Sprint(out[i]["published_at"]) > fmt.Sprint(out[j]["published_at"])
	})
	return out
}

func collect(force bool) ([]byte, error) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	if !force && len(cache.body) > 0 && time.Since(cache.at) < 2*time.Minute {
		return cache.body, nil
	}

	th := os.Getenv("TH_BIN")
	if th == "" {
		th = "./bin/th"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	cmd := exec.CommandContext(ctx, th, "profile", "choi.openai", "--posts", "-n", "100", "-o", "json", "--no-cache")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		cache.errText = fmt.Sprintf("%v: %s", err, stderr.String())
		return nil, fmt.Errorf("%s", cache.errText)
	}

	var payload any
	if err := json.Unmarshal(out, &payload); err != nil {
		cache.errText = err.Error()
		return nil, err
	}

	collectedAt := time.Now().UTC().Format(time.RFC3339Nano)
	newCount := rememberPosts(payload, collectedAt)
	wrapped := map[string]any{
		"account":        "choi.openai",
		"collected_at":   collectedAt,
		"source":         "Render independent backup collector via tamnd/threads-cli",
		"collection_ok":  true,
		"new_since_boot": newCount,
		"payload":        payload,
	}
	body, err := json.Marshal(wrapped)
	if err != nil {
		return nil, err
	}
	cache.at = time.Now()
	cache.body = body
	cache.errText = ""
	fmt.Printf("BACKUP_COLLECT_OK collected_at=%s count=%d new=%d archive=%d\n", collectedAt, len(rawPosts(payload)), newCount, len(archiveSnapshot()))
	return body, nil
}

func collectHandler(w http.ResponseWriter, r *http.Request) {
	body, err := collect(false)
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"account":       "choi.openai",
			"collected_at":  time.Now().UTC().Format(time.RFC3339Nano),
			"collection_ok": false,
			"error":         err.Error(),
		})
		return
	}
	_, _ = w.Write(body)
}

func archiveHandler(w http.ResponseWriter, r *http.Request) {
	_, collectErr := collect(false)
	posts := archiveSnapshot()

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")

	if len(posts) == 0 && collectErr != nil {
		w.WriteHeader(http.StatusBadGateway)
	}

	payload := map[string]any{
		"account":       "choi.openai",
		"collected_at":  time.Now().UTC().Format(time.RFC3339Nano),
		"source":        "Render in-memory watchdog archive from repeated anonymous public crawls",
		"collection_ok": collectErr == nil,
		"archive_count": len(posts),
		"posts":         posts,
	}
	if collectErr != nil {
		payload["error"] = collectErr.Error()
		payload["limitations"] = []string{
			"Fresh collection failed, so the response contains only posts retained in memory since the current service boot.",
		}
	}
	_ = json.NewEncoder(w).Encode(payload)
}

func triggerHandler(w http.ResponseWriter, r *http.Request) {
	body, err := collect(true)
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"ok":    false,
			"error": err.Error(),
		})
		return
	}
	var wrapped map[string]any
	_ = json.Unmarshal(body, &wrapped)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"ok":           true,
		"collected_at": wrapped["collected_at"],
		"archive_count": len(archiveSnapshot()),
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	cache.mu.Lock()
	lastCollectAt := cache.at
	lastError := cache.errText
	cache.mu.Unlock()

	_ = json.NewEncoder(w).Encode(map[string]any{
		"ok":              true,
		"account":         "choi.openai",
		"last_collect_at": lastCollectAt.UTC().Format(time.RFC3339Nano),
		"last_error":      lastError,
		"archive_count":   len(archiveSnapshot()),
	})
}

func backgroundCollector() {
	for {
		if _, err := collect(true); err != nil {
			fmt.Printf("BACKGROUND_COLLECT_ERROR %s\n", err)
		}
		time.Sleep(5 * time.Minute)
	}
}

func main() {
	http.HandleFunc("/collect", collectHandler)
	http.HandleFunc("/archive", archiveHandler)
	http.HandleFunc("/trigger", triggerHandler)
	http.HandleFunc("/health", healthHandler)

	go backgroundCollector()

	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}
	fmt.Printf("CHOI Render backup collector listening on :%s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		panic(err)
	}
}
