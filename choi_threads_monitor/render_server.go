package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"sync"
	"time"
)

type cacheState struct {
	mu        sync.Mutex
	at        time.Time
	body      []byte
	errText   string
}

var cache cacheState
var seenMu sync.Mutex
var seen = map[string]bool{}

func collect() ([]byte, error) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	if len(cache.body) > 0 && time.Since(cache.at) < 5*time.Minute {
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

	wrapped := map[string]any{
		"account":       "choi.openai",
		"collected_at":  time.Now().UTC().Format(time.RFC3339Nano),
		"source":        "Render independent backup collector via tamnd/threads-cli",
		"collection_ok": true,
		"payload":       payload,
	}
	body, err := json.Marshal(wrapped)
	if err != nil {
		return nil, err
	}
	cache.at = time.Now()
	cache.body = body
	cache.errText = ""
	return body, nil
}

func collectHandler(w http.ResponseWriter, r *http.Request) {
	body, err := collect()
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

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	cache.mu.Lock()
	defer cache.mu.Unlock()
	_ = json.NewEncoder(w).Encode(map[string]any{
		"ok":             true,
		"account":        "choi.openai",
		"last_collect_at": cache.at.UTC().Format(time.RFC3339Nano),
		"last_error":     cache.errText,
	})
}

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

func logNewPosts(payload any) int {
	posts := rawPosts(payload)
	newCount := 0
	seenMu.Lock()
	defer seenMu.Unlock()

	for _, post := range posts {
		id := pick(post, "post_id", "id", "pk", "code")
		link := pick(post, "permalink", "url", "link")
		key := fmt.Sprint(id)
		if key == "<nil>" || key == "" {
			key = fmt.Sprint(link)
		}
		if key == "<nil>" || key == "" || seen[key] {
			continue
		}
		seen[key] = true
		newCount++

		lean := map[string]any{
			"post_id":      id,
			"published_at": pick(post, "published_at", "timestamp", "taken_at", "created_at", "created_time"),
			"text":         pick(post, "text", "caption", "body", "content"),
			"permalink":    link,
		}
		b, _ := json.Marshal(lean)
		fmt.Printf("BACKUP_POST %s\n", string(b))
	}
	return newCount
}

func backgroundCollector() {
	for {
		body, err := collect()
		if err != nil {
			fmt.Printf("BACKGROUND_COLLECT_ERROR %s\n", err)
		} else {
			var wrapped map[string]any
			_ = json.Unmarshal(body, &wrapped)
			payload := wrapped["payload"]
			posts := rawPosts(payload)
			newCount := logNewPosts(payload)
			fmt.Printf("BACKGROUND_COLLECT_OK collected_at=%v count=%d new=%d\n", wrapped["collected_at"], len(posts), newCount)
		}
		time.Sleep(15 * time.Minute)
	}
}

func main() {
	http.HandleFunc("/collect", collectHandler)
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
