import Anthropic from '@anthropic-ai/sdk'
import { buildFollowUpPrompt } from './prompts'
import type { Artist, UnfinishedPiece } from '../lib/types'

const client = new Anthropic()

export async function draftFollowUpMessage(
  artist: Artist,
  piece: UnfinishedPiece,
): Promise<string> {
  const prompt = buildFollowUpPrompt(artist, piece)

  const response = await client.messages.create({
    model: 'claude-opus-4-8',
    max_tokens: 300,
    messages: [{ role: 'user', content: prompt }],
  })

  const block = response.content[0]
  if (block.type !== 'text') throw new Error('Unexpected response type from Claude')
  return block.text.trim()
}
