package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	requestCount = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "web_requests_total",
			Help: "Total web requests by HTTP status class.",
		},
		[]string{"status"},
	)

	requestDuration = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "web_request_duration_seconds",
		Help:    "Web request processing duration in seconds.",
		Buckets: prometheus.DefBuckets,
	})

	inFlight = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "web_requests_in_flight",
		Help: "Web requests currently being processed.",
	})

	workCount = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "web_work_iterations_total",
		Help: "CPU-work iterations completed by successful requests.",
	})
)

func init() {
	prometheus.MustRegister(requestCount, requestDuration, inFlight, workCount)
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleWeb)
	mux.HandleFunc("/healthz", handleHealth)
	mux.Handle("/metrics", promhttp.Handler())

	server := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 3 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       30 * time.Second,
	}

	ctx, stop := signal.NotifyContext(
		context.Background(),
		syscall.SIGINT,
		syscall.SIGTERM,
	)
	defer stop()

	go func() {
		log.Println("web server listening on :8080")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("serve: %v", err)
		}
	}()

	<-ctx.Done()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("graceful shutdown: %v", err)
	}
}

func handleWeb(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	inFlight.Inc()
	defer inFlight.Dec()
	defer func() {
		requestDuration.Observe(time.Since(started).Seconds())
	}()

	if r.URL.Path != "/" {
		requestCount.WithLabelValues("4xx").Inc()
		http.NotFound(w, r)
		return
	}

	iterations := queryInt(r, "work", 5_000_000, 50_000_000)
	result := burnCPU(iterations)
	requestCount.WithLabelValues("2xx").Inc()
	workCount.Add(float64(iterations))

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = fmt.Fprintf(w, "work=%d result=%d\n", iterations, result)
}

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
}

func queryInt(r *http.Request, name string, fallback, maximum int) int {
	raw := r.URL.Query().Get(name)
	if raw == "" {
		return fallback
	}

	value, err := strconv.Atoi(raw)
	if err != nil || value < 1 {
		return fallback
	}
	if value > maximum {
		return maximum
	}
	return value
}

func burnCPU(iterations int) uint64 {
	value := uint64(0x9e3779b97f4a7c15)
	for i := 0; i < iterations; i++ {
		value ^= value << 13
		value ^= value >> 7
		value ^= value << 17
	}
	return value
}
