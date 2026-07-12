package main

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	requestCount = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "web_requests_total",
		Help: "Total successful web requests.",
	})

	errorCount = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "web_request_errors_total",
		Help: "Total failed web requests.",
	})

	inFlight = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "web_requests_in_flight",
		Help: "Requests currently being processed.",
	})

	requestDuration = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "web_request_duration_seconds",
		Help:    "Request processing time.",
		Buckets: prometheus.DefBuckets,
	})

	workCount = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "web_work_iterations_total",
		Help: "CPU-work iterations completed.",
	})
)

func init() {
	prometheus.MustRegister(
		requestCount,
		errorCount,
		inFlight,
		requestDuration,
		workCount,
	)
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
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       30 * time.Second,
	}

	log.Println("web server listening on :8080")
	log.Fatal(server.ListenAndServe())
}

func handleWeb(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		errorCount.Inc()
		http.NotFound(w, r)
		return
	}

	started := time.Now()

	inFlight.Inc()
	defer inFlight.Dec()

	iterations := queryInt(r, "work", 50_000, 5_000_000)
	result := burnCPU(iterations)

	requestCount.Inc()
	workCount.Add(float64(iterations))
	requestDuration.Observe(time.Since(started).Seconds())

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintf(
		w,
		"Hello from Kubernetes. work=%d result=%d\n",
		iterations,
		result,
	)
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
