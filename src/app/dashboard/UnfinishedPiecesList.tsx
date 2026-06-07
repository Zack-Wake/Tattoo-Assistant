'use client'

import { useState } from 'react'
import { generateDraft } from './actions'
import type { UnfinishedPiece, Artist } from '@/lib/types'

interface Props {
  pieces: UnfinishedPiece[]
  artist: Artist
}

function daysSince(isoDate: string): number {
  return Math.floor((Date.now() - new Date(isoDate).getTime()) / 86_400_000)
}

export default function UnfinishedPiecesList({ pieces, artist }: Props) {
  const [drafts, setDrafts] = useState<Record<string, string>>({})
  const [loading, setLoading] = useState<Record<string, boolean>>({})
  const [copied, setCopied] = useState<Record<string, boolean>>({})

  async function handleDraft(piece: UnfinishedPiece) {
    setLoading((prev) => ({ ...prev, [piece.piece_id]: true }))
    try {
      const draft = await generateDraft(piece)
      setDrafts((prev) => ({ ...prev, [piece.piece_id]: draft }))
    } catch (err) {
      console.error('Draft generation failed:', err)
    } finally {
      setLoading((prev) => ({ ...prev, [piece.piece_id]: false }))
    }
  }

  async function handleCopy(id: string, text: string) {
    await navigator.clipboard.writeText(text)
    setCopied((prev) => ({ ...prev, [id]: true }))
    setTimeout(() => setCopied((prev) => ({ ...prev, [id]: false })), 2000)
  }

  function handleDiscard(id: string) {
    setDrafts((prev) => {
      const next = { ...prev }
      delete next[id]
      return next
    })
  }

  if (pieces.length === 0) {
    return (
      <div className="rounded-lg border border-zinc-800 bg-zinc-900 px-4 py-8 text-center">
        <p className="text-sm text-zinc-500">No unfinished multi-session pieces.</p>
        <p className="mt-1 text-xs text-zinc-600">
          They&apos;ll appear here once you log a completed session on a multi-session piece
          with no follow-up booking.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {pieces.map((piece) => {
        const days = daysSince(piece.last_session_at)
        const draft = drafts[piece.piece_id]
        const isLoading = loading[piece.piece_id]
        const isCopied = copied[piece.piece_id]

        return (
          <div
            key={piece.piece_id}
            className="rounded-lg border border-zinc-800 bg-zinc-900 p-4"
          >
            {/* Row header */}
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0">
                <p className="truncate font-medium text-zinc-100">
                  {piece.contact_name ?? 'Unknown client'}
                </p>
                <p className="mt-0.5 truncate text-sm text-zinc-400">
                  {piece.piece_title ?? piece.piece_description ?? 'Untitled piece'}
                  {' · '}
                  {piece.sessions_completed} session
                  {piece.sessions_completed !== 1 ? 's' : ''} done
                  {' · '}
                  <span className={days > 60 ? 'text-amber-400' : 'text-zinc-400'}>
                    {days}d since last session
                  </span>
                </p>
              </div>

              {!draft && (
                <button
                  onClick={() => handleDraft(piece)}
                  disabled={isLoading}
                  className="shrink-0 rounded-md bg-amber-500 px-3 py-1.5 text-sm font-medium text-zinc-950 transition-colors hover:bg-amber-400 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {isLoading ? 'Drafting…' : 'Draft message'}
                </button>
              )}
            </div>

            {/* Draft area */}
            {draft && (
              <div className="mt-3 space-y-2">
                <textarea
                  value={drafts[piece.piece_id]}
                  onChange={(e) =>
                    setDrafts((prev) => ({ ...prev, [piece.piece_id]: e.target.value }))
                  }
                  rows={3}
                  className="w-full rounded-md border border-zinc-700 bg-zinc-800 px-3 py-2 text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:ring-1 focus:ring-amber-500 resize-none"
                />
                <div className="flex flex-wrap gap-2">
                  <button
                    onClick={() => handleCopy(piece.piece_id, draft)}
                    className="rounded-md border border-zinc-700 px-3 py-1.5 text-sm text-zinc-300 transition-colors hover:border-zinc-600 hover:text-zinc-100"
                  >
                    {isCopied ? 'Copied!' : 'Copy'}
                  </button>
                  <button
                    onClick={() => handleDraft(piece)}
                    disabled={isLoading}
                    className="rounded-md border border-zinc-700 px-3 py-1.5 text-sm text-zinc-300 transition-colors hover:border-zinc-600 hover:text-zinc-100 disabled:opacity-50"
                  >
                    {isLoading ? 'Regenerating…' : 'Regenerate'}
                  </button>
                  <button
                    onClick={() => handleDiscard(piece.piece_id)}
                    className="rounded-md border border-zinc-700 px-3 py-1.5 text-sm text-zinc-500 transition-colors hover:border-zinc-600 hover:text-zinc-300"
                  >
                    Discard
                  </button>
                </div>
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
