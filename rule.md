# Skycast – Quy tắc code

> Áp dụng cho mọi code trong dự án. Chi tiết kế hoạch xem [plan.md](plan.md).

## 1. Độ dài file (quan trọng nhất)

- **Giới hạn cứng: 600 dòng / file** (tính cả import và comment, không tính file sinh ra `*.g.dart`, `*.freezed.dart`).
- **Dưới 600 dòng thì KHÔNG tách file** nếu không có lý do thật sự. Một file 400 dòng dễ đọc hơn 5 file 80 dòng nhảy qua nhảy lại.
- Chỉ tách khi:
  - File sắp vượt 600 dòng, hoặc
  - Một phần code được **dùng lại ở chỗ khác** (khi đó chuyển sang `core/` hoặc `widgets/` của feature).
- Khi tách: tách theo **khối có nghĩa** (một widget lớn, một nhóm hàm), không tách máy móc mỗi class một file.
- Widget con chỉ dùng trong một màn hình → để **private (`_MyWidget`) cùng file** với màn hình đó.
- Không tạo file chỉ chứa 1 hằng số, 1 typedef, hoặc file "barrel" export lại cho có.

## 2. Cấu trúc & kiến trúc

- Feature-first: `lib/core/` + `lib/features/<feature>/{data,domain,presentation}` (xem plan.md mục 5).
- **Không có lớp usecase**: provider gọi thẳng repository.
- Thư mục chỉ tạo khi có file thật đặt vào, không dựng sẵn thư mục rỗng.
- Abstract class repository chỉ dùng ở `domain/` để mock khi test; không tạo interface cho thứ khác nếu chỉ có 1 implementation.

## 3. State management (Riverpod)

- Dùng `riverpod_annotation` + codegen (`@riverpod`).
- UI đọc state bằng `ref.watch(...).when(data, loading, error)`.
- Không gọi API trực tiếp trong widget.
- Không dùng `setState` cho dữ liệu nghiệp vụ; chỉ dùng cho state UI cục bộ (animation, text field...).

## 4. Network & lỗi

- Dio tạo tại một chỗ (`core/network/dio_client.dart`). **Không tự viết interceptor**, chỉ `LogInterceptor` ở debug.
- Datasource bắt `DioException` → ném exception của app (`NetworkException`, `ServerException`).
- Repository bắt exception → trả `Result<T>` chứa `Failure` (sealed class). Không để exception lọt lên UI.
- Không nuốt lỗi im lặng (`catch (_) {}` là cấm).

## 5. UI

- **Không hard-code màu, text style**: lấy từ `Theme` / `ThemeExtension`.
- **Không hard-code chuỗi hiển thị**: dùng `context.l10n` (file `.arb` Việt/Anh).
- Mọi màn có dữ liệu phải xử lý đủ 3 trạng thái: loading (skeleton), error (`AppErrorView` + nút thử lại), empty.
- Dùng `const` constructor khi có thể.

## 6. Đặt tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| File, thư mục | `snake_case` | `weather_repository.dart` |
| Class, enum | `PascalCase` | `WeatherRepository` |
| Biến, hàm | `camelCase` | `getForecast()` |
| Private | tiền tố `_` | `_HourlyItem` |
| Model API | hậu tố `Dto` | `WeatherDto` |

## 7. Chất lượng

- `flutter analyze` không còn warning trước khi commit.
- Code sinh ra: `dart run build_runner build --delete-conflicting-outputs`.
- Logic thuần (mapper, converter, repository) phải có unit test. Widget test cho widget dùng chung.
- Không để code chết, code comment-out, `print()` (dùng `debugPrint` nếu cần).
- Comment chỉ giải thích **tại sao**, không giải thích code làm gì.
- Không thêm package mới nếu vài dòng code tự viết được.

## 8. Git

- Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Tạo `feature/<tên>` từ `dev` → Pull Request vào `dev`. `dev` merge vào `main` khi ổn định.
- Commit nhỏ, thường xuyên.
