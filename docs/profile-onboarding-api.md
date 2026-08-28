# Required profile onboarding API

The onboarding source of truth is the canonical current profile. A profile is
complete only when `displayName`, `gender`, `countryCode`, and a structured
`cityId` are valid. `profileSetup.completedAt` is audit metadata and never
overrides missing required data.

Use the API in this order:

1. Load `GET /api/v1/me` and initialize the wizard from the saved values.
2. Start at `profileSetup.nextStep` when `profileSetup.complete` is false.
3. Save each profile screen through `PATCH /api/v1/me`.
4. Use `GET /api/v1/usernames/validate` for debounced username checks.
5. Use the country and country-scoped city autocomplete endpoints for location.
6. Load and incrementally save reminders through
   `GET/PATCH /api/v1/me/notification-preferences`.
7. Send the full state to `POST /api/v1/me/onboarding/complete` when the user
   selects Enter the Mission.

The completion operation validates that the city belongs to the country and
saves the profile and preferences in one database transaction. The client
should navigate with replacement only after this request succeeds.

New Supabase Auth users are bootstrapped into `app.users`,
`app.user_profiles`, and `app.notification_preferences` by a database trigger.
Incomplete profile values remain null until the user supplies them; placeholder
values are not used to bypass the required setup guard.

## Sample responses

The values below are illustrative. UUIDs, timestamps, generated username
suggestions, and pagination metadata vary by request. All `/api/v1` routes in
this document require a Supabase access token.

### Supabase Auth sign-up

Sign-up is performed through `supabase.auth.signUp`, not a custom `/api/v1`
route. With email confirmation enabled, a successful call normally returns a
user while `session` remains `null` until confirmation.

```json
{
  "data": {
    "user": {
      "id": "9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002",
      "email": "samuel@example.com",
      "aud": "authenticated",
      "role": "authenticated",
      "email_confirmed_at": null
    },
    "session": null
  },
  "error": null
}
```

### Supabase Auth sign-in

Sign-in is performed through `supabase.auth.signInWithPassword`. Tokens below
are deliberately redacted.

```json
{
  "data": {
    "user": {
      "id": "9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002",
      "email": "samuel@example.com",
      "aud": "authenticated",
      "role": "authenticated"
    },
    "session": {
      "access_token": "<SUPABASE_ACCESS_TOKEN>",
      "refresh_token": "<SUPABASE_REFRESH_TOKEN>",
      "token_type": "bearer",
      "expires_in": 3600
    }
  },
  "error": null
}
```

Email confirmation links return an HTTP redirect rather than a JSON payload.
The browser follows the configured callback URL and establishes the session
before profile completeness is loaded.

### `GET /api/v1/me`

An incomplete profile makes the resume decision explicit:

```json
{
  "data": {
    "userId": "9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002",
    "displayName": "Samuel Ruiz",
    "username": "SamuelR",
    "avatarUrl": null,
    "title": null,
    "gender": "male",
    "saintAvatarId": null,
    "preferredLanguage": "en",
    "timezone": "America/Chicago",
    "cityId": null,
    "cityName": null,
    "state": null,
    "countryCode": "US",
    "countryName": "United States",
    "leaderboardVisibility": "public",
    "prayerMapVisibility": "aggregated",
    "profileSetup": {
      "complete": false,
      "missingFields": ["city"],
      "nextStep": "city",
      "completedAt": null
    },
    "createdAt": "2026-08-28T18:40:00.000Z",
    "updatedAt": "2026-08-28T18:48:00.000Z"
  }
}
```

### `PATCH /api/v1/me`

The response has the same shape as `GET /api/v1/me` and contains the complete
profile after the incremental update. For example, saving the missing city
returns:

```json
{
  "data": {
    "userId": "9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002",
    "displayName": "Samuel Ruiz",
    "username": "SamuelR",
    "avatarUrl": null,
    "title": null,
    "gender": "male",
    "saintAvatarId": null,
    "preferredLanguage": "en",
    "timezone": "America/Chicago",
    "cityId": "e0000000-0000-4000-8000-000000000001",
    "cityName": "Austin",
    "state": "Texas",
    "countryCode": "US",
    "countryName": "United States",
    "leaderboardVisibility": "public",
    "prayerMapVisibility": "aggregated",
    "profileSetup": {
      "complete": true,
      "missingFields": [],
      "nextStep": null,
      "completedAt": null
    },
    "createdAt": "2026-08-28T18:40:00.000Z",
    "updatedAt": "2026-08-28T18:51:00.000Z"
  }
}
```

`profileSetup.complete` can be `true` before Enter the Mission, while
`completedAt` remains `null`. Required stored fields—not the audit timestamp—are
the source of truth.

### `GET /api/v1/usernames/validate?username=joyful_clare`

Available username:

```json
{
  "data": {
    "username": "joyful_clare",
    "normalizedUsername": "joyful_clare",
    "valid": true,
    "available": true,
    "reason": null,
    "suggestions": [
      "faithful_clare1842",
      "monica_dove7391",
      "hopeful_pilgrim2318",
      "dominic_witness4430",
      "joyful_rosary8724"
    ]
  }
}
```

Taken username:

```json
{
  "data": {
    "username": "TakenName",
    "normalizedUsername": "takenname",
    "valid": true,
    "available": false,
    "reason": "USERNAME_TAKEN",
    "suggestions": [
      "humble_teresa1842",
      "kolbe_fisher7391",
      "peaceful_lantern2318",
      "francis_witness4430",
      "prayerful_dove8724"
    ]
  }
}
```

### `GET /api/v1/locations/countries?q=united&limit=20&offset=0`

```json
{
  "data": [
    {
      "code": "US",
      "name": "United States",
      "latitude": 39.8283,
      "longitude": -98.5795
    }
  ],
  "meta": {
    "limit": 20,
    "offset": 0,
    "hasMore": false,
    "nextOffset": null
  }
}
```

### `GET /api/v1/locations/cities?countryCode=US&q=aus&limit=20&offset=0`

```json
{
  "data": [
    {
      "id": "e0000000-0000-4000-8000-000000000001",
      "name": "Austin",
      "regionName": "Texas",
      "countryCode": "US",
      "timezone": "America/Chicago",
      "latitude": 30.26715,
      "longitude": -97.74306
    }
  ],
  "meta": {
    "limit": 20,
    "offset": 0,
    "hasMore": false,
    "nextOffset": null
  }
}
```

### `GET /api/v1/me/notification-preferences`

```json
{
  "data": {
    "dailyRosaryReminder": true,
    "confessionReminder": true,
    "eucharisticAdoration": true
  }
}
```

### `PATCH /api/v1/me/notification-preferences`

```json
{
  "data": {
    "dailyRosaryReminder": true,
    "confessionReminder": true,
    "eucharisticAdoration": false
  }
}
```

### `POST /api/v1/me/onboarding/complete`

```json
{
  "data": {
    "profile": {
      "userId": "9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002",
      "displayName": "Samuel Ruiz",
      "username": "SamuelR",
      "avatarUrl": null,
      "title": null,
      "gender": "male",
      "saintAvatarId": null,
      "preferredLanguage": "en",
      "timezone": "America/Chicago",
      "cityId": "e0000000-0000-4000-8000-000000000001",
      "cityName": "Austin",
      "state": "Texas",
      "countryCode": "US",
      "countryName": "United States",
      "leaderboardVisibility": "public",
      "prayerMapVisibility": "aggregated",
      "profileSetup": {
        "complete": true,
        "missingFields": [],
        "nextStep": null,
        "completedAt": "2026-08-28T18:52:34.591Z"
      },
      "createdAt": "2026-08-28T18:40:00.000Z",
      "updatedAt": "2026-08-28T18:52:34.591Z"
    },
    "notificationPreferences": {
      "dailyRosaryReminder": true,
      "confessionReminder": true,
      "eucharisticAdoration": false
    }
  }
}
```

## Common error response

Validation, duplicate username, authentication, and database failures use the
shared API error envelope. The status and error code vary by failure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request payload is invalid.",
    "details": {
      "formErrors": [],
      "fieldErrors": {
        "displayName": ["Display name is required."]
      }
    },
    "requestId": "4e03eb66-0a52-4fb4-83b3-c7ca9ea3a4b4"
  }
}
```
