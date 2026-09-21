export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

type EmptySchema = {
  Views: Record<string, never>;
  Enums: Record<string, never>;
  CompositeTypes: Record<string, never>;
};

export type Database = {
  app: Omit<EmptySchema, 'Views'> & {
    Tables: {
      examination_of_conscience_questions: {
        Row: {
          id: string;
          category: 'single' | 'married' | 'religious';
          title: string;
          commandment: number;
          severity: 'mortal' | 'grave';
          question: string;
          description: string;
          counsels: string[];
          prevention: string[];
          saints: string[];
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          category: 'single' | 'married' | 'religious';
          title: string;
          commandment: number;
          severity: 'mortal' | 'grave';
          question: string;
          description: string;
          counsels: string[];
          prevention: string[];
          saints: string[];
          is_active?: boolean;
        };
        Update: Partial<{
          category: 'single' | 'married' | 'religious';
          title: string;
          commandment: number;
          severity: 'mortal' | 'grave';
          question: string;
          description: string;
          counsels: string[];
          prevention: string[];
          saints: string[];
          is_active: boolean;
        }>;
        Relationships: [];
      };
      contact_requests: {
        Row: {
          id: string;
          name: string;
          email: string;
          subject:
            | 'Billing & Payments'
            | 'Subscription Management'
            | 'Login & Account Access'
            | 'App Performance & Bugs'
            | 'Audio & Playback Issues'
            | 'Streak & Progress Issues'
            | 'Content Feedback & Requests'
            | 'Prayer Intentions'
            | 'Grammar & Audio Mistakes'
            | 'Parish & Church Programs'
            | 'School & Ministry Licensing'
            | 'Media & Press Inquiries'
            | 'Other';
          other_subject: string | null;
          message: string;
          status: 'todo' | 'inprogress' | 'done';
          created_at: string;
        };
        Insert: {
          name: string;
          email: string;
          subject:
            | 'Billing & Payments'
            | 'Subscription Management'
            | 'Login & Account Access'
            | 'App Performance & Bugs'
            | 'Audio & Playback Issues'
            | 'Streak & Progress Issues'
            | 'Content Feedback & Requests'
            | 'Prayer Intentions'
            | 'Grammar & Audio Mistakes'
            | 'Parish & Church Programs'
            | 'School & Ministry Licensing'
            | 'Media & Press Inquiries'
            | 'Other';
          other_subject?: string | null;
          message: string;
          status?: 'todo' | 'inprogress' | 'done';
        };
        Update: Partial<{
          name: string;
          email: string;
          subject:
            | 'Billing & Payments'
            | 'Subscription Management'
            | 'Login & Account Access'
            | 'App Performance & Bugs'
            | 'Audio & Playback Issues'
            | 'Streak & Progress Issues'
            | 'Content Feedback & Requests'
            | 'Prayer Intentions'
            | 'Grammar & Audio Mistakes'
            | 'Parish & Church Programs'
            | 'School & Ministry Licensing'
            | 'Media & Press Inquiries'
            | 'Other';
          other_subject: string | null;
          message: string;
          status: 'todo' | 'inprogress' | 'done';
        }>;
        Relationships: [];
      };
      countries: {
        Row: {
          code: string;
          name: string;
          latitude: number | null;
          longitude: number | null;
          is_active: boolean;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_profiles: {
        Row: {
          user_id: string;
          display_name: string | null;
          username: string | null;
          avatar_url: string | null;
          title: string | null;
          gender: 'male' | 'female' | null;
          saint_avatar_id: string | null;
          preferred_language: string;
          timezone: string;
          country_code: string | null;
          leaderboard_visibility: 'public' | 'friends' | 'private';
          prayer_map_visibility: 'aggregated' | 'hidden';
          profile_setup_completed_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: Partial<{
          display_name: string | null;
          username: string | null;
          avatar_url: string | null;
          title: string | null;
          gender: 'male' | 'female' | null;
          saint_avatar_id: string | null;
          preferred_language: string;
          timezone: string;
          country_code: string | null;
          leaderboard_visibility: 'public' | 'friends' | 'private';
          prayer_map_visibility: 'aggregated' | 'hidden';
          profile_setup_completed_at: string | null;
        }>;
        Relationships: [];
      };
      notification_preferences: {
        Row: {
          user_id: string;
          daily_rosary_reminder: boolean;
          confession_reminder: boolean;
          eucharistic_adoration: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          daily_rosary_reminder?: boolean;
          confession_reminder?: boolean;
          eucharistic_adoration?: boolean;
        };
        Update: Partial<{
          daily_rosary_reminder: boolean;
          confession_reminder: boolean;
          eucharistic_adoration: boolean;
        }>;
        Relationships: [];
      };
      notifications: {
        Row: {
          id: string;
          user_id: string;
          notification_type: string;
          title: string;
          body: string | null;
          action_url: string | null;
          payload: Json;
          read_at: string | null;
          created_at: string;
        };
        Insert: never;
        Update: { read_at?: string | null };
        Relationships: [];
      };
      dioceses: {
        Row: {
          id: string;
          country_code: string;
          name: string;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      churches: {
        Row: {
          id: string;
          diocese_id: string | null;
          name: string;
          address_line_1: string;
          address_line_2: string | null;
          city: string;
          region_name: string | null;
          postal_code: string | null;
          country_code: string;
          timezone: string;
          latitude: number;
          longitude: number;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      church_service_times: {
        Row: {
          id: string;
          church_id: string;
          service_type: 'mass' | 'confession' | 'adoration';
          weekday: number;
          starts_at: string;
          ends_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_churches: {
        Row: {
          user_id: string;
          church_id: string;
          is_primary: boolean;
          linked_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_roles: {
        Row: {
          user_id: string;
          role: 'admin';
          granted_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      church_change_requests: {
        Row: {
          id: string;
          submitted_by: string;
          request_type: 'create_church' | 'schedule_update';
          church_id: string | null;
          proposed_church: Json;
          proposed_service_times: Json;
          notes: string | null;
          status: 'pending' | 'approved' | 'rejected';
          reviewed_by: string | null;
          reviewed_at: string | null;
          rejection_reason: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          submitted_by: string;
          request_type: 'create_church' | 'schedule_update';
          church_id?: string | null;
          proposed_church: Json;
          proposed_service_times: Json;
          notes?: string | null;
        };
        Update: never;
        Relationships: [];
      };
      friend_requests: {
        Row: {
          id: string;
          requester_id: string;
          recipient_id: string;
          status: 'pending' | 'accepted' | 'rejected' | 'cancelled';
          responded_at: string | null;
          cancelled_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      friendships: {
        Row: {
          id: string;
          user_low_id: string;
          user_high_id: string;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
    };
    Views: {
      leaderboard_profiles: {
        Row: {
          user_id: string;
          display_name: string;
          username: string | null;
          avatar_url: string | null;
          title: string | null;
          country_code: string | null;
          saint_avatar_id: string | null;
        };
        Relationships: [];
      };
    };
    Functions: {
      is_current_user_admin: {
        Args: Record<string, never>;
        Returns: boolean;
      };
    };
  };
  competition: EmptySchema & {
    Tables: {
      spiritual_activities: {
        Row: {
          id: string;
          user_id: string;
          activity_code: string;
          occurred_at: string;
          completed_at: string | null;
          duration_seconds: number | null;
          quantity: number;
          verification_status: 'self_reported' | 'verified' | 'rejected';
          source:
            | 'manual'
            | 'challenge'
            | 'live_prayer'
            | 'import'
            | 'admin'
            | 'system';
          country_code: string | null;
          idempotency_key: string | null;
          metadata: Json;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      level_definitions: {
        Row: {
          level_number: number;
          code: string;
          name: string;
          description: string | null;
          minimum_total_xp: number;
          icon_url: string | null;
          image_url: string | null;
          reward_type: string | null;
          reward_reference_id: string | null;
          is_active: boolean;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_progress: {
        Row: {
          user_id: string;
          total_xp: number;
          current_level: number;
          weekly_points: number;
          yearly_points: number;
          lifetime_points: number;
          last_activity_at: string | null;
          version: number;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_challenge_assignments: {
        Row: {
          id: string;
          user_id: string;
          challenge_definition_id: string;
          assignment_date: string;
          starts_at: string;
          expires_at: string;
          target_quantity: number;
          current_progress: number;
          status: 'active' | 'completed' | 'expired' | 'cancelled';
          completed_at: string | null;
          reward_claimed_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      challenge_definitions: {
        Row: {
          id: string;
          code: string;
          title: string;
          description: string | null;
          challenge_type: 'daily' | 'weekly' | 'special' | 'seasonal';
          activity_code: string | null;
          target_quantity: number;
          xp_reward: number;
          badge_reward_id: string | null;
          difficulty: 'easy' | 'normal' | 'hard' | 'heroic';
          assignment_weight: number;
          rules: Json;
          icon_url: string | null;
          starts_at: string | null;
          ends_at: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      badge_definitions: {
        Row: {
          id: string;
          code: string;
          name: string;
          description: string | null;
          category: string;
          rarity: string;
          icon_url: string;
          locked_icon_url: string | null;
          requirement_type: string | null;
          requirement_value: number | null;
          rules: Json;
          points_reward: number;
          is_repeatable: boolean;
          is_shareable: boolean;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_badges: {
        Row: {
          id: string;
          user_id: string;
          badge_id: string;
          earned_at: string;
          source_type: string | null;
          source_id: string | null;
          sequence_number: number;
          is_featured: boolean;
          metadata: Json;
        };
        Insert: never;
        Update: { is_featured?: boolean };
        Relationships: [];
      };
      user_badge_progress: {
        Row: {
          user_id: string;
          badge_id: string;
          current_value: number;
          required_value: number;
          progress_percentage: number;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      leaderboard_periods: {
        Row: {
          id: string;
          period_type: 'weekly' | 'yearly';
          code: string;
          name: string;
          starts_at: string;
          ends_at: string;
          status: 'scheduled' | 'active' | 'calculating' | 'finalized';
          finalized_at: string | null;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      leaderboard_entries: {
        Row: {
          period_id: string;
          user_id: string;
          scope_type: 'global' | 'country';
          scope_reference: string;
          points: number;
          rank: number | null;
          rosaries_count: number;
          scripture_readings_count: number;
          prayers_count: number;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      virtue_definitions: {
        Row: {
          code: string;
          name: string;
          description: string | null;
          default_value: number;
          icon: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      saint_definitions: {
        Row: {
          id: string;
          code: string;
          name: string;
          description: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      demon_definitions: {
        Row: {
          id: string;
          code: string;
          name: string;
          title: string;
          description: string | null;
          category: string;
          silly_personality: string | null;
          saint_mentor_id: string | null;
          saint_mentor_reason: string | null;
          max_hp: number;
          safety_note: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      demon_virtue_affinities: {
        Row: {
          demon_id: string;
          virtue_code: string;
          affinity_type: 'primary' | 'secondary';
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      demon_attacks: {
        Row: {
          id: string;
          demon_id: string;
          code: string;
          name: string;
          description: string | null;
          target_virtue_code: string;
          virtue_decrease: number;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      demon_defenses: {
        Row: {
          id: string;
          demon_id: string;
          code: string;
          name: string;
          challenge: string;
          reward_virtue_code: string;
          virtue_increase: number;
          demon_damage: number;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      demon_defeat_rewards: {
        Row: {
          demon_id: string;
          virtue_code: string;
          virtue_increase: number;
          xp_reward: number;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      badge_requirement_definitions: {
        Row: {
          id: string;
          badge_id: string;
          requirement_type: string;
          required_value: number;
          description: string | null;
          rules: Json;
          display_order: number;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_badge_requirement_progress: {
        Row: {
          user_id: string;
          badge_requirement_id: string;
          current_value: number;
          required_value: number;
          completed_at: string | null;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_virtues: {
        Row: {
          user_id: string;
          virtue_code: string;
          current_value: number;
          version: number;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_demon_encounters: {
        Row: {
          id: string;
          user_id: string;
          demon_id: string;
          status: 'active' | 'defeated' | 'abandoned' | 'expired';
          max_hp: number;
          current_hp: number;
          started_at: string;
          ended_at: string | null;
          defeated_at: string | null;
          version: number;
          metadata: Json;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      user_demon_defense_assignments: {
        Row: {
          id: string;
          encounter_id: string;
          defense_id: string;
          assignment_sequence: number;
          status: 'assigned' | 'completed' | 'expired' | 'cancelled';
          assigned_at: string;
          expires_at: string | null;
          completed_at: string | null;
          challenge_assignment_id: string | null;
          metadata: Json;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      virtue_events: {
        Row: {
          id: string;
          user_id: string;
          virtue_code: string;
          encounter_id: string | null;
          source_type: string;
          source_id: string | null;
          previous_value: number;
          delta: number;
          resulting_value: number;
          idempotency_key: string;
          metadata: Json;
          occurred_at: string;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      demon_battle_events: {
        Row: {
          id: string;
          encounter_id: string;
          event_type: 'attack' | 'defense_completed' | 'demon_defeated';
          attack_id: string | null;
          defense_assignment_id: string | null;
          virtue_event_id: string;
          previous_hp: number;
          demon_damage: number;
          resulting_hp: number;
          idempotency_key: string;
          metadata: Json;
          occurred_at: string;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
    };
    Functions: {
      refresh_leaderboard_period: {
        Args: { p_period_id: string };
        Returns: undefined;
      };
      refresh_leaderboards: {
        Args: {
          p_backfill?: boolean | null;
          p_as_of?: string | null;
        };
        Returns: undefined;
      };
    };
  };
  prayer: Omit<EmptySchema, 'Views'> & {
    Tables: {
      map_markers: {
        Row: {
          id: string;
          aggregation_level: 'country';
          location_reference: string;
          name: string;
          country_code: string;
          latitude: number;
          longitude: number;
          prayer_count: number;
          unique_users: number;
          intensity: number;
          period_start: string;
          period_end: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      prayer_intentions: {
        Row: {
          id: string;
          creator_id: string;
          title: string;
          description: string;
          symbol: 'candle' | 'cross' | 'dove' | 'olive_branch' | null;
          status: 'pending' | 'visible' | 'rejected';
          reviewed_by: string | null;
          reviewed_at: string | null;
          expires_at: string | null;
          created_at: string;
        };
        Insert: {
          creator_id: string;
          title: string;
          description: string;
          symbol?: 'candle' | 'cross' | 'dove' | 'olive_branch' | null;
        };
        Update: never;
        Relationships: [];
      };
      prayer_intention_approval_counts: {
        Row: {
          user_id: string;
          approved_count: number;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      prayer_intention_prayers: {
        Row: {
          id: string;
          intention_id: string;
          user_id: string;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
    };
    Views: {
      prayer_intention_cards: {
        Row: {
          id: string;
          title: string;
          description: string;
          symbol: 'candle' | 'cross' | 'dove' | 'olive_branch' | null;
          approved_at: string;
          expires_at: string;
          created_at: string;
          creator_display_name: string;
          creator_avatar_url: string | null;
          creator_country_code: string | null;
          prayer_count: number;
        };
        Relationships: [];
      };
      my_prayer_intention_summaries: {
        Row: {
          id: string;
          title: string;
          description: string;
          symbol: 'candle' | 'cross' | 'dove' | 'olive_branch' | null;
          status: 'pending' | 'visible' | 'rejected';
          created_at: string;
          reviewed_at: string | null;
          expires_at: string | null;
          prayer_count: number;
        };
        Relationships: [];
      };
      prayer_intention_prayer_participants: {
        Row: {
          id: string;
          intention_id: string;
          user_id: string;
          created_at: string;
          display_name: string;
          avatar_url: string | null;
          country_code: string | null;
        };
        Relationships: [];
      };
    };
    Functions: Record<string, never>;
  };
  api: EmptySchema & {
    Tables: Record<string, never>;
    Functions: {
      record_spiritual_activity: {
        Args: {
          p_activity_code: string;
          p_occurred_at: string;
          p_completed_at?: string | null;
          p_duration_seconds?: number | null;
          p_quantity?: number;
          p_country_code?: string | null;
          p_idempotency_key: string;
          p_metadata?: Json;
        };
        Returns: Json;
      };
      claim_challenge_reward: {
        Args: { p_assignment_id: string; p_idempotency_key: string };
        Returns: Json;
      };
      start_demon_encounter: {
        Args: { p_demon_code: string; p_idempotency_key: string };
        Returns: Json;
      };
      complete_demon_defense: {
        Args: {
          p_encounter_id: string;
          p_assignment_id: string;
          p_idempotency_key: string;
        };
        Returns: Json;
      };
      abandon_demon_encounter: {
        Args: { p_encounter_id: string; p_idempotency_key: string };
        Returns: Json;
      };
      get_my_rosary_completion: {
        Args: { p_year?: number | null; p_month?: number | null };
        Returns: Json;
      };
      get_admin_app_metrics: {
        Args: Record<string, never>;
        Returns: Json;
      };
      get_my_daily_rosary_reminder: {
        Args: Record<string, never>;
        Returns: Json;
      };
      get_my_rosary_streak: {
        Args: Record<string, never>;
        Returns: Json;
      };
      get_my_rosary_stats: {
        Args: Record<string, never>;
        Returns: Json;
      };
      get_global_rosary_stats: {
        Args: Record<string, never>;
        Returns: Json;
      };
      search_users: {
        Args: {
          p_query: string;
          p_limit?: number | null;
          p_offset?: number | null;
        };
        Returns: Array<{
          username: string;
          avatar_url: string | null;
          title: string | null;
          relationship_state:
            | 'none'
            | 'outgoingPending'
            | 'incomingPending'
            | 'friends';
        }>;
      };
      check_username_availability: {
        Args: { p_usernames: string[] };
        Returns: Array<{
          username: string;
          is_available: boolean;
        }>;
      };
      complete_current_user_profile_setup: {
        Args: {
          p_display_name: string;
          p_username: string | null;
          p_gender: 'male' | 'female';
          p_country_code: string;
          p_daily_rosary_reminder: boolean;
          p_confession_reminder: boolean;
          p_eucharistic_adoration: boolean;
        };
        Returns: Json;
      };
      search_countries: {
        Args: {
          p_query?: string | null;
          p_limit?: number | null;
          p_offset?: number | null;
        };
        Returns: Array<{
          code: string;
          name: string;
          latitude: number | null;
          longitude: number | null;
        }>;
      };
      search_churches: {
        Args: {
          p_country_code?: string | null;
          p_city?: string | null;
          p_diocese?: string | null;
          p_limit?: number | null;
          p_offset?: number | null;
        };
        Returns: Array<{
          id: string;
          name: string;
          city: string;
          region_name: string | null;
          country_code: string;
          diocese_name: string | null;
          timezone: string;
          latitude: number;
          longitude: number;
        }>;
      };
      link_current_user_church: {
        Args: { p_church_id: string; p_is_primary?: boolean | null };
        Returns: Json;
      };
      set_current_user_primary_church: {
        Args: { p_church_id: string };
        Returns: Json;
      };
      unlink_current_user_church: {
        Args: { p_church_id: string };
        Returns: Json;
      };
      review_church_change_request: {
        Args: {
          p_request_id: string;
          p_decision: string;
          p_rejection_reason?: string | null;
        };
        Returns: Json;
      };
      review_prayer_intention: {
        Args: { p_intention_id: string; p_decision: string };
        Returns: Json;
      };
      record_prayer_intention_prayer: {
        Args: { p_intention_id: string };
        Returns: Json;
      };
      send_current_user_friend_request: {
        Args: { p_username: string };
        Returns: Json;
      };
      review_current_user_friend_request: {
        Args: { p_request_id: string; p_decision: string };
        Returns: Json;
      };
      cancel_current_user_friend_request: {
        Args: { p_request_id: string };
        Returns: Json;
      };
      unfriend_current_user: {
        Args: { p_friend_id: string };
        Returns: Json;
      };
      list_current_user_friend_requests: {
        Args: {
          p_direction?: string | null;
          p_status?: string | null;
          p_limit?: number | null;
          p_offset?: number | null;
        };
        Returns: Array<{
          id: string;
          status: 'pending' | 'accepted' | 'rejected' | 'cancelled';
          direction: 'incoming' | 'outgoing';
          created_at: string;
          responded_at: string | null;
          cancelled_at: string | null;
          user_id: string;
          display_name: string;
          username: string | null;
          avatar_url: string | null;
          title: string | null;
          country_code: string | null;
        }>;
      };
      list_current_user_friends: {
        Args: {
          p_include_rosary_streak?: boolean | null;
          p_limit?: number | null;
          p_offset?: number | null;
        };
        Returns: Array<{
          friend_id: string;
          display_name: string;
          username: string | null;
          avatar_url: string | null;
          title: string | null;
          total_xp: number;
          current_level: number;
          level_code: string | null;
          level_name: string | null;
          rosary_total: number;
          badge_count: number;
          friends_since: string;
          rosary_streak: Json | null;
          country_code: string | null;
        }>;
      };
      get_current_user_friend_details: {
        Args: {
          p_friend_id: string;
          p_include_rosary_streak?: boolean | null;
        };
        Returns: Json;
      };
      get_current_user_friends_leaderboard: {
        Args: {
          p_period_type?: string | null;
          p_period_code?: string | null;
          p_limit?: number | null;
          p_offset?: number | null;
        };
        Returns: Json;
      };
      get_current_user_friends_comparison: {
        Args: {
          p_period_type?: string | null;
          p_period_code?: string | null;
          p_limit?: number | null;
          p_offset?: number | null;
        };
        Returns: Json;
      };
    };
  };
};
