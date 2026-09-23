# Skycast 🌤️

Ứng dụng thời tiết viết bằng Flutter, dùng API miễn phí [Open-Meteo](https://open-meteo.com) (không cần API key).

> 🚧 Đang phát triển. Kế hoạch chi tiết: [plan.md](plan.md) · Quy tắc code: [rule.md](rule.md)

## Tính năng (MVP)

- Thời tiết hiện tại theo GPS
- Dự báo 24 giờ và 7 ngày
- Thông số chi tiết: độ ẩm, gió, UV, áp suất, tầm nhìn, bình minh/hoàng hôn
- Tìm kiếm và lưu nhiều thành phố
- Cài đặt: °C/°F, đơn vị gió, sáng/tối, Việt/Anh
- Offline cache, pull-to-refresh

**Nâng cao (dự kiến):** AQI, gợi ý hoạt động, nền động, đồng bộ Supabase.

## Công nghệ

| Hạng mục | Package |
|---|---|
| State management | Riverpod (codegen) |
| Router | go_router |
| Network | dio |
| Model | freezed + json_serializable |
| Vị trí | geolocator + permission_handler |
| Lưu trữ | shared_preferences + hive_ce |
| Test | flutter_test + mocktail |

## Kiến trúc

Clean Architecture theo feature (`data` / `domain` / `presentation`), không có lớp usecase.

```
UI ──ref.watch──> Provider ──> Repository ──┬──> RemoteDataSource (Dio → Open-Meteo)
                                            └──> LocalDataSource  (Hive cache)
```

```
lib/
├── core/        # network, error, router, theme, storage, utils, widgets dùng chung
├── features/    # weather, location, city_search, saved_cities, settings, onboarding
└── l10n/        # app_vi.arb, app_en.arb
```

## Chạy project

```bash
flutter pub get
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

```bash
flutter run
```

## Credits

- Dữ liệu thời tiết: [Open-Meteo](https://open-meteo.com)
