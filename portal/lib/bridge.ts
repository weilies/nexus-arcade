export type PortalMessageType = 'auth_token' | 'season_info'

export interface GameReadyMessage { type: 'game_ready' }
export interface MatchEndMessage {
  type: 'match_end'
  score: number
  winner: 'player' | 'opponent' | 'draw'
  mode: 'solo' | 'local' | 'online'
}
export interface AuthRequestMessage { type: 'auth_request' }
export type GameMessage = GameReadyMessage | MatchEndMessage | AuthRequestMessage

export function sendToGame(
  iframe: HTMLIFrameElement,
  type: PortalMessageType,
  payload: Record<string, unknown>,
  targetOrigin = window.location.origin
): void {
  iframe.contentWindow?.postMessage({ type, ...payload }, targetOrigin)
}

export function onGameMessage(
  handler: (msg: GameMessage) => void,
  expectedOrigin = window.location.origin
): () => void {
  const listener = (event: MessageEvent) => {
    if (event.origin !== expectedOrigin) return
    if (event.data && typeof event.data.type === 'string') {
      handler(event.data as GameMessage)
    }
  }
  window.addEventListener('message', listener)
  return () => window.removeEventListener('message', listener)
}
