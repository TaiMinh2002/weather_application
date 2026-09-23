# Skycast – Kế hoạch phát triển App thời tiết (Flutter)

> Dự án portfolio đầu tiên. Mục tiêu: dựng "bộ khung" chuẩn (cấu trúc thư mục, state management, gọi API, xử lý lỗi, theme, router) để tái sử dụng cho các dự án sau.
>
> Tiêu chí: Flutter, backend Supabase (phần nâng cao), API bên thứ 3 miễn phí, **0 đồng chi phí phát triển**.

---

## Mục lục

1. [Tính năng](#1-tính-năng)
2. [Màn hình (UI/UX)](#2-màn-hình-uiux)
3. [Công nghệ sử dụng](#3-công-nghệ-sử-dụng)
4. [API Open-Meteo](#4-api-open-meteo)
5. [Kiến trúc và cấu trúc thư mục](#5-kiến-trúc-và-cấu-trúc-thư-mục)
6. [Base code](#6-base-code)
7. [Lộ trình 2 tuần](#7-lộ-trình-2-tuần)
8. [Test, CI/CD và Git](#8-test-cicd-và-git)
9. [README trên GitHub](#9-readme-trên-github)
10. [Checklist hoàn thành](#10-checklist-hoàn-thành)

---

## 1. Tính năng

### 1.1. MVP (bắt buộc, làm trong 2 tuần)

| # | Tính năng | Ghi chú kỹ thuật |
|---|---|---|
| 1 | Thời tiết hiện tại theo GPS | Nhiệt độ, cảm giác như, trạng thái (nắng/mưa...), icon theo `weather_code` |
| 2 | Dự báo theo giờ (24h tới) | List ngang, có % khả năng mưa |
| 3 | Dự báo 7 ngày | Min/max, icon, bấm vào xem chi tiết ngày |
| 4 | Thông số chi tiết | Độ ẩm, gió, UV, áp suất, tầm nhìn, bình minh/hoàng hôn |
| 5 | Tìm kiếm thành phố | Open-Meteo Geocoding API, có debounce khi gõ |
| 6 | Lưu nhiều thành phố | Vuốt ngang giữa các thành phố, sắp xếp, xóa |
| 7 | Cài đặt | °C/°F, km/h hoặc m/s, sáng/tối/theo hệ thống, Việt/Anh |
| 8 | Offline cache | Mất mạng vẫn hiện dữ liệu gần nhất, kèm "cập nhật lúc..." |
| 9 | Pull-to-refresh | Kéo xuống để tải lại |
| 10 | Xử lý trạng thái | Loading (skeleton), lỗi mạng, từ chối quyền vị trí, tắt GPS |

### 1.2. Nâng cao (chọn thêm sau MVP)

| Tính năng | Công nghệ | Độ khó | Ưu tiên |
|---|---|---|---|
| Chỉ số chất lượng không khí (AQI, PM2.5) | Open-Meteo Air Quality API | Dễ | ⭐ Nên làm |
| Gợi ý hoạt động theo thời tiết | Rule-based tự viết (mưa → mang áo mưa, UV cao → kem chống nắng) | Dễ | ⭐ Nên làm |
| Nền động theo thời tiết và ngày/đêm | Gradient + `lottie` / `flutter_animate` | Trung bình | ⭐ Nên làm |
| Đồng bộ thành phố đã lưu lên cloud | Supabase (anonymous auth hoặc Google login) | Trung bình | ⭐ Nên làm |
| Biểu đồ nhiệt độ theo giờ | `fl_chart` | Trung bình | Tùy chọn |
| Thông báo dự báo mỗi sáng | `flutter_local_notifications` + `workmanager` | Trung bình | Tùy chọn |
| Bản đồ chọn vị trí | `flutter_map` + OpenStreetMap | Trung bình | Tùy chọn |
| Widget màn hình chính | `home_widget` | Khó | Tùy chọn |

> Phần đồng bộ Supabase giúp dự án có "backend" đúng mục tiêu ban đầu.

---

## 2. Màn hình (UI/UX)

Tổng cộng **6 màn hình chính** (+1 nếu làm bản đồ).

| # | Màn hình | Nội dung |
|---|---|---|
| 1 | **Splash / Onboarding** | Logo, giải thích vì sao cần quyền vị trí *trước khi* hệ thống hỏi. Chỉ hiện lần đầu |
| 2 | **Home** | `PageView` các thành phố. Mỗi trang: header (tên, nhiệt độ lớn, trạng thái), dự báo theo giờ, 7 ngày, grid thông số chi tiết, AQI, gợi ý |
| 3 | **Chi tiết ngày** | Biểu đồ nhiệt độ theo giờ, mưa, gió, UV của ngày được chọn |
| 4 | **Tìm kiếm** | Ô tìm kiếm, kết quả gợi ý, lịch sử tìm kiếm gần đây |
| 5 | **Quản lý thành phố** | Danh sách đã lưu, kéo thả sắp xếp, vuốt để xóa |
| 6 | **Cài đặt** | Đơn vị, theme, ngôn ngữ, bật/tắt thông báo, giới thiệu app |
| 7 | *(Nâng cao)* **Bản đồ** | Chọn vị trí bất kỳ trên bản đồ để xem thời tiết |

### Sơ đồ điều hướng

```
Splash ──(lần đầu)──> Onboarding ──> Home
   └──(đã onboard)──────────────────> Home
                                       ├── Chi tiết ngày
                                       ├── Tìm kiếm
                                       ├── Quản lý thành phố
                                       ├── Cài đặt
                                       └── Bản đồ (nâng cao)
```

### Nguyên tắc UX

- **Skeleton loading** thay vì vòng xoay (package `skeletonizer`).
- **Empty state / error state** có hình minh họa + nút "Thử lại", không để màn hình trắng.
- **Dark mode từ đầu**: màu định nghĩa trong `ThemeData` + `ThemeExtension`, không hard-code màu trong widget.
- **Responsive**: kiểm tra trên màn nhỏ (iPhone SE), màn lớn và tablet.
- Thiết kế trước trên **Figma** (miễn phí), đưa ảnh/link vào README.

---

## 3. Công nghệ sử dụng

| Hạng mục | Lựa chọn | Lý do |
|---|---|---|
| State management | **Riverpod** (`flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`) | Gọn hơn Bloc, dễ test, `AsyncValue` xử lý loading/error/data tiện |
| Router | **go_router** | Do team Flutter duy trì, hỗ trợ deep link, `redirect` cho onboarding |
| Gọi API | **dio** | Timeout, query params gọn. **Không tự viết interceptor** (xem mục 6.1) |
| Model | **freezed** + **json_serializable** | Model bất biến, `copyWith`, sealed class cho lỗi |
| Vị trí | **geolocator** + **permission_handler** | Lấy GPS, xử lý quyền |
| Tên địa điểm từ tọa độ | **geocoding** (dịch vụ có sẵn trên máy, free) hoặc Nominatim API | Hiện "Hà Nội" thay vì tọa độ |
| Lưu trữ local | **shared_preferences** (cài đặt) + **hive_ce** (cache thời tiết, thành phố) | Nhẹ, nhanh, không cần SQL |
| Kiểm tra mạng | **connectivity_plus** | Hiện banner "Đang offline" |
| Biểu đồ | **fl_chart** | Miễn phí, tùy biến tốt |
| Animation | **flutter_animate**, **lottie** | Nền động, icon động (file Lottie free trên LottieFiles) |
| Skeleton | **skeletonizer** | Loading đẹp, ít code |
| Đa ngôn ngữ | `flutter_localizations` + `intl` (file `.arb`) | Cách chính thức của Flutter |
| Backend (nâng cao) | **supabase_flutter** | Auth + lưu thành phố yêu thích |
| Lint | **very_good_analysis** hoặc `flutter_lints` | Code sạch, nhất quán |
| Test | `flutter_test` + **mocktail** | Mock repository dễ |
| Codegen | **build_runner** | Chạy freezed, json_serializable, riverpod_generator |
| CI/CD | **GitHub Actions** | Free cho repo public |

> Phiên bản package thay đổi thường xuyên, kiểm tra bản mới nhất trên [pub.dev](https://pub.dev) khi cài.

### Lưu ý chi phí

- **Không dùng Google Maps** (bắt buộc gắn thẻ thanh toán). Dùng OpenStreetMap qua `flutter_map`.
- **Supabase free** tạm dừng project nếu không hoạt động khoảng 1 tuần, vào dashboard bấm resume là được.

---

## 4. API Open-Meteo

Miễn phí, **không cần API key**, giới hạn khoảng 10.000 request/ngày cho mục đích phi thương mại.

### 4.1. Dự báo thời tiết

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude=21.03&longitude=105.85
  &current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,pressure_msl
  &hourly=temperature_2m,weather_code,precipitation_probability,visibility
  &daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max
  &timezone=auto
  &forecast_days=7
```

### 4.2. Tìm kiếm thành phố

```
GET https://geocoding-api.open-meteo.com/v1/search?name=Hanoi&count=10&language=vi
```

### 4.3. Chất lượng không khí (nâng cao)

```
GET https://air-quality-api.open-meteo.com/v1/air-quality
  ?latitude=21.03&longitude=105.85
  &current=us_aqi,pm2_5,pm10
```

### 4.4. Mã thời tiết WMO

Open-Meteo trả về `weather_code` theo chuẩn WMO. Cần viết `weather_code_mapper.dart` map code → mô tả + icon + màu nền. Đây là chỗ tốt để viết unit test.

| Code | Ý nghĩa |
|---|---|
| 0 | Trời quang |
| 1, 2, 3 | Ít mây, có mây, nhiều mây |
| 45, 48 | Sương mù |
| 51, 53, 55 | Mưa phùn |
| 61, 63, 65 | Mưa nhẹ, vừa, to |
| 80, 81, 82 | Mưa rào |
| 95, 96, 99 | Dông (có thể kèm mưa đá) |

---

## 5. Kiến trúc và cấu trúc thư mục

**Clean Architecture theo feature** (feature-first), 3 lớp `data` / `domain` / `presentation`. Bỏ lớp `usecases` để tránh rườm rà: provider gọi thẳng repository.

```
lib/
├── main.dart
├── app.dart                      # MaterialApp.router, theme, locale
├── core/
│   ├── constants/                # api_constants.dart, app_constants.dart
│   ├── network/                  # dio_client.dart
│   ├── error/                    # failure.dart, exceptions.dart
│   ├── router/                   # app_router.dart, route_names.dart
│   ├── theme/                    # app_theme.dart, app_colors.dart, text_styles.dart
│   ├── storage/                  # hive_service.dart, prefs_service.dart
│   ├── utils/                    # weather_code_mapper.dart, date_formatter.dart, unit_converter.dart
│   ├── extensions/               # context_ext.dart, datetime_ext.dart
│   └── widgets/                  # app_error_view.dart, app_loading.dart, empty_view.dart
├── features/
│   ├── weather/
│   │   ├── data/
│   │   │   ├── datasources/      # weather_remote_ds.dart, weather_local_ds.dart
│   │   │   ├── models/           # weather_response_dto.dart (freezed + json)
│   │   │   └── repositories/     # weather_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/         # weather.dart, hourly.dart, daily.dart
│   │   │   └── repositories/     # weather_repository.dart (abstract)
│   │   └── presentation/
│   │       ├── providers/        # weather_provider.dart
│   │       ├── screens/          # home_screen.dart, day_detail_screen.dart
│   │       └── widgets/          # current_weather_card.dart, hourly_list.dart, daily_list.dart...
│   ├── location/                 # lấy GPS, xử lý quyền
│   ├── city_search/              # tìm kiếm thành phố
│   ├── saved_cities/             # quản lý thành phố
│   ├── settings/                 # cài đặt
│   └── onboarding/
└── l10n/                         # app_vi.arb, app_en.arb

test/                             # cấu trúc giống lib/
```

### Luồng dữ liệu

```
UI (Screen/Widget)
   │  ref.watch(...)
   ▼
Provider (Riverpod)
   │
   ▼
Repository (quyết định nguồn dữ liệu)
   ├──> RemoteDataSource (Dio → Open-Meteo)
   └──> LocalDataSource  (Hive cache)
```

**Logic repository:**
- Có mạng → gọi API → lưu cache → trả dữ liệu.
- Mất mạng → trả cache (kèm thời điểm cập nhật).
- Cả hai đều không có → trả `Failure`.

---

## 6. Base code

"Bộ khung" sẽ copy sang các dự án sau, cần đầu tư kỹ:

1. **DioClient**: `baseUrl`, timeout. Không tự viết interceptor.
2. **Xử lý lỗi thống nhất**: `sealed class Failure` gồm `NetworkFailure`, `ServerFailure`, `CacheFailure`, `LocationFailure`.
3. **Result type**: repository trả `Result<T>` (thành công / thất bại) thay vì ném exception lung tung.
4. **Theme**: `AppTheme.light` / `AppTheme.dark`, màu và text style tập trung một chỗ.
5. **Router**: route khai báo tập trung, `redirect` đưa người dùng mới vào onboarding.
6. **Widget dùng chung**: `AppErrorView(onRetry)`, `AppLoading`, `EmptyView`.
7. **Extension tiện ích**: `context.theme`, `context.l10n`, `DateTime.toHourString()`...

### 6.1. Quyết định về network: không dùng interceptor tự viết

Interceptor thường dùng cho 3 việc:

| Việc | App này có cần? | Cách xử lý |
|---|---|---|
| Gắn token vào header | Không (không có authen với Open-Meteo) | Bỏ |
| Log request/response | Có ích khi debug | Dùng `LogInterceptor` có sẵn của Dio, chỉ bật ở debug (hoặc bỏ) |
| Chuyển lỗi Dio → lỗi app | Có | `try/catch` ngay trong remote datasource |

Các dự án sau dùng Supabase/Firebase, SDK tự lo authen và token, không đi qua Dio. Khi nào thực sự cần (gọi API riêng có token) thì thêm interceptor lúc đó.

### 6.2. DioClient

```dart
Dio createDio() {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.forecastBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  if (kDebugMode) dio.interceptors.add(LogInterceptor(responseBody: true));
  return dio;
}
```

### 6.3. Chuyển lỗi trong datasource

```dart
Future<WeatherDto> getForecast(double lat, double lon) async {
  try {
    final res = await _dio.get('/forecast', queryParameters: {
      'latitude': lat,
      'longitude': lon,
      // current, hourly, daily, timezone, forecast_days...
    });
    return WeatherDto.fromJson(res.data);
  } on DioException catch (e) {
    throw e.type == DioExceptionType.connectionError
        ? NetworkException()
        : ServerException(e.response?.statusCode);
  }
}
```

### 6.4. Failure

```dart
sealed class Failure {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure { const NetworkFailure() : super('Không có kết nối mạng'); }
class ServerFailure extends Failure { const ServerFailure() : super('Máy chủ đang gặp sự cố'); }
class CacheFailure extends Failure { const CacheFailure() : super('Không có dữ liệu lưu sẵn'); }
class LocationFailure extends Failure { const LocationFailure(super.message); }
```

### 6.5. Provider (Riverpod codegen)

```dart
@riverpod
Future<Weather> weather(Ref ref, double lat, double lon) {
  final repo = ref.watch(weatherRepositoryProvider);
  return repo.getWeather(lat: lat, lon: lon);
}
```

Ở UI:

```dart
ref.watch(weatherProvider(lat, lon)).when(
  data: (w) => CurrentWeatherCard(weather: w),
  loading: () => const AppLoading(),
  error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(weatherProvider(lat, lon))),
);
```

### 6.6. Router với redirect onboarding

```dart
final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final done = prefs.getBool('onboarded') ?? false;
    return (!done && state.matchedLocation != '/onboarding') ? '/onboarding' : null;
  },
  routes: [ /* '/', '/onboarding', '/search', '/cities', '/settings', '/day/:index' */ ],
);
```

---

## 7. Lộ trình 2 tuần

| Ngày | Việc cần làm |
|---|---|
| 1 | Tạo project, cài package, cấu hình lint, dựng cấu trúc thư mục, theme, router |
| 2 | DioClient, Failure, Result type, gọi thử API Open-Meteo |
| 3 | Model (freezed), repository, provider thời tiết |
| 4 | Lấy GPS, xử lý quyền, reverse geocoding |
| 5–6 | Màn Home: thời tiết hiện tại, theo giờ, 7 ngày, thông số chi tiết |
| 7 | Cache offline bằng Hive, pull-to-refresh, banner offline |
| 8 | Màn tìm kiếm thành phố (debounce), lưu thành phố |
| 9 | Màn quản lý thành phố, PageView vuốt giữa các thành phố |
| 10 | Màn cài đặt: đơn vị, theme, ngôn ngữ |
| 11 | Onboarding, màn chi tiết ngày + biểu đồ |
| 12 | Nền động, skeleton loading, hoàn thiện UI |
| 13 | Viết test (mapper, repository, provider), GitHub Actions |
| 14 | README, chụp ảnh/quay GIF, build APK đưa lên Releases |

**Sau 2 tuần** (vài ngày thêm): AQI → gợi ý hoạt động → Supabase sync thành phố.

---

## 8. Test, CI/CD và Git

### 8.1. Test nên viết

- **Unit test**: `weather_code_mapper`, `unit_converter` (°C ↔ °F, km/h ↔ m/s).
- **Unit test repository** (mock remote/local bằng mocktail): có mạng, mất mạng có cache, mất mạng không cache, lỗi server.
- **Widget test**: `AppErrorView` (bấm "Thử lại" gọi callback), một widget ở Home.

### 8.2. GitHub Actions

File `.github/workflows/ci.yml`, chạy mỗi khi push / mở Pull Request:

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs`
3. `flutter analyze`
4. `flutter test`
5. `flutter build apk --release` (upload artifact)

Gắn badge "build passing" lên README.

### 8.3. Quy ước Git

- **Conventional Commits**: `feat: add hourly forecast`, `fix: handle location denied`, `refactor: extract weather card`, `test: add mapper tests`, `docs: update readme`.
- **Branch**: làm trên `feature/<tên>` → tạo Pull Request vào `main`, dù làm một mình.
- Commit đều đặn, không dồn một commit lớn cuối dự án.
- **Không commit** file sinh ra nếu không cần, cấu hình `.gitignore` đúng.

---

## 9. README trên GitHub

README nên có đủ các mục:

1. Tên app + mô tả một câu + badge (build, Flutter version, license)
2. GIF demo
3. Ảnh chụp các màn hình (cả sáng và tối)
4. Danh sách tính năng
5. Công nghệ sử dụng
6. Sơ đồ kiến trúc + luồng dữ liệu
7. Cấu trúc thư mục
8. Hướng dẫn chạy project (`flutter pub get`, `build_runner`, `flutter run`)
9. Link tải APK (GitHub Releases)
10. Hướng phát triển tiếp
11. Credits: Open-Meteo, LottieFiles, OpenStreetMap (nếu dùng)

---

## 10. Checklist hoàn thành

### Nền tảng
- [ ] Tạo project, cấu hình lint
- [ ] Cấu trúc thư mục feature-first
- [ ] Theme sáng/tối
- [ ] go_router + redirect onboarding
- [ ] DioClient + try/catch chuyển lỗi
- [ ] Failure + Result type
- [ ] Widget dùng chung (error, loading, empty)
- [ ] Đa ngôn ngữ Việt/Anh

### Tính năng MVP
- [ ] Thời tiết hiện tại theo GPS
- [ ] Dự báo theo giờ
- [ ] Dự báo 7 ngày
- [ ] Thông số chi tiết
- [ ] Tìm kiếm thành phố
- [ ] Lưu / sắp xếp / xóa thành phố
- [ ] Cài đặt đơn vị, theme, ngôn ngữ
- [ ] Offline cache
- [ ] Pull-to-refresh
- [ ] Xử lý quyền vị trí & lỗi

### Nâng cao
- [ ] AQI
- [ ] Gợi ý hoạt động
- [ ] Nền động
- [ ] Đồng bộ Supabase
- [ ] Biểu đồ nhiệt độ
- [ ] Thông báo mỗi sáng

### Chất lượng & trình bày
- [ ] Unit test + widget test
- [ ] GitHub Actions
- [ ] README đầy đủ
- [ ] APK trên GitHub Releases
