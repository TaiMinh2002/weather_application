// Pure alert rules, kept apart from index.ts so they can be unit-tested
// (rules_test.ts) without network or secrets.

/** Same names as the app's `AlertType` enum. */
export type AlertType = "rain" | "uv" | "air" | "heat";

export interface Subscription {
  user_id: string;
  fcm_token: string;
  lat: number;
  lon: number;
  locale: string;
  fahrenheit: boolean;
  types: AlertType[];
  /** Alert type → ISO time it was last sent. */
  last_sent: Partial<Record<AlertType, string>>;
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
}

const hour = 3_600_000;

// Rain comes and goes several times a day; the others describe the day, so
// once is enough.
const cooldown: Record<AlertType, number> = {
  rain: 3 * hour,
  uv: 20 * hour,
  air: 20 * hour,
  heat: 20 * hour,
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
  if (c.isDay && c.uv >= 8 && due("uv")) {
    const uv = Math.round(c.uv);
    alerts.push({
      type: "uv",
      title: vi ? "UV rất cao" : "Very high UV",
      body: vi
        ? `Chỉ số UV đang là ${uv}. Hạn chế ra nắng và bôi kem chống nắng.`
        : `The UV index is ${uv}. Limit time in the sun and wear sunscreen.`,
    });
  }
  // Above 150 is "unhealthy" for everyone, not only sensitive groups.
  if (c.aqi !== null && c.aqi > 150 && due("air")) {
    alerts.push({
      type: "air",
      title: vi ? "Không khí xấu" : "Unhealthy air",
      body: vi
        ? `AQI đang là ${c.aqi}, có hại cho sức khỏe. Nên đeo khẩu trang khi ra ngoài.`
        : `The AQI is ${c.aqi}, unhealthy. Consider a mask outdoors.`,
    });
  }
  if (c.feelsLike >= 39 && due("heat")) {
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
