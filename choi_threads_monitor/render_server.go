package main

import (
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
	out, err := cmd.CombinedOutput()
	if err != nil {
		cache.errText = fmt.Sprintf("%v: %s", err, string(out))
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

func main() {
	http.HandleFunc("/collect", collectHandler)
	http.HandleFunc("/health", healthHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}
	fmt.Printf("CHOI Render backup collector listening on :%s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		panic(err)
	}
}
