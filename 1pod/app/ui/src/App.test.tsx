import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'

describe('One-Pod lab UI', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })

  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it('shows health loading and success states', async () => {
    vi.mocked(fetch).mockResolvedValue(new Response('ok\n', { status: 200 }))
    render(<App />)

    expect(screen.getByRole('status')).toHaveTextContent('Checking service')
    await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent('Service healthy'))
    expect(fetch).toHaveBeenCalledWith('/healthz', expect.objectContaining({ cache: 'no-store' }))
  })

  it('shows a useful health error state', async () => {
    vi.mocked(fetch).mockResolvedValue(new Response('no', { status: 503 }))
    render(<App />)

    await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent('Service unavailable'))
  })

  it('sends adjustable work and records the response', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(new Response('ok\n', { status: 200 }))
      .mockResolvedValueOnce(new Response('Hello from Kubernetes. work=750000 result=42\n', { status: 200 }))
    const user = userEvent.setup()
    render(<App />)

    await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent('Service healthy'))
    const input = screen.getByLabelText('CPU iterations')
    await user.clear(input)
    await user.type(input, '750000')
    await user.click(screen.getByRole('button', { name: 'Generate observable load' }))

    await waitFor(() => expect(screen.getByText('750,000 iterations')).toBeInTheDocument())
    expect(screen.getByText('Hello from Kubernetes. work=750000 result=42')).toBeInTheDocument()
    expect(fetch).toHaveBeenLastCalledWith('/api/work?work=750000', { cache: 'no-store' })
  })

  it('reports workload request failures', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(new Response('ok\n', { status: 200 }))
      .mockResolvedValueOnce(new Response('request failed', { status: 500 }))
    const user = userEvent.setup()
    render(<App />)

    await waitFor(() => expect(screen.getByRole('status')).toHaveTextContent('Service healthy'))
    await user.click(screen.getByRole('button', { name: 'Generate observable load' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('request failed')
  })
})
