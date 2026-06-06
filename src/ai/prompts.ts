import type { Artist, UnfinishedPiece, ToneProfile } from '../lib/types'

function toneDescription(tone: ToneProfile): string {
  const parts: string[] = []
  if (tone.style_notes) parts.push(tone.style_notes)
  if (tone.sample_replies?.length) {
    parts.push(
      `Examples of how ${tone.greeting ? `"${tone.greeting}"` : 'this artist'} typically writes:\n` +
        tone.sample_replies.map((r) => `- "${r}"`).join('\n'),
    )
  }
  return parts.length ? parts.join('\n\n') : 'Friendly, professional, concise. Never pushy.'
}

function daysSince(isoDate: string): number {
  return Math.floor((Date.now() - new Date(isoDate).getTime()) / 86_400_000)
}

export function buildFollowUpPrompt(artist: Artist, piece: UnfinishedPiece): string {
  const days = daysSince(piece.last_session_at)
  const contactName = piece.contact_name ?? 'the client'
  const pieceRef = piece.piece_title ?? piece.piece_description ?? 'their piece'

  return `You are drafting a follow-up message for ${artist.name}, a tattoo artist.

Voice and style:
${toneDescription(artist.tone_profile)}

Context:
- Client: ${contactName}
- Piece: ${pieceRef}
- Sessions completed so far: ${piece.sessions_completed}
- Last session: ${days} day${days !== 1 ? 's' : ''} ago
- Situation: multi-session piece, no follow-up booking exists

Write a short, natural check-in from ${artist.name} to ${contactName} about finishing their piece. Tone: warm, not pushy. Under 3 sentences. Output only the message text — no subject line, no quotes, no commentary.`
}
