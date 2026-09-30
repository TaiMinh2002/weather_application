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
| Bản đồ chọn vị trí ✅ | `flutter_map` + OpenStreetMap | Trung bình | Tùy chọn |
| Widget màn hình chính ✅ | `home_widget` | Khó | Tùy chọn |

> Phần đồng bộ Supabase giúp dự án có "backend" đúng mục tiêu ban đầu.

### 1.3. Khác biệt với app mặc định (sau v1)

Định vị: app mặc định cho biết "trời thế nào", Skycast trả lời **"tôi nên làm gì, và lúc nào"**. Mỗi giai đoạn là một PR vào `dev`, phát hành được độc lập.

| GĐ | Tính năng | Nhánh | Công sức | Package mới |
|---|---|---|---|---|
| 1 | So sánh với hôm qua + mưa 2 giờ tới | `feature/nowcast` | 1,5–2 ngày | không |
| 2 | Radar mưa trên bản đồ | `feature/rain-radar` | 1,5–2 ngày | không |
| 3 | Thẻ hoạt động (chạy bộ, phơi đồ…) | `feature/activities` | 3–4 ngày | không |
| 4 | Cảnh báo đẩy (mưa sắp tới, UV, AQI, nắng nóng) | `feature/push-alerts` | 5–7 ngày | `firebase_core`, `firebase_messaging` |

Thứ tự làm: 1 → 3 → 2 (chỉ khi radar phủ tốt VN) → 4. **Đã làm: 1, 3, 4; bỏ 2** (xem dưới).

**GĐ 1 – So sánh hôm qua + mưa sắp tới**
- `/forecast` thêm `past_days=1` và `minutely_15=precipitation` (`forecast_minutely_15=8`). Mapper tách ngày hôm qua ra `Weather.yesterday` và bỏ giờ của hôm qua, nên `daily[0]` vẫn là hôm nay (`DailyCard`, `morningSlots`, `Routes.dayOf` không đổi).
- Hàm thuần có test: `compareToYesterday` (bỏ qua chênh < 1,5°) và `rainOutlook` (mưa bắt đầu/tạnh sau X phút, ngưỡng 0,2 mm/15 phút).
- UI: dòng "Nóng hơn hôm qua 3°" ở header; `NowcastCard` (8 cột mưa, `CustomPainter`) chỉ hiện khi 2 giờ tới có mưa. Ở VN dữ liệu 15 phút là nội suy từ mô hình, nên câu chữ dùng "khoảng".
- Không đưa "mưa sau X phút" lên widget màn hình chính: widget chỉ cập nhật khi mở Home, nên câu đó sẽ sai sau vài chục phút. Vì lý do tương tự, `NowcastCard` ẩn khi dữ liệu lấy từ cache offline.

**GĐ 2 – Radar mưa**
- RainViewer (`api.rainviewer.com/public/weather-maps.json`, miễn phí, không key) → `TileLayer` trên `flutter_map`. Feature `radar/`, route `/radar?lat=&lon=`, play/pause qua các frame.
- Kiểm tra trước: độ phủ radar ở VN và điều khoản gói miễn phí hiện tại. Phủ kém thì bỏ giai đoạn này.
- **Kết quả (2026-09-29): bỏ.** Độ phủ VN tốt (10 radar), nhưng từ 1/1/2026 gói miễn phí chỉ cho dùng cá nhân/giáo dục, zoom tối đa 7, không còn frame dự báo (chỉ ~2 giờ radar đã qua). Card nowcast (GĐ 1) đã trả lời "sắp mưa không".

**GĐ 3 – Thẻ hoạt động**
- Hourly thêm `apparent_temperature, precipitation, wind_speed_10m, uv_index, relative_humidity_2m`. Đo thực tế: response ~13 KB/vị trí (không phải ~40 KB như ước tính) → **giữ cache trong shared_preferences**, không thêm `path_provider`. Cache cũ thiếu các trường mới thì bị bỏ qua (chỉ xảy ra một lần, khi vừa cập nhật mà đang offline).
- `features/activities/domain/activity.dart`: `enum Activity` (xe máy, phơi đồ, chạy bộ, đạp xe, rửa xe, dã ngoại; bỏ câu cá vì khó chấm điểm có ý nghĩa), `scoreAt` (0–100, trừ điểm theo mưa/nóng/UV/gió/độ ẩm/AQI tùy hoạt động) và `bestWindow` (khối `Activity.hours` giờ liền nhau trong 5:00–21:00, xếp theo giờ tệ nhất trong khối). Mỗi luật có unit test.
- Không thêm trang onboarding / mục Cài đặt: mặc định chọn sẵn xe máy, phơi đồ, chạy bộ (`Activity.defaults`); người dùng sửa bằng nút trên chính card (bottom sheet `FilterChip`), lưu ở `settingsProvider.activities`. Chiều tối hết giờ trong ngày thì card hiện khung giờ ngày mai.
- Thông báo 7:00 thêm dòng "Chạy bộ: tốt nhất 5:00–6:00" cho hoạt động đầu tiên đã chọn (chỉ khi điểm ≥ 60; Android dùng `BigTextStyle` để không bị cắt).

**GĐ 4 – Cảnh báo đẩy**
- `pg_cron` 1 giờ/lần (lúc đầu 15 phút; giãn ra để bớt gọi API) → Edge Function `check-alerts` (gom vị trí theo ô ~0,1°, gọi Open-Meteo forecast + air-quality, giờ yên lặng 22:00–6:00 theo giờ địa phương) → FCM HTTP v1. Luật thuần trong `rules.ts` (có `rules_test.ts`): sắp mưa (khô bây giờ, ≥ 0,2 mm trong 60 phút tới, khớp với chu kỳ chạy; chống lặp 3 giờ), UV ≥ 8 ban ngày, AQI > 150, cảm giác nhiệt ≥ 39° (mỗi loại 1 lần/ngày). Ngưỡng cố định trên server, người dùng chỉ bật/tắt từng loại.
- Bảng `alert_subscriptions` (RLS theo user anonymous): token, lat/lon (làm tròn ~1 km), locale, °F, types, `last_sent`. App upsert mỗi lần có dự báo GPS mới, lỗi chỉ log (giống `cities_sync_ds.dart`); tắt công tắc thì xóa dòng; token chết (UNREGISTERED) thì server xóa.
- Key Firebase qua `--dart-define` (như Supabase), không dùng `google-services.json` / `GoogleService-Info.plist` / Gradle plugin → CI và máy clone mới vẫn build được; thiếu key thì ẩn công tắc.
- Android: app đang mở thì hiện lại bằng `flutter_local_notifications` (FCM không tự hiện); kênh `weather_alerts`. iOS: `aps-environment` + `UIBackgroundModes: remote-notification`; foreground dùng `setForegroundNotificationPresentationOptions`.
- Làm cả iOS và Android (đã có tài khoản Apple Developer). Hướng dẫn cài đặt: `supabase/functions/check-alerts/README.md`.

**Thẻ chia sẻ dạng ảnh (đã làm):** nút chia sẻ cạnh tên địa điểm trên Home → bottom sheet xem trước thẻ 4:5 (gradient theo thời tiết, nhiệt độ, cao/thấp, tối đa 2 điểm nổi bật: mưa sắp tới, giờ tốt nhất cho hoạt động đã chọn khi điểm ≥ 60, dòng ghi nguồn Open-Meteo) → chụp bằng `RepaintBoundary` (1080 px) → menu chia sẻ của máy qua `share_plus` (package duy nhất thêm vào; không cần `path_provider` vì `XFile.fromData`). Code: `features/share/presentation/share_card.dart`.

**Hồ sơ sức khỏe (đã làm):** Cài đặt → Sức khỏe, chọn nhiều: hen suyễn/bệnh hô hấp, có trẻ nhỏ, người cao tuổi. `Limits.of(health)` (trong `weather.dart`, ngưỡng khắt khe nhất thắng) đổi ngưỡng của gợi ý (khẩu trang AQI > 50 cho hô hấp; nóng từ 33° và UV từ 3 cho trẻ nhỏ/người già) và của chấm điểm hoạt động (khói bụi tính từ `limits.aqi`; ngưỡng nóng hạ 2°, ngưỡng lạnh giữ nguyên). Cảnh báo đẩy dùng `limitsFor` trong `rules.ts` (AQI > 100 thay vì 150; nóng 37° thay vì 39°; UV 6 thay vì 8 cho trẻ nhỏ), gửi lên qua cột `alert_subscriptions.health`. Bỏ phấn hoa: Open-Meteo chỉ có dữ liệu phấn hoa cho châu Âu (Hà Nội trả `null`).

**Theo dõi bão (đã làm, phần trong app):** nguồn là JMA / RSMC Tokyo (trung tâm WMO cho Tây Bắc Thái Bình Dương và Biển Đông), JSON công khai tại `jma.go.jp/bosai/typhoon/data/` (`targetTc.json`, rồi mỗi bão `specifications.json` + `forecast.json`), dùng lại được theo Public Data License của JMA (tương thích CC BY 4.0, phải ghi nguồn). NCHMF chỉ có bài viết HTML nên không dùng; GDACS (có API) để dự phòng nếu JMA đổi định dạng (endpoint JMA không có tài liệu, nên DTO đọc từng trường theo đường dẫn nullable, lỗi chỉ ẩn giá trị). Thẻ trên Home chỉ hiện khi bão đang/sẽ vào phạm vi 1500 km (`stormsNear`); màn `/storm/:id` có bản đồ đường đi, vòng xác suất 70%, bảng diễn biến. Cấp gió theo Beaufort, phân loại theo QĐ 18/2021/QĐ-TTg (áp thấp nhiệt đới đến siêu bão). Còn lại: cảnh báo đẩy khi bão tiến gần (server đọc JMA một lần mỗi lần chạy).

Để sau: cảnh báo đẩy khi có bão (cần nguồn NCHMF), Live Activity, Wear OS.

---

## 2. Màn hình (UI/UX)

**Native splash + 5 màn Flutter** (+1 nếu làm bản đồ).

| # | Màn hình | Route | Nội dung |
|---|---|---|---|
| 0 | **Splash (native)** | – | Không phải màn Flutter. Hiện trong lúc engine khởi động, xem mục bên dưới |
| 1 | **Onboarding** | `/onboarding` | Giải thích vì sao cần quyền vị trí *trước khi* hệ thống hỏi. Nút "Cho phép vị trí" / "Chọn thành phố". Chỉ hiện lần đầu |
| 2 | **Home** | `/` | `PageView`: trang 0 là vị trí GPS, sau đó các thành phố đã lưu. Mỗi trang: header (tên, nhiệt độ lớn, trạng thái, cao/thấp, cảm giác như), banner offline, 24 giờ, 7 ngày, grid thông số chi tiết, (AQI, gợi ý) |
| 3 | **Chi tiết ngày** | `/day/:index?lat=&lon=` | Chip chọn ngày, biểu đồ nhiệt độ theo giờ, % mưa, gió, UV, bình minh/hoàng hôn |
| 4 | **Thành phố** | `/cities` | Gộp tìm kiếm + quản lý (kiểu app Weather iOS). Ô tìm kiếm trống → danh sách đã lưu (kéo thả sắp xếp, vuốt xóa). Đang gõ → kết quả Geocoding (debounce) |
| 5 | **Cài đặt** | `/settings` | Đơn vị, theme, ngôn ngữ, giới thiệu app. Công tắc thông báo chỉ thêm khi làm tính năng thông báo |
| 6 | *(Nâng cao)* **Bản đồ** | `/map` | Chọn vị trí bất kỳ trên bản đồ để xem thời tiết |

> Không làm lịch sử tìm kiếm riêng: danh sách thành phố đã lưu đã đóng vai trò đó.

### Splash native

Làm bằng file native, không có route Flutter: Android `res/drawable/launch_background.xml` + `res/values(-night)/styles.xml` (+ `values-v31` cho Android 12+), iOS `LaunchScreen.storyboard`.

Thiết kế:
- Nền một màu, trùng màu nền của theme (có bản sáng và tối) để chuyển sang Flutter không bị nháy.
- Chỉ có logo ở giữa, **không có chữ**. Android 12+ cắt icon trong khung tròn: ảnh 288×288dp, nội dung nằm gọn trong vòng tròn 192dp.
- Không animation, không chờ cố ý. Splash tắt ngay khi Flutter vẽ frame đầu tiên. `redirect` của router quyết định vào Onboarding hay Home.

### Sơ đồ điều hướng

```
Splash (native) ──(chưa onboard)──> Onboarding ──> Home
       └──(đã onboard)──────────────────────────> Home
                                                    ├── Chi tiết ngày
                                                    ├── Thành phố (tìm kiếm + quản lý)
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
| Vị trí | **geolocator** | Lấy GPS, kiểm tra/xin quyền, mở Cài đặt (không cần `permission_handler`) |
| Tên địa điểm từ tọa độ | **geocoding** (dịch vụ có sẵn trên máy, free) hoặc Nominatim API | Hiện "Hà Nội" thay vì tọa độ |
| Lưu trữ local | **shared_preferences** (cài đặt + cache thời tiết dạng JSON) | Đã có sẵn, đủ cho vài địa điểm. Chuyển sang Hive/file khi số thành phố lưu tăng nhiều |
| Kiểm tra mạng | ~~connectivity_plus~~ không dùng | `NetworkException` từ Dio đã cho biết mất mạng; banner "Đang offline" hiện khi dữ liệu lấy từ cache |
| Biểu đồ | ~~fl_chart~~ `CustomPainter` | Design chỉ có 1 đường nhiệt độ + cột % mưa, không tương tác; tự vẽ ~150 dòng, khớp design, không thêm package |
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
  &current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_direction_10m,pressure_msl,uv_index,visibility
  &hourly=temperature_2m,weather_code,precipitation_probability,is_day
  &daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max
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
│   ├── network/                  # dio_client.dart (Dio provider + DioException → AppException)
│   ├── error/                    # errors.dart (AppException, Failure, Result, guard)
│   ├── router/                   # app_router.dart (route + Routes + redirect)
│   ├── theme/                    # app_theme.dart (ThemeData sáng/tối + ThemeExtension màu)
│   ├── storage/                  # prefs.dart
│   ├── utils/                    # weather_code_mapper.dart; sau: date_formatter, unit_converter
│   ├── extensions/               # context_ext.dart
│   └── widgets/                  # state_views.dart (AppLoading, AppErrorView, EmptyView)
├── features/
│   ├── weather/
│   │   ├── data/
│   │   │   ├── datasources/      # weather_remote_ds.dart, weather_local_ds.dart
│   │   │   ├── models/           # weather_dto.dart (freezed + json, có toEntity())
│   │   │   └── repositories/     # weather_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/         # weather.dart (Weather, CurrentWeather, hourly, daily)
│   │   │   └── repositories/     # weather_repository.dart (abstract)
│   │   └── presentation/
│   │       ├── providers/        # weather_provider.dart
│   │       ├── screens/          # home_screen.dart, day_detail_screen.dart
│   │       └── widgets/          # chỉ tạo khi widget được dùng lại ở nhiều màn (rule.md mục 1)
│   ├── location/                 # lấy GPS, xử lý quyền, reverse geocoding
│   ├── cities/                   # tìm kiếm + lưu/sắp xếp/xóa thành phố (một màn nên gộp một feature)
│   ├── settings/                 # cài đặt
│   └── onboarding/
└── l10n/                         # app_vi.arb, app_en.arb

test/                             # cấu trúc giống lib/
```

> Cây thư mục trên là đích đến. Thư mục chỉ được tạo khi có file thật đặt vào (rule.md mục 2).

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
   └──> LocalDataSource  (cache JSON trong shared_preferences)
```

**Logic repository:**
- Có mạng → gọi API → lưu cache → trả dữ liệu.
- Mất mạng → trả cache (kèm thời điểm cập nhật).
- Cả hai đều không có → trả `Failure`.

---

## 6. Base code

"Bộ khung" sẽ copy sang các dự án sau, cần đầu tư kỹ:

1. **Dio provider**: `baseUrl`, timeout. Không tự viết interceptor.
2. **Xử lý lỗi thống nhất**: `sealed class Failure` gồm `NetworkFailure`, `ServerFailure`, `CacheFailure`, `LocationFailure`, `UnknownFailure`.
3. **Result type**: repository trả `Result<T>` (`Ok` / `Err`) qua hàm `guard()`, thay vì ném exception lung tung.
4. **Theme**: `AppTheme.light` / `AppTheme.dark`, màu và text style tập trung một chỗ.
5. **Router**: route khai báo tập trung, `redirect` đưa người dùng mới vào onboarding.
6. **Widget dùng chung**: `AppErrorView(onRetry)`, `AppLoading`, `EmptyView`.
7. **Extension tiện ích**: `context.l10n`, `context.textTheme`, `context.colors`...

### 6.1. Quyết định về network: không dùng interceptor tự viết

Interceptor thường dùng cho 3 việc:

| Việc | App này có cần? | Cách xử lý |
|---|---|---|
| Gắn token vào header | Không (không có authen với Open-Meteo) | Bỏ |
| Log request/response | Có ích khi debug | Dùng `LogInterceptor` có sẵn của Dio, chỉ bật ở debug (hoặc bỏ) |
| Chuyển lỗi Dio → lỗi app | Có | `try/catch` ngay trong remote datasource |

Các dự án sau dùng Supabase/Firebase, SDK tự lo authen và token, không đi qua Dio. Khi nào thực sự cần (gọi API riêng có token) thì thêm interceptor lúc đó.

### 6.2. Dio provider (`core/network/dio_client.dart`)

```dart
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.forecastBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  if (kDebugMode) dio.interceptors.add(LogInterceptor(responseBody: true));
  return dio;
}

extension DioExceptionX on DioException {
  AppException toAppException() => switch (type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(),
    _ => ServerException(response?.statusCode),
  };
}
```

### 6.3. Chuyển lỗi trong datasource

```dart
Future<WeatherDto> getForecast(double lat, double lon) async {
  try {
    final res = await _dio.get<Map<String, dynamic>>('/forecast', queryParameters: {
      'latitude': lat,
      'longitude': lon,
      // current, hourly, daily, timezone, forecast_days...
    });
    return WeatherDto.fromJson(res.data!);
  } on DioException catch (e) {
    throw e.toAppException();
  }
}
```

### 6.4. Failure và Result (`core/error/errors.dart`)

`Failure` **không chứa câu thông báo**: `AppErrorView` chọn icon + câu theo loại lỗi từ l10n (rule.md cấm hard-code chuỗi).

```dart
sealed class Failure { const Failure(); }

class NetworkFailure extends Failure { const NetworkFailure(); }
class ServerFailure extends Failure { const ServerFailure(); }
class CacheFailure extends Failure { const CacheFailure(); }
class LocationFailure extends Failure {
  const LocationFailure(this.reason);
  final LocationError reason; // serviceDisabled, denied, deniedForever, unavailable
}
class UnknownFailure extends Failure { const UnknownFailure(this.error); final Object error; }

sealed class Result<T> {
  T getOrThrow(); // Ok → data, Err → throw failure (để Riverpod đưa vào AsyncValue.error)
}
final class Ok<T> extends Result<T> { ... }
final class Err<T> extends Result<T> { ... }

/// Repository bọc thân hàm: bắt mọi exception → Err(toFailure(e)).
Future<Result<T>> guard<T>(Future<T> Function() body);
```

Thêm loại `Failure` / `LocationError` mới thì cập nhật cả `toFailure` và `AppErrorView`.

### 6.5. Provider (Riverpod codegen)

```dart
// Repository: provider đặt cuối file impl.
@Riverpod(keepAlive: true)
WeatherRepository weatherRepository(Ref ref) =>
    WeatherRepositoryImpl(ref.watch(weatherRemoteDataSourceProvider));

// Presentation: repo trả Result, nên gọi getOrThrow().
@riverpod
Future<Weather> weather(Ref ref, double lat, double lon) async {
  final result = await ref.watch(weatherRepositoryProvider).getWeather(lat: lat, lon: lon);
  return result.getOrThrow();
}
```

Ở UI:

```dart
ref.watch(weatherProvider(lat, lon)).when(
  data: (w) => _CurrentView(weather: w),
  loading: () => const AppLoading(),
  error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(weatherProvider(lat, lon))),
);
```

### 6.6. Router với redirect onboarding

Redirect là hàm thuần để unit test không cần widget tree. `SharedPreferences` được load trong `main()` rồi inject qua `sharedPreferencesProvider.overrideWithValue(prefs)`.

```dart
String? onboardingRedirect(SharedPreferences prefs, String location) {
  final done = prefs.getBool(PrefKeys.onboarded) ?? false;
  if (!done && location != Routes.onboarding) return Routes.onboarding;
  if (done && location == Routes.onboarding) return Routes.home;
  return null;
}

// routes: '/', '/onboarding'; thêm dần '/cities', '/settings', '/day/:index?lat=&lon='
```

---

## 7. Lộ trình 2 tuần

| Ngày | Việc cần làm |
|---|---|
| 1 ✅ | Tạo project, cài package, cấu hình lint, dựng cấu trúc thư mục, theme, router |
| 2 ✅ | DioClient, Failure, Result type, gọi thử API Open-Meteo |
| 3 ✅ | Model (freezed), repository, provider thời tiết |
| 4 ✅ | Lấy GPS, xử lý quyền, reverse geocoding |
| 5–6 ✅ | Màn Home: thời tiết hiện tại, theo giờ, 7 ngày, thông số chi tiết |
| 7 ✅ | Cache offline, pull-to-refresh, banner offline |
| 8 ✅ | Màn Thành phố: tìm kiếm (debounce), lưu thành phố |
| 9 ✅ | Màn Thành phố: sắp xếp, xóa; PageView vuốt giữa các thành phố |
| 10 ✅ | Màn cài đặt: đơn vị, theme, ngôn ngữ |
| 11 ✅ | Onboarding, splash native, màn chi tiết ngày + biểu đồ |
| 12 ✅ | Nền động, hoàn thiện UI *(gradient chuyển mượt khi tải xong / đổi thời tiết, nội dung fade từ skeleton; tắt khi máy bật giảm chuyển động)* |
| 13 ✅ | Viết test (mapper, repository, provider), GitHub Actions |
| 14 ✅ | README, chụp ảnh *(tự dựng bằng `tool/screenshots_test.dart`)*, APK lên Releases khi push tag `v*` |

✅ = đã xong (merge vào `dev`).

**Sau 2 tuần** (vài ngày thêm): AQI → gợi ý hoạt động → Supabase sync thành phố.

---

## 8. Test, CI/CD và Git

### 8.1. Test nên viết

- **Unit test**: `weather_code_mapper`, `unit_converter` (°C ↔ °F, km/h ↔ m/s).
- **Unit test repository** (mock remote/local bằng mocktail): có mạng, mất mạng có cache, mất mạng không cache, lỗi server.
- **Widget test**: `AppErrorView` (bấm "Thử lại" gọi callback), một widget ở Home.

### 8.2. GitHub Actions

File `.github/workflows/ci.yml`, chạy khi push lên `dev` / `main` và khi mở Pull Request vào `dev` / `main`:

1. `flutter pub get`
2. `flutter gen-l10n` + `dart run build_runner build --delete-conflicting-outputs` (file sinh ra bị gitignore)
3. `flutter analyze`
4. `flutter test`
5. `flutter build apk --release` (upload artifact)

Gắn badge "build passing" lên README.

### 8.3. Quy ước Git

- **Conventional Commits**: `feat: add hourly forecast`, `fix: handle location denied`, `refactor: extract weather card`, `test: add mapper tests`, `docs: update readme`.
- **Branch**: tạo `feature/<tên>` từ `dev` → Pull Request vào **`dev`**, dù làm một mình. Không PR thẳng vào `main`.
- `dev` merge vào `main` khi ổn định (ví dụ hết một mốc lộ trình hoặc trước khi build APK lên Releases).
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

### Tiến độ (cập nhật 2026-09-27)

Đã merge vào `dev`: base code, dữ liệu thời tiết, vị trí, design tokens, Home, cache offline, Thành phố, Cài đặt, Chi tiết ngày, Onboarding + splash native (PR #1–#11). Tương ứng ngày 1–11.

**Tiếp theo:** merge `dev` → `main`, tag `v1.0.0`. Sau MVP: AQI → gợi ý hoạt động → Supabase sync.

**Thay đổi so với kế hoạch ban đầu:**
- Không dùng `permission_handler`: `geolocator` đã có sẵn kiểm tra quyền, xin quyền và mở Cài đặt.
- `Failure` không chứa câu thông báo; `AppErrorView` lấy câu theo loại lỗi từ l10n (rule.md cấm hard-code chuỗi). `LocationFailure` mang lý do: GPS tắt, bị từ chối, bị từ chối vĩnh viễn, không lấy được vị trí.
- Exception, `Failure`, `Result` nằm chung `core/error/errors.dart` thay vì tách 2 file (theo rule 600 dòng).
- Nhánh: `feature/*` tạo từ `dev`, Pull Request vào `dev` (không vào thẳng `main`).
- Cache offline dùng `shared_preferences` (JSON, mỗi địa điểm ~30 KB) thay vì `hive_ce`: đủ dùng và không thêm package (rule.md mục 7). Chỉ fallback cache khi mất mạng; lỗi server vẫn báo lỗi.
- Không dùng `connectivity_plus`, `fl_chart`, `hive_ce`, `flutter_native_splash`: `NetworkException`, `CustomPainter`, `shared_preferences` và file native tự viết đã đủ (rule.md mục 7).
- Tìm kiếm và quản lý thành phố gộp một màn `/cities` (feature `cities/`).


### Nền tảng
- [x] Tạo project, cấu hình lint
- [x] Cấu trúc thư mục feature-first
- [x] Theme sáng/tối
- [x] go_router + redirect onboarding
- [x] DioClient + try/catch chuyển lỗi
- [x] Failure + Result type
- [x] Widget dùng chung (error, loading, empty)
- [x] Đa ngôn ngữ Việt/Anh

### Tính năng MVP
- [x] Thời tiết hiện tại theo GPS
- [x] Dự báo theo giờ
- [x] Dự báo 7 ngày
- [x] Thông số chi tiết
- [x] Tìm kiếm thành phố
- [x] Lưu / sắp xếp / xóa thành phố
- [x] Cài đặt đơn vị, theme, ngôn ngữ
- [x] Offline cache
- [x] Pull-to-refresh
- [x] Xử lý quyền vị trí & lỗi

### Nâng cao
- [x] AQI *(card cuối Home: US AQI + mức, thang màu EPA, PM2.5/PM10; không cache, offline thì ẩn)*
- [x] Gợi ý hoạt động *(`tipsFor` trong `weather.dart`: 7 quy tắc + "thời tiết đẹp", tối đa 3 gợi ý, card dưới dự báo 24 giờ)*
- [x] Nền động *(bản nhẹ: `AnimatedContainer` + `AnimatedSwitcher`; Lottie/hạt mưa để sau nếu cần)*
- [x] Đồng bộ Supabase *(anonymous ngầm, không màn login; sao lưu danh sách thành phố, khôi phục khi máy trống; key qua `--dart-define-from-file`)*
- [x] Biểu đồ nhiệt độ *(màn Chi tiết ngày)*
- [x] Widget màn hình chính *(2×2: Android native xong; iOS có target WidgetKit `SkycastWidget`, iOS 17+)*
- [x] Thông báo mỗi sáng *(bật trong Cài đặt; mỗi lần có dự báo GPS mới thì lên lịch sẵn 7 thông báo 7:00, mỗi cái mang dự báo của đúng ngày đó → không cần `workmanager`/chạy nền)*

### Khác biệt (mục 1.3)
- [x] GĐ 1: So sánh hôm qua + mưa 2 giờ tới *(`highVsYesterday`, `rainOutlook` trong `weather.dart`; `NowcastCard` trong `insight_cards.dart`)*
- [x] Thẻ chia sẻ dạng ảnh *(`features/share/`)*
- [x] Theo dõi bão *(`features/storms/`, dữ liệu JMA)*
- [x] Hồ sơ sức khỏe *(`HealthProfile` + `Limits` trong `weather.dart`, `limitsFor` trong `rules.ts`)*
- [ ] ~~GĐ 2: Radar mưa~~ *(bỏ: điều khoản RainViewer, xem mục 1.3)*
- [x] GĐ 3: Thẻ hoạt động *(`features/activities/`: `scoreAt`, `bestWindow`, `ActivitiesCard`)*
- [x] GĐ 4: Cảnh báo đẩy *(`features/alerts/`, `supabase/functions/check-alerts/`)*

### Chất lượng & trình bày
- [x] Unit test + widget test *(45 test)*
- [x] GitHub Actions
- [x] README đầy đủ *(ảnh chụp sáng/tối; GIF demo để sau)*
- [x] APK trên GitHub Releases *(push tag `v*`)*
