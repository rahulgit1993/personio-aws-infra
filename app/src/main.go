package main

import (
"fmt"
"net/http"
"os"
"time"

"github.com/prometheus/client_golang/prometheus"
"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
// Create a new counter metric for the HTTP requests.
httpRequests = prometheus.NewCounterVec(
prometheus.CounterOpts{
Name: "http_requests_total",
Help: "Total number of HTTP requests",
},
[]string{"method", "path"},
)

// Create a new histogram metric for request duration.
httpDuration = prometheus.NewHistogramVec(
prometheus.HistogramOpts{
Name:    "http_request_duration_seconds",
Help:    "Histogram of HTTP request durations.",
Buckets: prometheus.DefBuckets,
},
[]string{"method", "path"},
)
)

func init() {
// Register the metrics with Prometheus.
prometheus.MustRegister(httpRequests)
prometheus.MustRegister(httpDuration)
}

func main() {
// Register the /metrics endpoint for Prometheus to scrape.
http.Handle("/metrics", promhttp.Handler())

// Register your app's endpoint.
http.HandleFunc("/", HelloEndpoint)

// Start the HTTP server.
http.ListenAndServe(":8080", nil)
}

// HelloEndpoint handles the root path and exposes metrics.
func HelloEndpoint(w http.ResponseWriter, r *http.Request) {
// Measure the request duration.
start := time.Now()

// Increment the HTTP request counter.
httpRequests.WithLabelValues(r.Method, r.URL.Path).Inc()

// Handle the request.
fmt.Fprintf(w, "%s, %s!", os.Getenv("HELLO"), r.URL.Path[1:])

// Record the request duration.
httpDuration.WithLabelValues(r.Method, r.URL.Path).Observe(time.Since(start).Seconds())
}
