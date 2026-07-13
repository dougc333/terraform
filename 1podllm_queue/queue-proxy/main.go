package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

const (
	maxRequestBytes  = 4 << 20
	maxResponseBytes = 16 << 20
)

type queueJob struct {
	ctx     context.Context
	body    []byte
	headers http.Header
	result  chan queueResult
}

type queueResult struct {
	status  int
	headers http.Header
	body    []byte
	err     error
}

type queueProxy struct {
	backendURL string
	jobs       chan queueJob
	workers    int
	client     *http.Client

	queued    atomic.Int64
	inFlight  atomic.Int64
	accepted  atomic.Uint64
	completed atomic.Uint64
	failed    atomic.Uint64
	rejected  atomic.Uint64
}

type queueStatus struct {
	Queued    int64  `json:"queued"`
	Capacity  int    `json:"capacity"`
	InFlight  int64  `json:"in_flight"`
	Workers   int    `json:"workers"`
	Accepted  uint64 `json:"accepted_total"`
	Completed uint64 `json:"completed_total"`
	Failed    uint64 `json:"failed_total"`
	Rejected  uint64 `json:"rejected_total"`
}

func newQueueProxy(backendURL string, workers, capacity int, timeout time.Duration) *queueProxy {
	p := &queueProxy{
		backendURL: strings.TrimRight(backendURL, "/") + "/v1/chat/completions",
		jobs:       make(chan queueJob, capacity),
		workers:    workers,
		client: &http.Client{
			Timeout: timeout,
			Transport: &http.Transport{
				DisableKeepAlives: true,
			},
		},
	}
	for workerID := 1; workerID <= workers; workerID++ {
		go p.runWorker(workerID)
	}
	return p
}

func (p *queueProxy) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/chat/completions", p.handleCompletion)
	mux.HandleFunc("/queue", p.handleQueueStatus)
	mux.HandleFunc("/queue-depth", p.handleQueueDepth)
	mux.HandleFunc("/metrics", p.handleMetrics)
	mux.HandleFunc("/healthz", p.handleHealth)
	return mux
}

func (p *queueProxy) handleCompletion(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxRequestBytes))
	if err != nil {
		http.Error(w, "request body is too large or unreadable", http.StatusRequestEntityTooLarge)
		return
	}

	job := queueJob{
		ctx:     r.Context(),
		body:    body,
		headers: r.Header.Clone(),
		result:  make(chan queueResult, 1),
	}

	p.queued.Add(1)
	select {
	case p.jobs <- job:
		p.accepted.Add(1)
		log.Printf("queue event=enqueue queued=%d in_flight=%d capacity=%d", p.queued.Load(), p.inFlight.Load(), cap(p.jobs))
	case <-r.Context().Done():
		p.queued.Add(-1)
		return
	default:
		p.queued.Add(-1)
		p.rejected.Add(1)
		w.Header().Set("Retry-After", "1")
		http.Error(w, "llama request queue is full", http.StatusTooManyRequests)
		log.Printf("queue event=reject queued=%d in_flight=%d capacity=%d", p.queued.Load(), p.inFlight.Load(), cap(p.jobs))
		return
	}

	select {
	case result := <-job.result:
		if result.err != nil {
			http.Error(w, result.err.Error(), http.StatusBadGateway)
			return
		}
		copyResponseHeaders(w.Header(), result.headers)
		w.WriteHeader(result.status)
		_, _ = w.Write(result.body)
	case <-r.Context().Done():
		return
	}
}

func (p *queueProxy) runWorker(workerID int) {
	for job := range p.jobs {
		queued := p.queued.Add(-1)
		inFlight := p.inFlight.Add(1)
		log.Printf("queue event=dequeue worker=%d queued=%d in_flight=%d", workerID, queued, inFlight)

		result := p.forward(job)
		inFlight = p.inFlight.Add(-1)
		if result.err != nil {
			p.failed.Add(1)
			log.Printf("queue event=failed worker=%d queued=%d in_flight=%d error=%q", workerID, p.queued.Load(), inFlight, result.err)
		} else {
			p.completed.Add(1)
			log.Printf("queue event=complete worker=%d queued=%d in_flight=%d status=%d", workerID, p.queued.Load(), inFlight, result.status)
		}
		job.result <- result
	}
}

func (p *queueProxy) forward(job queueJob) queueResult {
	if err := job.ctx.Err(); err != nil {
		return queueResult{err: err}
	}
	req, err := http.NewRequestWithContext(job.ctx, http.MethodPost, p.backendURL, bytes.NewReader(job.body))
	if err != nil {
		return queueResult{err: err}
	}
	req.Header = job.headers.Clone()
	removeHopByHopHeaders(req.Header)

	resp, err := p.client.Do(req)
	if err != nil {
		return queueResult{err: fmt.Errorf("llama.cpp request failed: %w", err)}
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes+1))
	if err != nil {
		return queueResult{err: fmt.Errorf("reading llama.cpp response: %w", err)}
	}
	if len(body) > maxResponseBytes {
		return queueResult{err: fmt.Errorf("llama.cpp response exceeded %d bytes", maxResponseBytes)}
	}
	return queueResult{status: resp.StatusCode, headers: resp.Header.Clone(), body: body}
}

func (p *queueProxy) status() queueStatus {
	return queueStatus{
		Queued:    p.queued.Load(),
		Capacity:  cap(p.jobs),
		InFlight:  p.inFlight.Load(),
		Workers:   p.workers,
		Accepted:  p.accepted.Load(),
		Completed: p.completed.Load(),
		Failed:    p.failed.Load(),
		Rejected:  p.rejected.Load(),
	}
}

func (p *queueProxy) handleQueueStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(p.status())
}

func (p *queueProxy) handleQueueDepth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintf(w, "%d\n", p.queued.Load())
}

func (p *queueProxy) handleMetrics(w http.ResponseWriter, _ *http.Request) {
	status := p.status()
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	fmt.Fprintf(w, "# HELP llama_queue_depth Number of llama.cpp requests waiting in the FIFO queue.\n")
	fmt.Fprintf(w, "# TYPE llama_queue_depth gauge\nllama_queue_depth %d\n", status.Queued)
	fmt.Fprintf(w, "# HELP llama_queue_in_flight Number of requests currently forwarded to llama.cpp.\n")
	fmt.Fprintf(w, "# TYPE llama_queue_in_flight gauge\nllama_queue_in_flight %d\n", status.InFlight)
	fmt.Fprintf(w, "# HELP llama_queue_capacity Maximum number of waiting requests.\n")
	fmt.Fprintf(w, "# TYPE llama_queue_capacity gauge\nllama_queue_capacity %d\n", status.Capacity)
	fmt.Fprintf(w, "# HELP llama_queue_accepted_total Total requests accepted by the queue.\n")
	fmt.Fprintf(w, "# TYPE llama_queue_accepted_total counter\nllama_queue_accepted_total %d\n", status.Accepted)
	fmt.Fprintf(w, "# HELP llama_queue_completed_total Total requests completed by llama.cpp.\n")
	fmt.Fprintf(w, "# TYPE llama_queue_completed_total counter\nllama_queue_completed_total %d\n", status.Completed)
	fmt.Fprintf(w, "# HELP llama_queue_failed_total Total queued requests that failed.\n")
	fmt.Fprintf(w, "# TYPE llama_queue_failed_total counter\nllama_queue_failed_total %d\n", status.Failed)
	fmt.Fprintf(w, "# HELP llama_queue_rejected_total Total requests rejected because the queue was full.\n")
	fmt.Fprintf(w, "# TYPE llama_queue_rejected_total counter\nllama_queue_rejected_total %d\n", status.Rejected)
}

func (p *queueProxy) handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = io.WriteString(w, `{"status":"ok"}`+"\n")
}

func copyResponseHeaders(dst, src http.Header) {
	removeHopByHopHeaders(src)
	for key, values := range src {
		for _, value := range values {
			dst.Add(key, value)
		}
	}
}

func removeHopByHopHeaders(header http.Header) {
	for _, key := range []string{"Connection", "Keep-Alive", "Proxy-Authenticate", "Proxy-Authorization", "Te", "Trailer", "Transfer-Encoding", "Upgrade", "Content-Length"} {
		header.Del(key)
	}
}

func envInt(name string, fallback int) int {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < 1 {
		log.Fatalf("%s must be a positive integer, got %q", name, raw)
	}
	return value
}

func envDuration(name string, fallback time.Duration) time.Duration {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback
	}
	value, err := time.ParseDuration(raw)
	if err != nil || value <= 0 {
		log.Fatalf("%s must be a positive duration, got %q", name, raw)
	}
	return value
}

func main() {
	backendURL := os.Getenv("LLAMA_URL")
	if backendURL == "" {
		backendURL = "http://llama-server:8080"
	}
	workers := envInt("QUEUE_WORKERS", 2)
	capacity := envInt("QUEUE_CAPACITY", 100)
	timeout := envDuration("LLAMA_TIMEOUT", 5*time.Minute)
	listenAddress := os.Getenv("LISTEN_ADDRESS")
	if listenAddress == "" {
		listenAddress = ":8080"
	}

	proxy := newQueueProxy(backendURL, workers, capacity, timeout)
	log.Printf("llama queue listening=%s backend=%s workers=%d capacity=%d", listenAddress, proxy.backendURL, workers, capacity)
	if err := http.ListenAndServe(listenAddress, proxy.routes()); err != nil {
		log.Fatal(err)
	}
}
