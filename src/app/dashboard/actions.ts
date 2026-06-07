'use server'

import { createClient } from '@/lib/supabase/server'
import { draftFollowUpMessage } from '@/ai/draft-reply'
import type { UnfinishedPiece } from '@/lib/types'

export async function generateDraft(piece: UnfinishedPiece): Promise<string> {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const { data: artist, error } = await supabase
    .from('artists')
    .select('*')
    .eq('id', user.id)
    .single()

  if (error || !artist) throw new Error('Artist not found')

  return draftFollowUpMessage(artist, piece)
}
