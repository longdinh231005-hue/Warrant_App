# Soopi — Ứng dụng bảo hành điện tử

Ứng dụng Flutter dành cho khách hàng của hệ thống Soopi: quản lý thiết bị, gửi yêu cầu bảo hành, theo dõi sửa chữa và phản hồi báo giá. Giao diện sử dụng tiếng Việt và bộ nhận diện Soopi.

Tên package Dart hiện tại là `warrant_safe`; một số class và định danh nền tảng vẫn giữ tên WarrantSafe. Repository này chứa ứng dụng khách, không chứa backend hoặc cơ sở dữ liệu.

## Chức năng

- **Tài khoản:** đăng nhập, lưu và khôi phục phiên, đăng xuất; chế độ API thật hỗ trợ đăng ký và đặt lại mật khẩu bằng OTP email.
- **Trang chủ:** tổng quan thiết bị, yêu cầu và báo giá cần phản hồi.
- **Thiết bị:** xem danh sách thiết bị của khách hàng và chi tiết bảo hành; tạo yêu cầu từ thiết bị đã có.
- **Yêu cầu bảo hành:** tạo yêu cầu từ thiết bị có sẵn hoặc nhập thông tin thiết bị mới, chọn trạm tiếp nhận và thời gian mong muốn, đính kèm ảnh/video.
- **Theo dõi:** xem yêu cầu, phiếu tiếp nhận/sửa chữa, tiến trình và báo giá; xác nhận đồng ý hoặc từ chối báo giá.
- **Tra cứu:** chế độ API thật tra cứu yêu cầu/phiếu theo mã trong phiên khách hàng; chế độ Mock có luồng tra cứu thiết bị mẫu.
- **Thông báo:** hộp thư trong ứng dụng, số chưa đọc, đánh dấu đã đọc và mở phiếu liên quan.

Tệp đính kèm là tùy chọn, tối đa 3 tệp: JPEG/PNG/WebP tối đa 5 MiB mỗi ảnh hoặc MP4 tối đa 30 MiB mỗi video. Máy chủ tiếp tục kiểm tra nội dung tệp.

## Công nghệ và cấu trúc

| Thành phần | Sử dụng |
| --- | --- |
| Flutter / Dart | Giao diện đa nền tảng |
| Provider / ChangeNotifier | Quản lý trạng thái qua ViewModel |
| GoRouter | Điều hướng và chuyển hướng theo trạng thái đăng nhập |
| Dio | Gọi API, Bearer token và xử lý lỗi mạng |
| flutter_secure_storage | Lưu access token, refresh token và định danh phiên |
| shared_preferences | Lưu chế độ Mock/Real và Base URL khi debug |
| file_picker | Chọn tệp đính kèm |
| google_fonts | Phông chữ giao diện |

```text
lib/
├── main.dart          # Khởi tạo ứng dụng, Provider và Router
├── data/              # Dữ liệu mẫu cho chế độ Mock
├── models/            # Tài khoản, thiết bị, yêu cầu, phiếu và thông báo
├── router/            # Route và kiểm soát truy cập theo phiên
├── services/          # Hợp đồng API, triển khai Mock/Real, lưu phiên
├── theme/             # Màu sắc, typography và theme Soopi
├── viewmodels/        # Trạng thái xác thực, yêu cầu và phiếu sửa chữa
├── views/             # Màn hình theo từng chức năng
└── widgets/           # Thành phần giao diện dùng chung
assets/brand/          # Logo và wordmark Soopi
test/                  # Unit test và widget test
web_dev_config.yaml    # Máy chủ Web debug và proxy API cục bộ
```

`AuthViewModel` lựa chọn `MockApiService` hoặc `RealApiService` qua hợp đồng `IApiService`. Các màn hình và ViewModel xử lý dữ liệu Mock/Real riêng theo chế độ. Router giữ màn hình khởi động trong lúc khôi phục phiên và yêu cầu đăng nhập trước khi vào các tab chính.

## Yêu cầu môi trường

- Flutter stable có Dart tương thích với các phiên bản trong `pubspec.lock`. Lockfile hiện yêu cầu **Flutter >= 3.47.0, Dart >= 3.13.0 và < 4.0.0**; môi trường kiểm tra sử dụng Flutter 3.47.8 / Dart 3.13.7.
- Chrome hoặc Edge để chạy Web; Android SDK và emulator/thiết bị để chạy Android.
- JDK 17 tương thích với cấu hình Java/Kotlin của dự án Android.
- Backend Soopi tương thích với các endpoint bên dưới nếu dùng chế độ API thật.

Repository có thư mục nền tảng Android, iOS, Web, Windows, macOS và Linux. Việc có thư mục nền tảng không thay thế kiểm thử trên từng hệ điều hành.

## Cài đặt và chạy nhanh

```sh
git clone https://github.com/longdinh231005-hue/Warrant_App.git
cd Warrant_App
flutter doctor
flutter pub get
flutter devices
```

Chạy Web:

```sh
flutter run -d chrome
```

Có thể thay `chrome` bằng `edge`. File `web_dev_config.yaml` cấu hình địa chỉ `http://localhost:5175` và chuyển tiếp `/api/*` sang backend `http://localhost:8081/`.

Chạy Android hoặc một thiết bị khác trong kết quả `flutter devices`:

```sh
flutter run -d <device-id>
```

### Chế độ Mock — không cần backend

Lần chạy **debug** đầu tiên mặc định dùng Mock. Những lần sau ứng dụng đọc lại chế độ đã lưu. Nhấn giữ **logo trên màn hình đăng nhập** để mở **Cấu hình thử nghiệm**, sau đó bật **Chế độ Mock (Giao diện)**.

| Tài khoản mẫu | Mật khẩu |
| --- | --- |
| `admin@gmail.com` | `123456` |
| `user@gmail.com` | `password123` |

Đây là tài khoản giả lập được khai báo trong `lib/services/api_service.dart`, chỉ dùng để xem thử ứng dụng. Mock không gọi API thật; OTP email và đặt lại mật khẩu cần chế độ Real. Không dùng dữ liệu Mock để kết luận về trạng thái trên backend.

### Chế độ Real — kết nối backend Soopi

1. Khởi động backend riêng; cấu hình phát triển hiện tại hướng tới cổng `8081`.
2. Tại màn hình đăng nhập, nhấn giữ logo và tắt **Chế độ Mock (Giao diện)**.
3. Kiểm tra **Base URL**, sửa nếu cần và bấm **Áp dụng Base URL**.
4. Đăng nhập bằng số điện thoại/tên đăng nhập của tài khoản khách hàng trên backend, hoặc đăng ký bằng OTP email.

| Nơi chạy ứng dụng | Base URL khi phát triển |
| --- | --- |
| Web qua cấu hình có sẵn | `http://localhost:5175/api/v1` — proxy đến backend cổng `8081` |
| Android emulator | `http://10.0.2.2:8081/api/v1` |
| Windows/macOS/Linux trên máy chạy backend | Đặt thủ công `http://localhost:8081/api/v1` |
| Điện thoại thật cùng mạng | Đặt `http://<IP-LAN-may-chay-backend>:8081/api/v1` |

Base URL phải có giao thức `http`/`https`, host và path đúng `/api/v1`. Mặc định debug của Web dùng origin hiện tại; các nền tảng khác mặc định dùng địa chỉ Android emulator. Nếu đã lưu Base URL cũ, giá trị đó được ưu tiên hơn mặc định và `--dart-define` trong bản debug.

Có thể cung cấp cấu hình lúc chạy:

```sh
flutter run -d <device-id> --dart-define=API_URL=http://10.0.2.2:8081/api/v1
```

Đổi chế độ sẽ gỡ phiên đang hoạt động; dữ liệu phiên Mock và Real được lưu bằng các khóa riêng. Các lệnh ghi như gửi yêu cầu và quyết định báo giá không được tự động gửi lại khi lỗi mạng; hãy kiểm tra danh sách/trạng thái trước khi thao tác lại.

## API ứng dụng sử dụng

Các đường dẫn dưới đây tương đối so với Base URL `/api/v1`. Chi tiết request/response nằm trong `lib/services/real_api_service.dart` và `lib/models/`.

| Phương thức | Đường dẫn | Mục đích |
| --- | --- | --- |
| POST | `/auth/mobile/login`, `/auth/mobile/refresh`, `/auth/mobile/logout` | Quản lý phiên |
| POST | `/auth/mobile/otp`, `/auth/mobile/register` | OTP và đăng ký |
| POST | `/auth/mobile/password-reset/verify`, `/auth/mobile/password-reset` | Xác minh OTP và đổi mật khẩu |
| GET | `/portal/my/profile`, `/portal/my/devices` | Hồ sơ và thiết bị của khách hàng |
| GET | `/portal/catalog` | Danh mục thiết bị và trạm |
| GET / POST | `/portal/my/warranty-requests` | Danh sách / tạo yêu cầu bằng multipart |
| GET | `/portal/my/warranty-requests/{code}` | Chi tiết yêu cầu của khách hàng |
| GET | `/portal/my/tickets`, `/portal/tickets/{code}` | Danh sách và chi tiết phiếu |
| POST | `/portal/tickets/{code}/quotation-decision` | Phản hồi báo giá |
| GET | `/notifications` | Hộp thư và số chưa đọc |
| POST | `/notifications/{id}/read` | Đánh dấu đã đọc |

Service còn có luồng cấp quyền tra cứu giới hạn qua `POST /portal/lookup`; màn hình tra cứu Real hiện dùng phiên đăng nhập và các API đọc yêu cầu/phiếu, không yêu cầu nhập số điện thoại để tra cứu.

## Kiểm tra

```sh
flutter analyze
flutter test
```

Các test hiện có bao phủ phân tích dữ liệu API, khôi phục/refresh phiên, OTP email, cấu hình đăng nhập, luồng Mock, tạo yêu cầu, đính kèm, tra cứu, theo dõi phiếu, quyết định báo giá và trạng thái/điều hướng thông báo. Các test sử dụng dữ liệu và bộ giả lập API, không chứng minh việc tích hợp với backend đang chạy.

## Build bản release

Bản release tắt Mock và bắt buộc cung cấp `API_URL` có **HTTPS**, host hợp lệ và path chính xác `/api/v1`. Thay tên miền ví dụ bằng backend thực tế:

```sh
flutter build apk --release --dart-define=API_URL=https://api.example.com/api/v1
flutter build web --release --dart-define=API_URL=https://api.example.com/api/v1
```

- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- Web: `build/web/`. Proxy trong `web_dev_config.yaml` chỉ áp dụng khi phát triển; khi triển khai cần cấu hình reverse proxy hoặc CORS phù hợp trên backend.
- Android release hiện vẫn dùng **debug signing** trong `android/app/build.gradle.kts`; cần cấu hình khóa ký phát hành trước khi phân phối chính thức.

## Xử lý lỗi thường gặp

- **Không kết nối được API:** kiểm tra backend, Base URL đã lưu, cổng `8081` và địa chỉ phù hợp với emulator/thiết bị thật. `localhost` trên điện thoại là chính điện thoại đó.
- **Web lỗi CORS hoặc gọi nhầm cổng:** chạy từ thư mục dự án để Flutter đọc `web_dev_config.yaml`, rồi đặt Base URL về origin hiện tại kèm `/api/v1`.
- **Release báo thiếu/sai `API_URL`:** build lại với `--dart-define=API_URL=https://<host>/api/v1`; không dùng HTTP hoặc thêm dấu `/` sau `/api/v1`.
- **Không nhận OTP:** kiểm tra tài khoản, email và cấu hình gửi thư trên backend; Mock không gửi email.
- **Gửi yêu cầu bị timeout:** kiểm tra danh sách yêu cầu trước khi gửi lại để tránh tạo trùng.
- **Mất mạng lúc khôi phục phiên:** ứng dụng giữ phiên khi lỗi tạm thời và cho phép thử lại; phiên bị backend từ chối mới bị xóa.
