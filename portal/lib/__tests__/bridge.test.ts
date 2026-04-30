import { describe, it, expect, vi, beforeEach } from 'vitest'
import { sendToGame, onGameMessage } from '../bridge'

describe('sendToGame', () => {
  it('posts message to iframe contentWindow', () => {
    const postMessage = vi.fn()
    const iframe = { contentWindow: { postMessage } } as unknown as HTMLIFrameElement
    sendToGame(iframe, 'auth_token', { token: 'abc123' })
    expect(postMessage).toHaveBeenCalledWith(
      { type: 'auth_token', token: 'abc123' },
      '*'
    )
  })

  it('does nothing when contentWindow is null', () => {
    const iframe = { contentWindow: null } as unknown as HTMLIFrameElement
    expect(() => sendToGame(iframe, 'auth_token', { token: 'abc' })).not.toThrow()
  })
})

describe('onGameMessage', () => {
  it('calls handler when message event fires with type', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    window.dispatchEvent(
      new MessageEvent('message', { data: { type: 'game_ready' } })
    )
    expect(handler).toHaveBeenCalledWith({ type: 'game_ready' })
    cleanup()
  })

  it('ignores messages without type', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    window.dispatchEvent(new MessageEvent('message', { data: { foo: 'bar' } }))
    expect(handler).not.toHaveBeenCalled()
    cleanup()
  })

  it('ignores null data messages', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    window.dispatchEvent(new MessageEvent('message', { data: null }))
    expect(handler).not.toHaveBeenCalled()
    cleanup()
  })

  it('cleanup removes listener', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler)
    cleanup()
    window.dispatchEvent(
      new MessageEvent('message', { data: { type: 'game_ready' } })
    )
    expect(handler).not.toHaveBeenCalled()
  })
})
