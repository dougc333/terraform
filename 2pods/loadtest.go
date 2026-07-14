package main

import (
    "context"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/exec"
    "os/signal"
    "path/filepath"
    "sync"
    "syscall"
    "time"
)

const (
    namespace     = "web-observability"
    url           = "http://127.0.0.1:18080"
    pfLogFilename = "one-pod-web-port-forward.log"
)

type Stage struct {
    Concurrency int
    Duration    int
    Work        int
}

func main() {
    // 1. Setup Paths & Env Vars
    root, err := os.Getwd()
    if err != nil {
        log.Fatalf("Failed to get working directory: %v", err)
    }
    os.Setenv("KUBECONFIG", filepath.Join(root, ".kubeconfig"))

    tmpDir := os.Getenv("TMPDIR")
    if tmpDir == "" {
        tmpDir = "/tmp"
    }
    logPath := filepath.Join(tmpDir, pfLogFilename)

    // 2. Context for graceful shutdown (Replaces bash `trap cleanup EXIT INT TERM`)
    ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer stop()

    // 3. Start Port-Forward
    logFile, err := os.Create(logPath)
    if err != nil {
        log.Fatalf("Failed to create log file: %v", err)
    }
    defer logFile.Close()

    // CommandContext automatically kills the process if ctx is canceled
    pfCmd := exec.CommandContext(ctx, "kubectl", "--namespace", namespace, "port-forward", "service/web", "18080:8080")
    pfCmd.Stdout = logFile
    pfCmd.Stderr = logFile

    if err := pfCmd.Start(); err != nil {
        log.Fatalf("Failed to start port-forward: %v", err)
    }
    fmt.Printf("Started port-forward (PID %d), logging to %s\n", pfCmd.Process.Pid, logPath)

    // 4. Readiness Check (Replaces the 30-iteration bash loop)
    fmt.Println("Waiting for port-forward to become ready...")
    client := &http.Client{Timeout: 2 * time.Second}
    ready := false
    for i := 0; i < 30; i++ {
        resp, err := client.Get(url + "/healthz")
        if err == nil && resp.StatusCode == http.StatusOK {
            resp.Body.Close()
            ready = true
            break
        }
        if resp != nil {
            resp.Body.Close()
        }
        time.Sleep(1 * time.Second)
    }

    if !ready {
        log.Fatalf("web port-forward did not become ready; see %s", logPath)
    }
    fmt.Println("Port-forward is ready!")

    // 5. Start CPU Monitor Goroutine (Replaces bash background function)
    go monitorCPU(ctx)

    // 6. Define Test Stages
    singleRamp := []Stage{
        {1, 10, 250000},
        {5, 15, 1000000},
        {15, 25, 3000000},
        {30, 30, 5000000},

