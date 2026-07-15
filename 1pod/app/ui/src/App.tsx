import { FormEvent, useCallback, useEffect, useRef, useState } from 'react'

const MIN_WORK = 1
const MAX_WORK = 5_000_000
const DEFAULT_WORK = 250_000
const HEALTH_INTERVAL_MS = 10_000

type HealthState = 'loading' | 'healthy' | 'error'

type Run = {
  id: number
  work: number
  duration: number
  response: string
  time: string
}

function formatNumber(value: number) {
  return new Intl.NumberFormat('en-US').format(value)
}

function formatDuration(milliseconds: number) {
  return milliseconds < 1_000
    ? `${Math.round(milliseconds)} ms`
    : `${(milliseconds / 1_000).toFixed(2)} s`
}

function App() {
  const [health, setHealth] = useState<HealthState>('loading')
  const [workInput, setWorkInput] = useState(String(DEFAULT_WORK))
  const [isRunning, setIsRunning] = useState(false)
  const [runs, setRuns] = useState<Run[]>([])
  const [runError, setRunError] = useState('')
  const runId = useRef(0)
  const work = Math.min(MAX_WORK, Math.max(MIN_WORK, Number(workInput) || MIN_WORK))

  const checkHealth = useCallback(async (signal?: AbortSignal) => {
    setHealth('loading')
    try {
      const response = await fetch('/healthz', { signal, cache: 'no-store' })
      if (!response.ok) throw new Error(`Health check returned ${response.status}`)
      setHealth('healthy')
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') return
      setHealth('error')
    }
  }, [])

  useEffect(() => {
    const controller = new AbortController()
    void checkHealth(controller.signal)
    const interval = window.setInterval(() => void checkHealth(), HEALTH_INTERVAL_MS)

    return () => {
      controller.abort()
      window.clearInterval(interval)
    }
  }, [checkHealth])

  async function runWorkload(event: FormEvent) {
    event.preventDefault()
    setIsRunning(true)
    setRunError('')
    const started = performance.now()

    try {
      const response = await fetch(`/api/work?work=${work}`, { cache: 'no-store' })
      const body = (await response.text()).trim()
      if (!response.ok) throw new Error(body || `Request returned ${response.status}`)

      const run: Run = {
        id: ++runId.current,
        work,
        duration: performance.now() - started,
        response: body,
        time: new Intl.DateTimeFormat('en', {
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
        }).format(new Date()),
      }
      setRuns((current) => [run, ...current].slice(0, 6))
    } catch (error) {
      setRunError(error instanceof Error ? error.message : 'The workload request failed.')
    } finally {
      setIsRunning(false)
    }
  }

  return (
    <div className="app-shell">
      <header className="topbar">
        <a className="brand" href="#top" aria-label="One-Pod Observability Lab home">
          <span className="brand-mark" aria-hidden="true">
            <span />
          </span>
          <span>1POD <em>/ OBSERVABILITY</em></span>
        </a>
        <div className={`health-pill health-${health}`} role="status" aria-live="polite">
          <span className="health-dot" aria-hidden="true" />
          {health === 'loading' && 'Checking service'}
          {health === 'healthy' && 'Service healthy'}
          {health === 'error' && 'Service unavailable'}
        </div>
      </header>

      <main id="top">
        <section className="hero" aria-labelledby="page-title">
          <div className="eyebrow"><span>LOCAL KUBERNETES</span><span>LIVE TELEMETRY</span></div>
          <h1 id="page-title">Make the pod<br /><span>tell its story.</span></h1>
          <p className="hero-copy">
            One Go service. One Kubernetes pod. Every request becomes a signal you can follow
            through Prometheus and Grafana.
          </p>
          <div className="system-line" aria-label="Lab data flow">
            <span>Browser</span><i aria-hidden="true" /><span>Web pod</span><i aria-hidden="true" />
            <span>Prometheus</span><i aria-hidden="true" /><span>Grafana</span>
          </div>
        </section>

        <section className="workspace" aria-label="Lab controls and recent results">
          <div className="work-card panel">
            <div className="panel-heading">
              <div>
                <p className="kicker">LOAD GENERATOR</p>
                <h2>Send one workload</h2>
              </div>
              <span className="metric-tag">GET /api/work</span>
            </div>

            <form onSubmit={runWorkload}>
              <label htmlFor="work-number">CPU iterations</label>
              <div className="number-control">
                <input
                  id="work-number"
                  type="number"
                  min={MIN_WORK}
                  max={MAX_WORK}
                  step="1"
                  value={workInput}
                  onChange={(event) => setWorkInput(event.target.value)}
                  onBlur={() => setWorkInput(String(work))}
                />
                <span>iterations</span>
              </div>
              <input
                className="work-slider"
                type="range"
                min={MIN_WORK}
                max={MAX_WORK}
                step="1"
                value={work}
                aria-label="CPU iterations slider"
                onChange={(event) => setWorkInput(event.target.value)}
              />
              <div className="range-labels" aria-hidden="true">
                <span>1</span><span>2.5M</span><span>5M max</span>
              </div>
              <button className="run-button" type="submit" disabled={isRunning}>
                <span>{isRunning ? 'Request running…' : 'Generate observable load'}</span>
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="m8 5 8 7-8 7V5Z" />
                </svg>
              </button>
            </form>

            {runError && <p className="run-error" role="alert">{runError}</p>}
            <p className="work-note">
              One request burns <strong>{formatNumber(work)}</strong> CPU iterations in the pod.
              Try higher values and watch request duration rise.
            </p>
          </div>

          <div className="runs-card panel">
            <div className="panel-heading">
              <div>
                <p className="kicker">REQUEST STREAM</p>
                <h2>Recent runs</h2>
              </div>
              <span className="run-count">{runs.length} / 6</span>
            </div>

            <div className="runs" aria-live="polite">
              {runs.length === 0 ? (
                <div className="empty-state">
                  <div className="empty-pulse" aria-hidden="true"><span /></div>
                  <p>No workload signals yet</p>
                  <span>Send a request to begin the trace.</span>
                </div>
              ) : runs.map((run) => (
                <article className="run-row" key={run.id}>
                  <div className="run-status" aria-hidden="true">✓</div>
                  <div className="run-result">
                    <strong>{formatNumber(run.work)} iterations</strong>
                    <code>{run.response}</code>
                  </div>
                  <div className="run-meta">
                    <strong>{formatDuration(run.duration)}</strong>
                    <time>{run.time}</time>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="observe" aria-labelledby="observe-title">
          <div className="section-intro">
            <p className="kicker">FOLLOW THE SIGNAL</p>
            <h2 id="observe-title">Observe what you create</h2>
            <p>Keep these port-forwards open in separate terminals while you generate load.</p>
          </div>
          <div className="guide-grid">
            <article className="guide-card grafana-card">
              <div className="guide-number">01</div>
              <div>
                <h3>Open Grafana</h3>
                <p>Explore the provisioned dashboard for rate, latency, CPU, memory, and in-flight requests.</p>
                <code>./scripts/grafana-ui.sh</code>
                <a href="http://127.0.0.1:3000/d/one-pod-overview/one-pod-observability" target="_blank" rel="noreferrer">
                  127.0.0.1:3000 <span aria-hidden="true">↗</span>
                </a>
              </div>
            </article>
            <article className="guide-card prometheus-card">
              <div className="guide-number">02</div>
              <div>
                <h3>Query Prometheus</h3>
                <p>Inspect raw metrics and graph the service request rate over the last 30 seconds.</p>
                <code>./scripts/prometheus-ui.sh</code>
                <a href="http://127.0.0.1:9090/query" target="_blank" rel="noreferrer">
                  127.0.0.1:9090 <span aria-hidden="true">↗</span>
                </a>
              </div>
            </article>
            <article className="guide-card load-card">
              <div className="guide-number">03</div>
              <div>
                <h3>Run staged load</h3>
                <p>Drive sustained concurrency from a terminal and watch the pod’s resources respond.</p>
                <code>./scripts/load-test.sh</code>
                <span className="terminal-note">Bash · curl · kubectl</span>
              </div>
            </article>
          </div>
        </section>
      </main>

      <footer>
        <span>ONE-POD OBSERVABILITY LAB</span>
        <span>Signals over guesses.</span>
      </footer>
    </div>
  )
}

export default App
