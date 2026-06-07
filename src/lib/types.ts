// Domain types — mirror the DB schema exactly.
// Re-generate with: supabase gen types typescript --project-id dzmxypuvufrrskivxicn

// Standard JSON type for JSONB columns — Supabase requires this in the Database generic
export type Json = string | number | boolean | null | Json[] | { [key: string]: Json }

export type ContactCategory =
  | 'new_enquiry'
  | 'active_client'
  | 'unfinished_piece'
  | 'past_client'
  | 'spam'

export type PieceStatus = 'in_progress' | 'complete' | 'abandoned'

export type SessionStatus =
  | 'pending'
  | 'confirmed'
  | 'completed'
  | 'no_show'
  | 'cancelled'

export type EnquirySource =
  | 'instagram_dm'
  | 'instagram_story_reply'
  | 'instagram_comment'
  | 'manual'

export type EnquiryStatus = 'open' | 'responded' | 'converted' | 'dropped'

export type DepositStatus = 'pending' | 'received' | 'forfeited' | 'refunded'

export type MessageDirection = 'inbound' | 'outbound'

export type ReplyStatus = 'none' | 'drafted' | 'approved' | 'sent'

export interface ToneProfile {
  greeting?: string
  sign_off?: string
  style_notes?: string
  sample_replies?: string[]
}

export interface DepositRules {
  amount_pence: number
  non_refundable: boolean
}

export interface Artist {
  id: string
  name: string
  email: string
  instagram_account_id: string | null
  tone_profile: ToneProfile
  deposit_rules: DepositRules
  working_hours: Record<string, unknown>
  created_at: string
  updated_at: string
}

export interface Contact {
  id: string
  artist_id: string
  instagram_user_id: string | null
  name: string | null
  phone: string | null
  email: string | null
  category: ContactCategory
  do_not_engage: boolean
  notes: string | null
  created_at: string
  updated_at: string
}

export interface Piece {
  id: string
  artist_id: string
  contact_id: string
  title: string | null
  description: string | null
  is_multi_session: boolean
  status: PieceStatus
  created_at: string
  updated_at: string
}

export interface Session {
  id: string
  artist_id: string
  contact_id: string
  piece_id: string | null
  scheduled_at: string
  duration_minutes: number
  status: SessionStatus
  deposit_paid: boolean
  notes: string | null
  created_at: string
  updated_at: string
}

export interface Enquiry {
  id: string
  artist_id: string
  contact_id: string
  source: EnquirySource
  message_text: string | null
  received_at: string
  status: EnquiryStatus
  converted_to_session_id: string | null
  response_time_minutes: number | null
  created_at: string
  updated_at: string
}

export interface Deposit {
  id: string
  artist_id: string
  contact_id: string
  session_id: string | null
  amount_pence: number
  status: DepositStatus
  received_at: string | null
  notes: string | null
  created_at: string
  updated_at: string
}

export interface Message {
  id: string
  artist_id: string
  contact_id: string
  instagram_message_id: string | null
  direction: MessageDirection
  content: string
  sent_at: string
  draft_reply: string | null
  reply_status: ReplyStatus
  created_at: string
}

export interface UnfinishedPiece {
  contact_id: string
  artist_id: string
  contact_name: string | null
  instagram_user_id: string | null
  category: ContactCategory
  piece_id: string
  piece_title: string | null
  piece_description: string | null
  sessions_completed: number
  last_session_at: string
}

// Supabase Database type — used to type the Supabase client.
// JSONB columns use `Json` (not the richer application interfaces) because
// Supabase's type machinery requires JSON-safe types for generic resolution.
// Application code casts to Artist / Contact etc. after fetching.
export interface Database {
  public: {
    Tables: {
      artists: {
        Row: {
          id: string
          name: string
          email: string
          instagram_account_id: string | null
          tone_profile: Json
          deposit_rules: Json
          working_hours: Json
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          name: string
          email: string
          instagram_account_id?: string | null
          tone_profile?: Json
          deposit_rules?: Json
          working_hours?: Json
          created_at?: string
          updated_at?: string
        }
        Update: {
          name?: string
          email?: string
          instagram_account_id?: string | null
          tone_profile?: Json
          deposit_rules?: Json
          working_hours?: Json
          updated_at?: string
        }
      }
      contacts: {
        Row: {
          id: string
          artist_id: string
          instagram_user_id: string | null
          name: string | null
          phone: string | null
          email: string | null
          category: ContactCategory
          do_not_engage: boolean
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          artist_id: string
          instagram_user_id?: string | null
          name?: string | null
          phone?: string | null
          email?: string | null
          category?: ContactCategory
          do_not_engage?: boolean
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          instagram_user_id?: string | null
          name?: string | null
          phone?: string | null
          email?: string | null
          category?: ContactCategory
          do_not_engage?: boolean
          notes?: string | null
          updated_at?: string
        }
      }
      pieces: {
        Row: {
          id: string
          artist_id: string
          contact_id: string
          title: string | null
          description: string | null
          is_multi_session: boolean
          status: PieceStatus
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          artist_id: string
          contact_id: string
          title?: string | null
          description?: string | null
          is_multi_session?: boolean
          status?: PieceStatus
          created_at?: string
          updated_at?: string
        }
        Update: {
          title?: string | null
          description?: string | null
          is_multi_session?: boolean
          status?: PieceStatus
          updated_at?: string
        }
      }
      sessions: {
        Row: {
          id: string
          artist_id: string
          contact_id: string
          piece_id: string | null
          scheduled_at: string
          duration_minutes: number
          status: SessionStatus
          deposit_paid: boolean
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          artist_id: string
          contact_id: string
          piece_id?: string | null
          scheduled_at: string
          duration_minutes?: number
          status?: SessionStatus
          deposit_paid?: boolean
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          piece_id?: string | null
          scheduled_at?: string
          duration_minutes?: number
          status?: SessionStatus
          deposit_paid?: boolean
          notes?: string | null
          updated_at?: string
        }
      }
      enquiries: {
        Row: {
          id: string
          artist_id: string
          contact_id: string
          source: EnquirySource
          message_text: string | null
          received_at: string
          status: EnquiryStatus
          converted_to_session_id: string | null
          response_time_minutes: number | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          artist_id: string
          contact_id: string
          source?: EnquirySource
          message_text?: string | null
          received_at?: string
          status?: EnquiryStatus
          converted_to_session_id?: string | null
          response_time_minutes?: number | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          source?: EnquirySource
          message_text?: string | null
          status?: EnquiryStatus
          converted_to_session_id?: string | null
          response_time_minutes?: number | null
          updated_at?: string
        }
      }
      deposits: {
        Row: {
          id: string
          artist_id: string
          contact_id: string
          session_id: string | null
          amount_pence: number
          status: DepositStatus
          received_at: string | null
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          artist_id: string
          contact_id: string
          session_id?: string | null
          amount_pence: number
          status?: DepositStatus
          received_at?: string | null
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          session_id?: string | null
          amount_pence?: number
          status?: DepositStatus
          received_at?: string | null
          notes?: string | null
          updated_at?: string
        }
      }
      messages: {
        Row: {
          id: string
          artist_id: string
          contact_id: string
          instagram_message_id: string | null
          direction: MessageDirection
          content: string
          sent_at: string
          draft_reply: string | null
          reply_status: ReplyStatus
          created_at: string
        }
        Insert: {
          id?: string
          artist_id: string
          contact_id: string
          instagram_message_id?: string | null
          direction: MessageDirection
          content: string
          sent_at: string
          draft_reply?: string | null
          reply_status?: ReplyStatus
          created_at?: string
        }
        Update: {
          draft_reply?: string | null
          reply_status?: ReplyStatus
        }
      }
    }
    Views: {
      unfinished_pieces: {
        Row: {
          contact_id: string
          artist_id: string
          contact_name: string | null
          instagram_user_id: string | null
          category: ContactCategory
          piece_id: string
          piece_title: string | null
          piece_description: string | null
          sessions_completed: number
          last_session_at: string
        }
      }
    }
    Functions: Record<string, never>
    Enums: {
      contact_category: ContactCategory
      piece_status: PieceStatus
      session_status: SessionStatus
      enquiry_source: EnquirySource
      enquiry_status: EnquiryStatus
      deposit_status: DepositStatus
      message_direction: MessageDirection
      reply_status: ReplyStatus
    }
  }
}
