# check-alerts

Push weather alerts (rain soon, very high UV, unhealthy air, extreme heat). The app
writes one `alert_subscriptions` row per device (place, language, units, chosen
alert types, FCM token). `pg_cron` calls this function every 15 minutes. It checks
Open-Meteo for each place and sends pushes through FCM HTTP v1.

- Rules: `rules.ts` (tests: `deno test supabase/functions/check-alerts/`).
- Quiet hours: 22:00–6:00, in each place's local time.
- Cooldowns: rain alerts at most once every 3 hours; the other types once a day.

## Setup (once)

### 1. Firebase

1. Create a Firebase project. It doesn't need Analytics.
2. Add an **Android app** and an **iOS app**. Use the package `com.example.weather_application` (the `applicationId` in `android/app/build.gradle.kts`) and the bundle id `com.minhpt.skycast`. You don't need to download `google-services.json` or `GoogleService-Info.plist`; the app takes its keys from `--dart-define`.
3. Upload your **APNs auth key (.p8)**: Project settings → Cloud Messaging → Apple app configuration.
4. Create a service-account key: Project settings → Service accounts → Generate new private key. The key is a JSON file. **Keep it secret.** It goes only into the Supabase secret in step 3 below.
5. Add these keys to `supabase.json` (gitignored). See `supabase.example.json`.
   - `FIREBASE_PROJECT_ID` and `FIREBASE_SENDER_ID` (the "Project number").
   - `FIREBASE_ANDROID_API_KEY` and `FIREBASE_ANDROID_APP_ID`, from the Android app's settings.
   - `FIREBASE_IOS_API_KEY` and `FIREBASE_IOS_APP_ID`, from the iOS app's settings.

### 2. Database

Run `supabase/schema.sql` in the SQL Editor. It is idempotent for tables, but
re-running the `create policy` lines fails, so run only the new
`alert_subscriptions` part if the cities table already exists.

### 3. Function

```bash
supabase functions deploy check-alerts --no-verify-jwt
supabase secrets set CRON_SECRET="$(openssl rand -hex 32)"
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat path/to/service-account.json)"
```

`--no-verify-jwt` lets `pg_cron` call the function without a user token. The
`CRON_SECRET` header check in `index.ts` keeps other callers out.

### 4. Schedule

In the SQL Editor, use the same `CRON_SECRET` value and your project ref:

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

select vault.create_secret('<CRON_SECRET>', 'check_alerts_secret');

select cron.schedule('check-alerts', '*/15 * * * *', $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/check-alerts',
    headers := jsonb_build_object(
      'x-cron-secret',
      (select decrypted_secret from vault.decrypted_secrets
        where name = 'check_alerts_secret')
    ),
    timeout_milliseconds := 60000
  );
$$);
```

To check that it runs, look at the `net._http_response` table or at the function's logs in the
dashboard. Each run returns `{devices, cells, sent}`.

## Limits

The free Supabase and Open-Meteo tiers are plenty for a few hundred devices:
2 Open-Meteo calls per ~11 km cell, every 15 minutes. Places are processed one
after another. At a few thousand cells, a run would get close to the Edge
Function time limit, so the loop would need to fan out.
