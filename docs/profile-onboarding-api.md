# Profile onboarding API

Profile setup requires a display name, gender, country, and notification
preferences. City selection is not part of a user profile.

Use `GET /api/v1/locations/countries` to search active countries, then submit
the completed setup to `POST /api/v1/me/onboarding/complete`.

```json
{
  "displayName": "Samuel Ruiz",
  "username": "SamuelR",
  "gender": "male",
  "countryCode": "US",
  "notificationPreferences": {
    "dailyRosaryReminder": true,
    "confessionReminder": true,
    "eucharisticAdoration": false
  }
}
```

Church directory records retain their own city text for search and display;
that information is independent of a profile location.
