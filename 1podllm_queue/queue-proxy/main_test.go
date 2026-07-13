package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestQueueDepthAndForwarding(t *testing.T) {
	backendStarted := make(chan struct{}, 1)
	releaseBackend := make(chan struct{})
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		backendStarted <- struct{}{}
		<-releaseBackend
		w.Header().Set("Content-Type", "application/json")
		body, _ := io.ReadAll(r.Body)
		_, _ = w.Write(body)
	}))
	defer backend.Close()

	proxy := newQueueProxy(backend.URL, 1, 2, 5*time.Second)
	frontend := httptest.NewServer(proxy.routes())
	defer frontend.Close()

	firstDone := postAsync(frontend.URL, []byte(`{"request":1}`))
	select {
	case <-backendStarted:
	case <-time.After(time.Second):
		t.Fatal("first request did not reach the backend")
	}

	secondDone := postAsync(frontend.URL, []byte(`{"request":2}`))
	deadline := time.Now().Add(time.Second)
	for {
		resp, err := http.Get(frontend.URL + "/queue")
		if err != nil {
			t.Fatal(err)
		}
		var status queueStatus
		err = json.NewDecoder(resp.Body).Decode(&status)
		resp.Body.Close()
		if err != nil {
			t.Fatal(err)
		}
		if status.Queued == 1 && status.InFlight == 1 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("expected one queued and one in-flight request, got %+v", status)
		}
		time.Sleep(10 * time.Millisecond)
	}

	close(releaseBackend)
	for _, result := range []requestResult{<-firstDone, <-secondDone} {
		if result.err != nil {
			t.Fatal(result.err)
		}
		if result.status != http.StatusOK {
			t.Fatalf("unexpected status %d", result.status)
		}
	}
}

type requestResult struct {
	status int
	err    error
}

func postAsync(url string, body []byte) <-chan requestResult {
	done := make(chan requestResult, 1)
	go func() {
		resp, err := http.Post(url+"/v1/chat/completions", "application/json", bytes.NewReader(body))
		if err != nil {
			done <- requestResult{err: err}
			return
		}
		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		done <- requestResult{status: resp.StatusCode}
	}()
	return done
}
