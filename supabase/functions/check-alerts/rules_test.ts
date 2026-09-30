// Run: deno test supabase/functions/check-alerts/
import { assertEquals } from "jsr:@std/assert@1";
import { alertsFor, type Conditions, rainStartsIn, type Subscription } from "./rules.ts";

const now = new Date("2026-09-30T05:00:00Z");

const sub = (over: Partial<Subscription> = {}): Subscription => ({
  user_id: "u",
  fcm_token: "t",
  lat: 21.03,
  lon: 105.85,
  locale: "vi",
  fahrenheit: false,
  types: ["rain", "uv", "air", "heat"],
  last_sent: {},
  ...over,
});

const calm: Conditions = {
  localHour: 12,
  isDay: true,
  feelsLike: 30,
  uv: 5,
  rainMm: [0, 0, 0, 0],
  aqi: 60,
};

Deno.test("rainStartsIn: dry now, wet within the hour", () => {
  assertEquals(rainStartsIn([0, 0, 0.2, 1]), 30);
  assertEquals(rainStartsIn([0, 0.5]), 15);
  assertEquals(rainStartsIn([0, 0, 0, 0.3]), 45);
  assertEquals(rainStartsIn([0, 0, 0, 0, 0.3]), 60);
  assertEquals(rainStartsIn([0.3, 0.3]), null, "already raining");
  assertEquals(rainStartsIn([0, 0.1, null, 0.19]), null, "only drizzle");
  assertEquals(rainStartsIn([0, 0, 0, 0, 0, 1]), null, "next run's job");
  assertEquals(rainStartsIn([]), null);
});

Deno.test("calm weather sends nothing", () => {
  assertEquals(alertsFor(sub(), calm, now), []);
});

Deno.test("each rule fires on its threshold", () => {
  const bad: Conditions = {
    ...calm,
    rainMm: [0, 0.6],
    uv: 8,
    aqi: 151,
    feelsLike: 39,
  };
  assertEquals(
    alertsFor(sub(), bad, now).map((a) => a.type),
    ["rain", "uv", "air", "heat"],
  );
  const justUnder: Conditions = { ...calm, uv: 7.9, aqi: 150, feelsLike: 38.9 };
  assertEquals(alertsFor(sub(), justUnder, now), []);
  assertEquals(alertsFor(sub(), { ...bad, isDay: false }, now).map((a) => a.type), [
    "rain",
    "air",
    "heat",
  ]);
});

Deno.test("quiet hours, opted-out types and cooldowns suppress alerts", () => {
  const rain: Conditions = { ...calm, rainMm: [0, 0.6] };
  assertEquals(alertsFor(sub(), { ...rain, localHour: 22 }, now), []);
  assertEquals(alertsFor(sub(), { ...rain, localHour: 5 }, now), []);
  assertEquals(alertsFor(sub(), { ...rain, localHour: 6 }, now).length, 1);
  assertEquals(alertsFor(sub({ types: ["uv"] }), rain, now), []);
  const twoHoursAgo = new Date(now.getTime() - 2 * 3_600_000).toISOString();
  const threeHoursAgo = new Date(now.getTime() - 3 * 3_600_000).toISOString();
  assertEquals(alertsFor(sub({ last_sent: { rain: twoHoursAgo } }), rain, now), []);
  assertEquals(
    alertsFor(sub({ last_sent: { rain: threeHoursAgo } }), rain, now).length,
    1,
  );
});

Deno.test("text follows the subscriber's language and units", () => {
  const hot: Conditions = { ...calm, feelsLike: 40 };
  assertEquals(alertsFor(sub(), hot, now)[0].body.includes("40°"), true);
  const en = alertsFor(sub({ locale: "en", fahrenheit: true }), hot, now)[0];
  assertEquals(en.title, "Extreme heat");
  assertEquals(en.body.includes("104°"), true);
});
