// Pure alert rules, kept apart from index.ts so they can be unit-tested
// (rules_test.ts) without network or secrets.

/** Same names as the app's `AlertType` enum. */
export type AlertType = "rain" | "uv" | "air" | "heat" | "storm";

/** Same names as the app's `HealthProfile` enum. */
export type HealthProfile = "respiratory" | "children" | "elderly";

export interface Subscription {
  user_id: string;
  fcm_token: string;
  lat: number;
  lon: number;
  locale: string;
  fahrenheit: boolean;
  types: AlertType[];
  /** Missing on rows written before health profiles existed. */
  health?: HealthProfile[];
  /** Alert key (the type, or "storm:<JMA id>") → ISO time last sent. */
  last_sent: Partial<Record<string, string>>;
}

/** What one forecast + air-quality request says about a place right now. */
export interface Conditions {
  /** Hour of day at the place (Open-Meteo timezone=auto). */
  localHour: number;
  isDay: boolean;
  /** °C. */
  feelsLike: number;
  uv: number;
  /** mm per 15-minute slot, starting with the current slot. */
  rainMm: (number | null)[];
  /** US AQI; null where the air-quality model has no coverage. */
  aqi: number | null;
}

export interface Alert {
  type: AlertType;
  title: string;
  body: string;
  /** Cooldown key in last_sent; the type unless one type has several. */
  key?: string;
}

const hour = 3_600_000;

// Rain comes and goes several times a day; the others describe the day, so
// once is enough.
const cooldown: Record<AlertType, number> = {
  rain: 3 * hour,
  uv: 20 * hour,
  air: 20 * hour,
  heat: 20 * hour,
  // Per storm: often enough to follow a change of track, not every run.
  storm: 12 * hour,
};

/**
 * Minutes until rain starts, when it's dry now and the first wet slot
 * (≥ 0.2 mm, the app's rainOutlook threshold) is within the hour: the
 * function runs hourly, so rain starting later is caught by the next run.
 */
export function rainStartsIn(mm: (number | null)[]): number | null {
  const wet = mm.map((v) => (v ?? 0) >= 0.2);
  if (wet.length === 0 || wet[0]) return null;
  const i = wet.indexOf(true);
  return i > 0 && i <= 4 ? i * 15 : null;
}

/**
 * Push thresholds: worth interrupting someone for, so a notch above the
 * app's own tips (Limits in weather.dart). EPA counts children, older adults
 * and people with lung disease as sensitive to air from AQI 100; for
 * everyone else it's "unhealthy" from 150.
 */
export function limitsFor(health: HealthProfile[]) {
  const young = health.includes("children");
  const old = health.includes("elderly");
  return {
    aqi: health.length > 0 ? 100 : 150,
    feelsHot: young || old ? 37 : 39,
    uv: young ? 6 : 8,
  };
}

export function alertsFor(
  sub: Subscription,
  c: Conditions,
  now: Date,
): Alert[] {
  // Local night: nobody wants a rain alert at 3:00.
  if (c.localHour >= 22 || c.localHour < 6) return [];
  const due = (t: AlertType) => {
    if (!sub.types.includes(t)) return false;
    const last = sub.last_sent[t];
    return last === undefined || now.getTime() - Date.parse(last) >= cooldown[t];
  };
  const vi = sub.locale === "vi";
  const limits = limitsFor(sub.health ?? []);
  const temp = (celsius: number) =>
    `${Math.round(sub.fahrenheit ? celsius * 9 / 5 + 32 : celsius)}°`;
  const alerts: Alert[] = [];

  const minutes = rainStartsIn(c.rainMm);
  if (minutes !== null && due("rain")) {
    alerts.push({
      type: "rain",
      title: vi ? "Sắp mưa" : "Rain soon",
      body: vi
        ? `Mưa có thể bắt đầu sau khoảng ${minutes} phút ở chỗ bạn.`
        : `Rain may start in about ${minutes} min where you are.`,
    });
  }
  if (c.isDay && c.uv >= limits.uv && due("uv")) {
    const uv = Math.round(c.uv);
    alerts.push({
      type: "uv",
      title: vi ? "UV rất cao" : "Very high UV",
      body: vi
        ? `Chỉ số UV đang là ${uv}. Hạn chế ra nắng và bôi kem chống nắng.`
        : `The UV index is ${uv}. Limit time in the sun and wear sunscreen.`,
    });
  }
  if (c.aqi !== null && c.aqi > limits.aqi && due("air")) {
    alerts.push({
      type: "air",
      title: vi ? "Không khí xấu" : "Unhealthy air",
      body: vi
        ? `AQI đang là ${c.aqi}, có hại cho sức khỏe. Nên đeo khẩu trang khi ra ngoài.`
        : `The AQI is ${c.aqi}, unhealthy. Consider a mask outdoors.`,
    });
  }
  if (c.feelsLike >= limits.feelsHot && due("heat")) {
    alerts.push({
      type: "heat",
      title: vi ? "Nắng nóng gay gắt" : "Extreme heat",
      body: vi
        ? `Cảm giác như ${temp(c.feelsLike)}. Uống đủ nước và tránh ra ngoài giờ trưa.`
        : `Feels like ${temp(c.feelsLike)}. Drink water and avoid the midday sun.`,
    });
  }
  return alerts;
}

/** One JMA forecast time for a storm, as used by [stormAlertsFor]. */
export interface StormPoint {
  hoursAhead: number;
  lat: number;
  lon: number;
  /** 10-minute sustained wind, m/s. */
  windMs: number | null;
  gustMs: number | null;
  /** Forecast to have become an ordinary low. */
  isLow: boolean;
}

export interface Storm {
  id: string;
  name: string | null;
  points: StormPoint[];
}

/**
 * JMA's undocumented specifications.json, read the same defensive way as
 * the app's storm_dto.dart: a part without a usable position is skipped,
 * and a storm with none is null.
 */
// deno-lint-ignore no-explicit-any
export function parseJmaSpecs(id: string, parts: any[]): Storm | null {
  const num = (v: unknown) => {
    const n = typeof v === "number" ? v : Number.parseFloat(String(v));
    return Number.isFinite(n) ? n : null;
  };
  const points: StormPoint[] = [];
  for (const p of parts.slice(1)) {
    const [lat, lon] = p?.position?.deg ?? [];
    if (typeof lat !== "number" || typeof lon !== "number") continue;
    if (typeof p?.advancedHours !== "number") continue;
    points.push({
      hoursAhead: p.advancedHours,
      lat,
      lon,
      windMs: num(p?.maximumWind?.sustained?.["m/s"]),
      gustMs: num(p?.maximumWind?.gust?.["m/s"]),
      isLow: p?.category?.en === "LOW",
    });
  }
  if (points.length === 0) return null;
  return { id, name: parts[0]?.name?.en ?? null, points };
}

/** Beaufort force; keep in step with `beaufort` in the app's storm.dart. */
export function beaufort(ms: number): number {
  const upper = [
    0.2, 1.5, 3.3, 5.4, 7.9, 10.7, 13.8, 17.1, 20.7, 24.4, 28.4, 32.6,
    36.9, 41.4, 46.1, 50.9, 56.0,
  ];
  const i = upper.findIndex((u) => ms <= u);
  return i === -1 ? 17 : i;
}

/** Vietnam's cyclone classes (Decision 18/2021/QĐ-TTg); see StormStrength. */
function stormClass(force: number, vi: boolean): string {
  if (force <= 7) return vi ? "Áp thấp nhiệt đới" : "Tropical depression";
  if (force <= 9) return vi ? "Bão" : "Tropical storm";
  if (force <= 11) return vi ? "Bão mạnh" : "Severe tropical storm";
  if (force <= 15) return vi ? "Bão rất mạnh" : "Typhoon";
  return vi ? "Siêu bão" : "Super typhoon";
}

function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  const rad = (d: number) => (d * Math.PI) / 180;
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) *
      Math.sin(rad(lon2 - lon1) / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(a));
}

/** Closer than this within [stormHorizonHours] is worth a push. */
export const stormRadiusKm = 500;
export const stormHorizonHours = 72;

/**
 * A push per storm forecast to pass within [stormRadiusKm] of the device in
 * the next [stormHorizonHours], still a cyclone (force 6+, not yet a low)
 * when it does. No quiet hours: a storm is a safety matter.
 */
export function stormAlertsFor(
  sub: Subscription,
  storms: Storm[],
  now: Date,
): Alert[] {
  if (!sub.types.includes("storm")) return [];
  const vi = sub.locale === "vi";
  const alerts: Alert[] = [];
  for (const storm of storms) {
    const key = `storm:${storm.id}`;
    const last = sub.last_sent[key];
    if (last !== undefined && now.getTime() - Date.parse(last) < cooldown.storm) {
      continue;
    }
    const near = storm.points
      .filter((p) => p.hoursAhead <= stormHorizonHours && !p.isLow)
      .filter((p) => p.windMs !== null && beaufort(p.windMs) >= 6)
      .map((p) => ({ p, km: distanceKm(p.lat, p.lon, sub.lat, sub.lon) }))
      .filter((n) => n.km <= stormRadiusKm)
      .sort((a, b) => a.km - b.km)[0];
    if (near === undefined) continue;
    const force = beaufort(near.p.windMs!);
    const what = [stormClass(force, vi), storm.name].filter(Boolean).join(" ");
    const km = Math.round(near.km / 10) * 10;
    const when = near.p.hoursAhead === 0
      ? (vi ? `đang cách bạn khoảng ${km} km` : `is about ${km} km from you`)
      : vi
      ? `dự kiến cách bạn khoảng ${km} km sau ${near.p.hoursAhead} giờ`
      : `is forecast to pass about ${km} km from you in ${near.p.hoursAhead} h`;
    const gust = near.p.gustMs === null ? null : beaufort(near.p.gustMs);
    const wind = vi
      ? `Gió cấp ${force}${gust === null ? "" : `, giật cấp ${gust}`}.`
      : `Force ${force} winds${gust === null ? "" : `, gusts force ${gust}`}.`;
    alerts.push({
      type: "storm",
      key,
      // Same name as the app's storm card.
      title: vi ? "Theo dõi bão" : "Storm watch",
      body: `${what} ${when}. ${wind}`,
    });
  }
  return alerts;
}
