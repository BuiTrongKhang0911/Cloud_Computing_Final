# MiniCloud — Docker Compose Cloud Lab

Dự án mô phỏng các vai trò hạ tầng cloud bằng Docker Compose: web frontend, API, cơ sở dữ liệu, xác thực, object storage, DNS, giám sát và API gateway. Hướng dẫn này giúp thành viên nhóm clone, chạy thử và kiểm tra các dịch vụ trên máy cá nhân trước khi triển khai lên AWS EC2.

## Yêu cầu

- Git
- Docker Desktop đang chạy, có Docker Compose v2
- PowerShell trên Windows (hoặc shell tương đương trên Linux/macOS)
- Khuyến nghị RAM từ 8 GB để chạy đồng thời các container

## Bắt đầu nhanh trên Windows

Clone repository và vào thư mục dự án:

```powershell
git clone https://github.com/DucAnhWasabi/MiniCloud_Docker.git
cd MiniCloud_Docker
```

Tạo file cấu hình cục bộ từ mẫu. Không commit file `.env`:

```powershell
Copy-Item .env.example .env
notepad .env
```

Thay các mật khẩu mẫu trong `.env` bằng giá trị riêng trên máy bạn. Giữ nguyên tên biến; Docker Compose dùng các biến này cho MariaDB, Keycloak, MinIO và Grafana.

Build và khởi động toàn bộ stack:

```powershell
docker compose up -d --build
docker compose ps
```

Chờ các dịch vụ có healthcheck chuyển sang `healthy`. Dịch vụ không khai báo healthcheck có thể chỉ hiện `Up`.

### Khởi tạo studentdb

Trên volume MariaDB mới, SQL trong `relational-database-server/init/` tự chạy khi database được khởi tạo. Nếu volume đã tồn tại từ lần chạy trước, áp dụng migration bằng script:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\apply-studentdb.ps1
```

Thay đổi execution policy chỉ áp dụng trong PowerShell hiện tại. Script lấy mật khẩu root từ `.env`, không cần nhập mật khẩu trực tiếp vào lệnh.

## Các địa chỉ dịch vụ

| Thành phần | URL/địa chỉ từ máy host | Ghi chú |
| --- | --- | --- |
| Web frontend | <http://localhost:8080/> | Trang chủ |
| Blog | <http://localhost:8080/blog/> | Ba bài viết tĩnh |
| API Gateway | <http://localhost/> | Web qua upstream cân bằng tải |
| Backend API | <http://localhost:8085/> | Cổng backend trực tiếp |
| Keycloak | <http://localhost:8081/> | Admin credentials nằm trong `.env` cục bộ |
| MinIO Console | <http://localhost:9001/> | MinIO API ở cổng 9000 |
| Prometheus | <http://localhost:9090/> | Target health tại `/targets` |
| Grafana | <http://localhost:3000/> | Admin credentials nằm trong `.env` cục bộ |
| MariaDB | `127.0.0.1:3307` | Cổng container là 3306; bind trên loopback |
| DNS | `127.0.0.1:1053` TCP/UDP | DNS nội bộ lắng nghe cổng 53 trong container |

Các container trao đổi với nhau qua mạng Docker `cloud-net`; ứng dụng dùng tên service và cổng nội bộ, ví dụ `relational-database-server:3306`.

## Kiểm tra nhanh

Chạy sau khi stack đã khởi động:

```powershell
curl.exe http://localhost:8080/
curl.exe http://localhost:8080/blog/
curl.exe http://localhost:8085/hello
curl.exe http://localhost/api/student
curl.exe http://localhost/api/students-db
curl.exe http://localhost/student/
```

`/api/student` và `/student/` trả về danh sách 5 sinh viên mẫu. `/api/students-db` truy vấn ba hàng mẫu trong database `studentdb`.

Kiểm tra DNS mở rộng từ container Bind9:

```powershell
docker exec minicloud-dns nslookup app-backend.cloud.local 127.0.0.1
docker exec minicloud-dns nslookup minio.cloud.local 127.0.0.1
docker exec minicloud-dns nslookup keycloak.cloud.local 127.0.0.1
```

Kiểm tra Prometheus tại <http://localhost:9090/targets>; target `web` cần ở trạng thái `UP`. Trong Grafana tại <http://localhost:3000/>, mở dashboard **System Health of SV001** để xem CPU, memory và network.

### Xác thực Keycloak

Realm mẫu `realm_sv001` được import cùng client `flask-app` và hai user thử nghiệm `sv01`, `sv02`. Mật khẩu demo được khai báo trong file realm import; chỉ dùng cho lab cục bộ và cần thay trước khi công khai repository hoặc triển khai thật.

Có thể gọi `/secure` bằng access token. Đoạn PowerShell dưới đây giữ token trong biến; không in hoặc chụp giá trị token:

```powershell
$tokenResponse = Invoke-RestMethod -Method Post `
  -Uri 'http://localhost:8081/realms/realm_sv001/protocol/openid-connect/token' `
  -ContentType 'application/x-www-form-urlencoded' `
  -Body @{ grant_type='password'; client_id='flask-app'; username='sv01'; password='<demo-password-from-realm-import>' }

Invoke-RestMethod -Uri 'http://localhost:8085/secure' `
  -Headers @{ Authorization="Bearer $($tokenResponse.access_token)" }
```

Thay `<demo-password-from-realm-import>` bằng mật khẩu lab đã cấu hình trong realm import. Kết quả mong đợi có `authenticated: true`.

### Kiểm tra MinIO

Đăng nhập MinIO Console bằng thông tin trong `.env`, tạo hai bucket `profile-pics` và `documents`, rồi tải file thử nghiệm lên. Giữ bucket ở chế độ private sau khi hoàn tất demo; không dùng dữ liệu cá nhân nhạy cảm.

### Kiểm tra cân bằng tải web

Gateway gửi request `/` luân phiên qua hai frontend instance. Chạy:

```powershell
1..6 | ForEach-Object {
  curl.exe -s -i http://localhost/ | Select-String 'X-Backend-Instance|Serving instance'
}
```

Kết quả cần thể hiện cả `web-frontend-server` và `web-frontend-server-2`.

## Bằng chứng và cấu trúc dự án

Ảnh chụp được chia theo chức năng trong `evidence/`; xem [evidence/README.md](evidence/README.md) để biết nội dung từng ảnh. Không đưa mật khẩu, access token, private key hoặc thông tin cá nhân vào ảnh hay tài liệu công khai.

| Thư mục | Vai trò |
| --- | --- |
| `web-frontend-server/` | Nginx frontend, blog và instance thứ hai |
| `application-backend-server/` | Flask API và JWT validation |
| `relational-database-server/` | MariaDB schema và dữ liệu khởi tạo |
| `authentication-identity-server/` | Keycloak và realm import |
| `object-storage-server/` | MinIO |
| `internal-dns-server/` | Bind9 zone nội bộ |
| `monitoring-prometheus-server/` | Prometheus scrape targets |
| `monitoring-grafana-dashboard-server/` | Datasource và dashboard provisioning |
| `api-gateway-proxy-server/` | Nginx reverse proxy và load balancing |

## Dừng và dọn môi trường

Dừng container nhưng giữ dữ liệu trong named volumes:

```powershell
docker compose down
```

Xóa cả volumes sẽ xóa dữ liệu MariaDB, MinIO, Keycloak, Prometheus và Grafana; chỉ chạy lệnh sau nếu muốn reset lab:

```powershell
docker compose down -v
```

## Xử lý lỗi thường gặp

- **Không bind được cổng 3306:** database được publish ra `127.0.0.1:3307`. Host dùng cổng 3307; các container vẫn kết nối cổng nội bộ 3306.
- **API báo `student_database_unavailable`:** chạy lại `scripts/apply-studentdb.ps1`, sau đó xem log bằng `docker compose logs application-backend-server`.
- **Container chưa healthy ngay sau khi start:** chờ thêm rồi xem `docker compose ps` hoặc `docker compose logs <service-name>`.
- **DNS không phân giải được:** kiểm tra `minicloud-dns` đang chạy và truy vấn qua `docker exec minicloud-dns nslookup <name> 127.0.0.1`.

## An toàn khi cộng tác

- Không commit `.env`; mỗi thành viên tạo file riêng từ `.env.example`.
- Không chia sẻ mật khẩu, access token hay khóa riêng qua GitHub/chat.
- File realm có credential demo để phục vụ lab. Giữ repository private cho nhóm; trước khi chuyển sang public, thay hoặc loại bỏ credential demo và rà soát ảnh trong `evidence/`.
- Sau khi thay mật khẩu realm, cập nhật cấu hình local tương ứng để bài kiểm tra xác thực tiếp tục hoạt động.

## Triển khai AWS

Triển khai EC2, Security Group, Docker Hub và bằng chứng môi trường AWS thuộc phần tiếp theo của project. Chỉ mở các cổng cần thiết và giới hạn nguồn truy cập theo IP nhóm; không mở database hoặc dashboard quản trị công khai.
