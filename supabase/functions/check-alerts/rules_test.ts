// Run: deno test supabase/functions/check-alerts/
import { assertEquals } from "jsr:@std/assert@1";
import {
  alertsFor,
  beaufort,
  type Conditions,
  limitsFor,
  parseJmaSpecs,
  rainStartsIn,
  type Storm,
  stormAlertsFor,
  type Subscription,
} from "./rules.ts";

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

Deno.test("health profiles lower the thresholds", () => {
  assertEquals(limitsFor([]), { aqi: 150, feelsHot: 39, uv: 8 });
  assertEquals(limitsFor(["respiratory"]), { aqi: 100, feelsHot: 39, uv: 8 });
  assertEquals(limitsFor(["children"]), { aqi: 100, feelsHot: 37, uv: 6 });
  assertEquals(limitsFor(["elderly"]), { aqi: 100, feelsHot: 37, uv: 8 });

  const smoggy: Conditions = { ...calm, aqi: 120, feelsLike: 37.5, uv: 6.5 };
  // sub() has no `health`, like rows written before the column existed.
  assertEquals(alertsFor(sub(), smoggy, now), []);
  assertEquals(
    alertsFor(sub({ health: ["children"] }), smoggy, now).map((a) => a.type),
    ["uv", "air", "heat"],
  );
});

Deno.test("beaufort matches the app's bands", () => {
  const cases: [number, number][] = [
    [0, 0], [10.8, 6], [17.1, 7], [17.2, 8], [25, 10], [32.7, 12], [51, 16],
    [70, 17],
  ];
  for (const [ms, force] of cases) assertEquals(beaufort(ms), force, `${ms}`);
});

Deno.test("parseJmaSpecs reads JMA's shape and skips what it can't", () => {
  // Trimmed from a real specifications.json (Tropical Storm Surigae).
  const parts = [
    { part: "title", name: { en: "Surigae" }, category: { en: "TS" } },
    {
      advancedHours: 0,
      position: { deg: [31.7, 138.8] },
      maximumWind: { sustained: { "m/s": "18" }, gust: { "m/s": "25" } },
      category: { en: "TS" },
    },
    { advancedHours: 12, position: { deg: "moved" } },
    {
      advancedHours: 45,
      position: { deg: [40.9, 156.4] },
      maximumWind: { sustained: { "m/s": "-" } },
      category: { en: "LOW" },
    },
  ];
  assertEquals(parseJmaSpecs("TC2632", parts), {
    id: "TC2632",
    name: "Surigae",
    points: [
      { hoursAhead: 0, lat: 31.7, lon: 138.8, windMs: 18, gustMs: 25, isLow: false },
      { hoursAhead: 45, lat: 40.9, lon: 156.4, windMs: null, gustMs: null, isLow: true },
    ],
  });
  assertEquals(parseJmaSpecs("TC0", [{ part: "title" }]), null);
});

// Heading west across the South China Sea for Da Nang (16.05, 108.2).
const kajiki: Storm = {
  id: "TC2640",
  name: "Kajiki",
  points: [
    { hoursAhead: 0, lat: 15, lon: 118, windMs: 26, gustMs: 35, isLow: false },
    { hoursAhead: 24, lat: 15.8, lon: 111, windMs: 33, gustMs: 45, isLow: false },
    { hoursAhead: 96, lat: 16, lon: 108.3, windMs: 20, gustMs: null, isLow: false },
  ],
};
const daNang = sub({ lat: 16.05, lon: 108.2, types: ["storm"] });

Deno.test("a storm forecast to pass within 500 km gets one push", () => {
  const [alert, ...rest] = stormAlertsFor(daNang, [kajiki], now);
  assertEquals(rest, []);
  assertEquals(alert.key, "storm:TC2640");
  assertEquals(alert.title, "Theo dõi bão");
  assertEquals(
    alert.body,
    "Bão rất mạnh Kajiki dự kiến cách bạn khoảng 300 km sau 24 giờ. " +
      "Gió cấp 12, giật cấp 14.",
  );
  const en = stormAlertsFor({ ...daNang, locale: "en" }, [kajiki], now)[0];
  assertEquals(
    en.body,
    "Typhoon Kajiki is forecast to pass about 300 km from you in 24 h. " +
      "Force 12 winds, gusts force 14.",
  );
});

Deno.test("far, late, weak or opted-out storms send nothing", () => {
  const hanoi = sub({ types: ["storm"] }); // ~800 km from the 24 h point
  assertEquals(stormAlertsFor(hanoi, [kajiki], now), []);
  // Only the 96 h point reaches Da Nang: past the 72 h horizon.
  const late = { ...kajiki, points: [kajiki.points[0], kajiki.points[2]] };
  assertEquals(stormAlertsFor(daNang, [late], now), []);
  const weak: Storm = {
    ...kajiki,
    points: kajiki.points.map((p) => ({ ...p, windMs: 10 })),
  };
  assertEquals(stormAlertsFor(daNang, [weak], now), []);
  const low: Storm = {
    ...kajiki,
    points: kajiki.points.map((p) => ({ ...p, isLow: true })),
  };
  assertEquals(stormAlertsFor(daNang, [low], now), []);
  assertEquals(stormAlertsFor({ ...daNang, types: ["rain"] }, [kajiki], now), []);
});

Deno.test("each storm has its own 12-hour cooldown", () => {
  const ago = (h: number) => new Date(now.getTime() - h * 3_600_000).toISOString();
  const other: Storm = { ...kajiki, id: "TC2641", name: "Nongfa" };
  const recently = { ...daNang, last_sent: { "storm:TC2640": ago(11) } };
  assertEquals(
    stormAlertsFor(recently, [kajiki, other], now).map((a) => a.key),
    ["storm:TC2641"],
  );
  const earlier = { ...daNang, last_sent: { "storm:TC2640": ago(12) } };
  assertEquals(stormAlertsFor(earlier, [kajiki], now).length, 1);
});
