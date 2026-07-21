export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

type EmptySchema = {
  Views: Record<string, never>
  Enums: Record<string, never>
  CompositeTypes: Record<string, never>
}

export type Database = {
  app: Omit<EmptySchema, 'Views'> & {
    Tables: {
      user_profiles: {
        Row: {
          user_id: string
          display_name: string
          username: string | null
          avatar_url: string | null
          title: string | null
          preferred_language: string
          timezone: string
          city_id: string | null
          country_code: string | null
          leaderboard_visibility: 'public' | 'friends' | 'private'
          prayer_map_visibility: 'aggregated' | 'hidden'
          created_at: string
          updated_at: string
        }
        Insert: never
        Update: Partial<{
          display_name: string
          username: string | null
          avatar_url: string | null
          title: string | null
          preferred_language: string
          timezone: string
          city_id: string | null
          country_code: string | null
          leaderboard_visibility: 'public' | 'friends' | 'private'
          prayer_map_visibility: 'aggregated' | 'hidden'
        }>
        Relationships: []
      }
      notifications: {
        Row: {
          id: string
          user_id: string
          notification_type: string
          title: string
          body: string | null
          action_url: string | null
          payload: Json
          read_at: string | null
          created_at: string
        }
        Insert: never
        Update: { read_at?: string | null }
        Relationships: []
      }
    }
    Views: {
      leaderboard_profiles: {
        Row: {
          user_id: string
          display_name: string
          username: string | null
          avatar_url: string | null
          title: string | null
        }
        Relationships: []
      }
    }
    Functions: Record<string, never>
  }
  competition: EmptySchema & {
    Tables: {
      spiritual_activities: {
        Row: {
          id: string
          user_id: string
          activity_code: string
          occurred_at: string
          completed_at: string | null
          duration_seconds: number | null
          quantity: number
          verification_status: 'self_reported' | 'verified' | 'rejected'
          source: 'manual' | 'challenge' | 'live_prayer' | 'import' | 'admin' | 'system'
          city_id: string | null
          country_code: string | null
          idempotency_key: string | null
          metadata: Json
          created_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      level_definitions: {
        Row: {
          level_number: number
          code: string
          name: string
          description: string | null
          minimum_total_xp: number
          icon_url: string | null
          image_url: string | null
          reward_type: string | null
          reward_reference_id: string | null
          is_active: boolean
          created_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      user_progress: {
        Row: {
          user_id: string
          total_xp: number
          current_level: number
          weekly_points: number
          yearly_points: number
          lifetime_points: number
          last_activity_at: string | null
          version: number
          updated_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      user_challenge_assignments: {
        Row: {
          id: string
          user_id: string
          challenge_definition_id: string
          assignment_date: string
          starts_at: string
          expires_at: string
          target_quantity: number
          current_progress: number
          status: 'active' | 'completed' | 'expired' | 'cancelled'
          completed_at: string | null
          reward_claimed_at: string | null
          created_at: string
          updated_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      challenge_definitions: {
        Row: {
          id: string
          code: string
          title: string
          description: string | null
          challenge_type: 'daily' | 'weekly' | 'special' | 'seasonal'
          activity_code: string | null
          target_quantity: number
          xp_reward: number
          badge_reward_id: string | null
          difficulty: 'easy' | 'normal' | 'hard' | 'heroic'
          assignment_weight: number
          rules: Json
          icon_url: string | null
          starts_at: string | null
          ends_at: string | null
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      badge_definitions: {
        Row: {
          id: string
          code: string
          name: string
          description: string | null
          category: string
          rarity: string
          icon_url: string
          locked_icon_url: string | null
          requirement_type: string | null
          requirement_value: number | null
          rules: Json
          points_reward: number
          is_repeatable: boolean
          is_shareable: boolean
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      user_badges: {
        Row: {
          id: string
          user_id: string
          badge_id: string
          earned_at: string
          source_type: string | null
          source_id: string | null
          sequence_number: number
          is_featured: boolean
          metadata: Json
        }
        Insert: never
        Update: { is_featured?: boolean }
        Relationships: []
      }
      user_badge_progress: {
        Row: {
          user_id: string
          badge_id: string
          current_value: number
          required_value: number
          progress_percentage: number
          updated_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      leaderboard_periods: {
        Row: {
          id: string
          period_type: 'daily' | 'weekly' | 'monthly' | 'yearly' | 'season'
          code: string
          name: string
          starts_at: string
          ends_at: string
          status: 'scheduled' | 'active' | 'calculating' | 'finalized'
          finalized_at: string | null
          created_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
      leaderboard_entries: {
        Row: {
          period_id: string
          user_id: string
          scope_type: 'global' | 'country' | 'city'
          scope_reference: string
          points: number
          rank: number | null
          rosaries_count: number
          scripture_readings_count: number
          prayers_count: number
          updated_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
    }
    Functions: Record<string, never>
  }
  prayer: EmptySchema & {
    Tables: {
      map_markers: {
        Row: {
          id: string
          aggregation_level: 'country' | 'city'
          location_reference: string
          name: string
          country_code: string
          latitude: number
          longitude: number
          prayer_count: number
          unique_users: number
          intensity: number
          period_start: string
          period_end: string
          updated_at: string
        }
        Insert: never
        Update: never
        Relationships: []
      }
    }
    Functions: Record<string, never>
  }
  api: EmptySchema & {
    Tables: Record<string, never>
    Functions: {
      record_spiritual_activity: {
        Args: {
          p_activity_code: string
          p_occurred_at: string
          p_completed_at?: string | null
          p_duration_seconds?: number | null
          p_quantity?: number
          p_city_id?: string | null
          p_country_code?: string | null
          p_idempotency_key: string
          p_metadata?: Json
        }
        Returns: Json
      }
      claim_challenge_reward: {
        Args: { p_assignment_id: string }
        Returns: Json
      }
    }
  }
}
