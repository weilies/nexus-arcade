import { describe, it, expect, vi, beforeEach } from 'vitest'
import { sendToGame, onGameMessage } from '../bridge'

describe('sendToGame', () => {
  it('posts message to iframe contentWindow', () => {
    const postMessage = vi.fn()
    const iframe = { contentWindow: { postMessage } } as unknown as HTMLIFrameElement
    sendToGame(iframe, 'auth_token', { token: 'abc123' }, '*')
    expect(postMessage).toHaveBeenCalledWith(
      { type: 'auth_token', token: 'abc123' },
      '*'
    )
  })

  it('does nothing when contentWindow is null', () => {
    const iframe = { contentWindow: null } as unknown as HTMLIFrameElement
    expect(() => sendToGame(iframe, 'auth_token', { token: 'abc' }, '*')).not.toThrow()
  })
})

describe('onGameMessage', () => {
  const origin = window.location.origin

  it('calls handler when message event fires with type from expected origin', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler, origin)
    window.dispatchEvent(
      new MessageEvent('message', { data: { type: 'game_ready' }, origin })
    )
    expect(handler).toHaveBeenCalledWith({ type: 'game_ready' })
    cleanup()
  })

  it('ignores messages from unexpected origins', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler, origin)
    window.dispatchEvent(
      new MessageEvent('message', { data: { type: 'game_ready' }, origin: 'https://evil.com' })
    )
    expect(handler).not.toHaveBeenCalled()
    cleanup()
  })

  it('ignores messages without type', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler, origin)
    window.dispatchEvent(new MessageEvent('message', { data: { foo: 'bar' }, origin }))
    expect(handler).not.toHaveBeenCalled()
    cleanup()
  })

  it('ignores null data messages', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler, origin)
    window.dispatchEvent(new MessageEvent('message', { data: null, origin }))
    expect(handler).not.toHaveBeenCalled()
    cleanup()
  })

  it('cleanup removes listener', () => {
    const handler = vi.fn()
    const cleanup = onGameMessage(handler, origin)
    cleanup()
    window.dispatchEvent(
      new MessageEvent('message', { data: { type: 'game_ready' }, origin })
    )
    expect(handler).not.toHaveBeenCalled()
  })
})
