// Runs hourly (pg_cron, see README.md). Checks the weather at each
// subscribed device's place, and JMA's active storms once for everyone, and
// pushes the alerts whose rule fires and whose cooldown has passed. Rules
// live in rules.ts.
import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";
import {
  type Alert,
  alertsFor,
  type Conditions,
  parseJmaSpecs,
  type Storm,
  stormAlertsFor,
  type Subscription,
} from "./rules.ts";

const table = "alert_subscriptions";
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  // Deployed with --no-verify-jwt so pg_cron can call it; this header is
  // what keeps everyone else out.
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const { data, error } = await supabase.from(table).select("*");
  if (error) return new Response(error.message, { status: 500 });
  const subs = data as Subscription[];

  // Devices within the same ~11 km cell share one pair of requests.
  const cells = new Map<string, Subscription[]>();
  for (const s of subs) {
    const key = `${s.lat.toFixed(1)},${s.lon.toFixed(1)}`;
    cells.set(key, [...(cells.get(key) ?? []), s]);
  }

  const now = new Date();
  // Once per run for everyone; without it only storm alerts are skipped.
  const storms = await fetchStorms().catch((e) => {
    console.error("storms:", e);
    return [] as Storm[];
  });
  let fcm: Promise<FcmAuth> | undefined;
  let sent = 0;
  for (const [key, group] of cells) {
    let conditions: Conditions | null = null;
    try {
      conditions = await fetchConditions(key);
    } catch (e) {
      // One place failing shouldn't stop the others, nor its storm alerts;
      // the weather is retried next hour.
      console.error(`weather ${key}:`, e);
    }
    for (const sub of group) {
      const alerts = [
        ...(conditions === null ? [] : alertsFor(sub, conditions, now)),
        ...stormAlertsFor(sub, storms, now),
      ];
      if (alerts.length === 0) continue;
      fcm ??= fcmAuth();
      const lastSent = { ...sub.last_sent };
      let gone = false;
      for (const alert of alerts) {
        const result = await sendPush(await fcm, sub.fcm_token, alert);
        if (result === "unregistered") {
          gone = true;
          break;
        }
        if (result === "ok") {
          lastSent[alert.key ?? alert.type] = now.toISOString();
          sent++;
        }
      }
      // A dead token means the app was uninstalled or its data cleared.
      await (gone
        ? supabase.from(table).delete().eq("user_id", sub.user_id)
        : supabase.from(table).update({ last_sent: lastSent }).eq("user_id", sub.user_id));
    }
  }
  return Response.json({
    devices: subs.length,
    cells: cells.size,
    storms: storms.length,
    sent,
  });
});

async function fetchConditions(cell: string): Promise<Conditions> {
  const [latitude, longitude] = cell.split(",");
  const place = new URLSearchParams({ latitude, longitude });
  const forecast = await getJson(
    `https://api.open-meteo.com/v1/forecast?${place}&current=apparent_temperature,uv_index,is_day&minutely_15=precipitation&forecast_minutely_15=5&timezone=auto`,
  );
  // Air quality is a separate API; without it only the AQI rule is skipped.
  const air = await getJson(
    `https://air-quality-api.open-meteo.com/v1/air-quality?${place}&current=us_aqi`,
  ).catch(() => null);
  const current = forecast.current;
  return {
    // "2026-09-30T14:15", already local to the place.
    localHour: Number(current.time.slice(11, 13)),
    isDay: current.is_day === 1,
    feelsLike: current.apparent_temperature,
    uv: current.uv_index ?? 0,
    rainMm: forecast.minutely_15?.precipitation ?? [],
    aqi: air?.current?.us_aqi ?? null,
  };
}

/** Every cyclone JMA tracks now (jma.go.jp/bosai/typhoon/data/). */
async function fetchStorms(): Promise<Storm[]> {
  const base = "https://www.jma.go.jp/bosai/typhoon/data";
  const active = await getJson(`${base}/targetTc.json`);
  const storms = await Promise.all(
    // deno-lint-ignore no-explicit-any
    (active as any[]).map(async (t) => {
      const id = String(t?.tropicalCyclone ?? "");
      if (id === "") return null;
      // One storm's file failing drops that storm, not the run.
      const specs = await getJson(`${base}/${id}/specifications.json`)
        .catch(() => null);
      return Array.isArray(specs) ? parseJmaSpecs(id, specs) : null;
    }),
  );
  return storms.filter((s): s is Storm => s !== null);
}

async function getJson(url: string) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  return await res.json();
}

interface FcmAuth {
  token: string;
  projectId: string;
}

/** OAuth token for FCM HTTP v1 from the service account (secret). */
async function fcmAuth(): Promise<FcmAuth> {
  const account = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`OAuth ${res.status}: ${await res.text()}`);
  return { token: (await res.json()).access_token, projectId: account.project_id };
}

async function sendPush(
  auth: FcmAuth,
  token: string,
  alert: Alert,
): Promise<"ok" | "unregistered" | "failed"> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${auth.projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${auth.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: alert.title, body: alert.body },
          android: {
            priority: "high",
            // Same channel the app creates (alertsChannelId); the tag makes a
            // newer alert of a type (or of the same storm) replace the older.
            notification: {
              channel_id: "weather_alerts",
              tag: alert.key ?? alert.type,
            },
          },
          apns: {
            payload: {
              aps: { sound: "default", "thread-id": alert.key ?? alert.type },
            },
          },
        },
      }),
    },
  );
  if (res.ok) return "ok";
  const text = await res.text();
  if (res.status === 404 || text.includes("UNREGISTERED")) return "unregistered";
  console.error(`FCM ${res.status}: ${text}`);
  return "failed";
}
