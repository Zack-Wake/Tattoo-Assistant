import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import UnfinishedPiecesList from './UnfinishedPiecesList'
import type { Artist, UnfinishedPiece } from '@/lib/types'

export default async function DashboardPage() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  const [
    { data: artistRow },
    { data: unfinished },
    { count: openEnquiries },
    { count: upcomingSessions },
  ] = await Promise.all([
    supabase.from('artists').select('*').eq('id', user.id).single(),
    supabase.from('unfinished_pieces').select('*'),
    supabase
      .from('enquiries')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'open'),
    supabase
      .from('sessions')
      .select('*', { count: 'exact', head: true })
      .gte('scheduled_at', new Date().toISOString())
      .in('status', ['pending', 'confirmed']),
  ])

  if (!artistRow) redirect('/login')

  // Cast to rich application type — JSONB columns are safe to assert here
  const artist = artistRow as unknown as Artist

  const pieces = (unfinished ?? []) as UnfinishedPiece[]

  const stats = [
    {
      label: 'Unfinished pieces',
      value: pieces.length,
      description: 'multi-session, no follow-up booked',
      urgent: pieces.length > 0,
    },
    {
      label: 'Open enquiries',
      value: openEnquiries ?? 0,
      description: 'awaiting response',
      urgent: false,
    },
    {
      label: 'Upcoming sessions',
      value: upcomingSessions ?? 0,
      description: 'confirmed or pending',
      urgent: false,
    },
  ]

  return (
    <div className="min-h-screen bg-zinc-950 px-4 py-8 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-4xl space-y-8">

        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-zinc-100">{artist.name}</h1>
            <p className="text-sm text-zinc-500">Studio assistant</p>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {stats.map((stat) => (
            <div
              key={stat.label}
              className={`rounded-lg border p-4 ${
                stat.urgent
                  ? 'border-amber-500/40 bg-amber-500/5'
                  : 'border-zinc-800 bg-zinc-900'
              }`}
            >
              <p className="text-3xl font-bold text-zinc-100">{stat.value}</p>
              <p
                className={`mt-1 text-sm font-medium ${
                  stat.urgent ? 'text-amber-400' : 'text-zinc-300'
                }`}
              >
                {stat.label}
              </p>
              <p className="mt-0.5 text-xs text-zinc-500">{stat.description}</p>
            </div>
          ))}
        </div>

        {/* Unfinished pieces */}
        <div>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-base font-semibold text-zinc-100">Unfinished pieces</h2>
            <span className="text-xs text-zinc-500">
              Highest-value recoverable group — they already trust you
            </span>
          </div>
          <UnfinishedPiecesList pieces={pieces} artist={artist} />
        </div>

      </div>
    </div>
  )
}
