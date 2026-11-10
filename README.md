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
git clone https://github.com/BuiTrongKhang0911/Cloud_Computing_Final.git
cd Cloud_Computing_Final
```

Tạo file cấu hình cục bộ từ mẫu. Không commit file `.env`:

```powershell
Copy-Item .env.example .env
notepad .env
```

Thay các mật khẩu mẫu trong `.env` bằng giá trị riêng trên máy bạn. Giữ nguyên tên biến; Docker Compose dùng các biến này cho MariaDB, Keycloak, MinIO và Grafana.

Build và khởi động toàn bộ stack trên máy phát triển:

```powershell
docker compose -f docker-compose.yml -f docker-compose.build.yml build
docker compose up -d --no-build
docker compose ps
```

Chờ các dịch vụ có healthcheck chuyển sang `healthy`. Dịch vụ không khai báo healthcheck có thể chỉ hiện `Up`.

### Khởi tạo studentdb

Image MariaDB tự chạy các file trong `db/init/` theo thứ tự tên
khi khởi tạo **volume dữ liệu mới**:

1. `001_init.sql`: tạo database `minicloud`, bảng `services` và dữ liệu mẫu.
2. `002_studentdb.sql`: tạo `studentdb`, bảng `students`, thêm 3 sinh viên và cấp quyền cho `minicloud_user`.

Compose đã mount thư mục này vào `/docker-entrypoint-initdb.d`; không cần script
PowerShell để seed DB khi deploy lần đầu. Giữ `MARIADB_USER=minicloud_user` trong
`.env` vì file SQL đang cấp quyền cho username này.

Restart/rebuild container với volume cũ sẽ giữ dữ liệu và **không chạy lại SQL
init**. Khi thay đổi schema hoặc dữ liệu trên DB cũ, áp dụng SQL có chủ đích qua
DB client; không xóa volume đang dùng để ép chạy lại seed.

Nguồn: [MariaDB official image — initializing database contents](https://hub.docker.com/_/mariadb).

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

Realm mẫu `realm_sv001` được import từ `auth/realm/` cùng client `flask-app` và hai user thử nghiệm `sv01`, `sv02`. Mật khẩu demo được khai báo trong file realm import; chỉ dùng cho lab cục bộ và cần thay trước khi công khai repository hoặc triển khai thật.

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

MinIO đảm nhiệm Object Storage Server, mô phỏng lưu trữ bucket/object như S3.
Service `object-storage-server` dùng image có sẵn trong Compose, dữ liệu lưu vào
Docker named volume `minio-data` tại `/data`. Không cần thư mục source hoặc
Dockerfile MinIO riêng. Frontend/backend hiện chưa tích hợp chức năng upload;
bạn demo lưu trữ trực tiếp qua MinIO Console hoặc S3 API.

Đăng nhập Console tại <http://localhost:9001/> bằng `MINIO_ROOT_USER` và
`MINIO_ROOT_PASSWORD` trong `.env`. Demo cơ bản: tạo bucket `demo`, upload
`web/html/index.html` và thử download. Phần mở rộng: tạo bucket `profile-pics`,
upload `avatar.jpg`, kiểm tra URL public object; tạo bucket `documents` và upload
PDF báo cáo. Dùng file demo không nhạy cảm và đưa bucket về private sau demo.

### Kiểm tra cân bằng tải web

Gateway gửi request `/` luân phiên qua hai frontend instance. Chạy:

```powershell
1..6 | ForEach-Object {
  curl.exe -s -i http://localhost/ | Select-String 'X-Backend-Instance|Serving instance'
}
```

Kết quả cần thể hiện cả `web-frontend-server` và `web-frontend-server-2`.

## Cấu trúc dự án

```text
Cloud_Computing_Final/
├── app/
│   ├── Dockerfile
│   ├── app.py
│   ├── requirements.txt
│   └── students.json
├── auth/realm/         # Realm, client, user Keycloak
├── db/init/
│   ├── 001_init.sql
│   └── 002_studentdb.sql
├── dns/
│   ├── db.cloud.local
│   ├── named.conf      # Nạp hai file options/local bên dưới
│   ├── named.conf.local
│   └── named.conf.options
├── grafana/
│   ├── dashboards/
│   └── provisioning/
├── monitor/
│   └── prometheus.yml
├── proxy/
│   └── nginx.conf
├── web/
│   ├── Dockerfile
│   ├── conf.default
│   ├── conf.server-2
│   └── html/
│       ├── blog/       # Index blog, 3 bài viết, ảnh và CSS
│       ├── index.html
│       └── index-server-2.html
├── setup-ec2.sh        # Cài Docker/Compose và khởi động trên Ubuntu EC2
├── docker-compose.yml
├── docker-compose.build.yml # Chỉ dùng khi build image trên máy phát triển
├── .gitattributes      # Giữ LF cho shell script khi clone trên Windows
└── .env.example
```

Compose và `.env` nằm ở gốc để khởi động chung cả 11 container. Tên service,
container, cổng và named volume được giữ nguyên sau khi tổ chức lại thư mục;
tên thư mục mới không thay đổi hostname dùng giữa các container.

| Thư mục | Vai trò |
| --- | --- |
| `web/` | Nginx frontend, blog và instance thứ hai |
| `app/` | Flask API và JWT validation |
| `db/` | MariaDB schema và dữ liệu khởi tạo |
| `auth/` | Keycloak và realm import |
| `proxy/` | Nginx reverse proxy và load balancing |
| `dns/` | Bind9 zone nội bộ |
| `monitor/` | Prometheus scrape targets; Node Exporter dùng image có sẵn trong Compose |
| `grafana/` | Datasource và dashboard provisioning |

Cấu trúc dùng tên thư mục theo ví dụ trong đề. Các file mở rộng cho blog,
web thứ hai, Keycloak và Grafana nằm trong thư mục vai trò tương ứng. MinIO và
Node Exporter dùng image có sẵn trong Compose nên không cần thư mục source riêng;
hệ thống vẫn có đủ 9 loại server.

`.gitattributes` có dòng `*.sh text eol=lf` để Git giữ xuống dòng Linux cho
`setup-ec2.sh`, kể cả khi clone trên Windows có bật `core.autocrlf`. File này
giúp tránh lỗi Bash do CRLF khi đưa script lên EC2 nên được giữ lại.

## Kiểm tra sau khi khởi động

```powershell
docker compose config --quiet
docker compose ps
curl.exe http://localhost/api/student
curl.exe http://localhost/api/students-db
```

Trên Ubuntu, dùng `curl` thay cho `curl.exe` và thêm `sudo` trước lệnh `docker`
nếu tài khoản hiện tại chưa có quyền truy cập Docker. Xem các phần kiểm tra nhanh,
Keycloak, MinIO, DNS và cân bằng tải ở trên để demo từng dịch vụ.

Ảnh demo có thể lưu trong `evidence/` khi thu thập minh chứng. Không đưa mật khẩu,
access token hoặc private key vào ảnh/log công khai.

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
- **API báo `student_database_unavailable`:** xem `docker compose logs relational-database-server application-backend-server`; xác nhận `studentdb` đã được tạo và user có quyền. Volume DB cũ không tự chạy lại SQL init mới thêm vào.
- **Container chưa healthy ngay sau khi start:** chờ thêm rồi xem `docker compose ps` hoặc `docker compose logs <service-name>`.
- **DNS không phân giải được:** kiểm tra `minicloud-dns` đang chạy và truy vấn qua `docker exec minicloud-dns nslookup <name> 127.0.0.1`.

## An toàn khi cộng tác

- Không commit `.env`; mỗi thành viên tạo file riêng từ `.env.example`.
- Không chia sẻ mật khẩu, access token hay khóa riêng qua GitHub/chat.
- File realm có credential demo để phục vụ lab. Giữ repository private cho nhóm; trước khi chuyển sang public, thay hoặc loại bỏ credential demo và rà soát ảnh trong `evidence/`.
- Sau khi thay mật khẩu realm, cập nhật cấu hình local tương ứng để bài kiểm tra xác thực tiếp tục hoạt động.

## Triển khai AWS

Trước khi deploy, build và push 2 custom image lên Docker Hub theo phần hướng dẫn
bên dưới. Sau khi có EC2 Ubuntu, clone hoặc copy **toàn bộ repo** lên máy để lấy
Compose, SQL init, realm Keycloak, config DNS/monitoring, config Nginx gateway
và file mount cho web 2. Backend/frontend nằm trong hai custom image; gateway
dùng image Nginx có sẵn và mount cấu hình. EC2 không build source.

Chạy từ bản repo trên EC2. Script tự lấy public IPv4 qua EC2 Instance Metadata
Service bằng IMDSv2, không cần nhập IP:

```bash
sudo bash setup-ec2.sh
```

Nếu muốn dùng domain hoặc chỉ định địa chỉ, vẫn có thể truyền host:

```bash
sudo bash setup-ec2.sh ec2-example.compute.amazonaws.com
```

File setup thực hiện:

1. Kiểm tra Ubuntu và các file dự án cần thiết.
2. Cài Docker Engine/Compose nếu chưa có, từ [APT repository chính thức của Docker](https://docs.docker.com/engine/install/ubuntu/).
3. Tự lấy public IPv4 qua IMDSv2, hoặc dùng host được truyền vào. Nếu không lấy được địa chỉ, dừng và thông báo; không dùng nhầm private IP.
4. Đọc `.env.example` và hỏi 5 mật khẩu nếu chưa có `.env`: MariaDB root, MariaDB application user, Keycloak admin, MinIO admin và Grafana admin. Mật khẩu được nhập ẩn, tối thiểu 8 ký tự và nhập lại để xác nhận. Script lưu vào `.env` với quyền `600`, cập nhật hai issuer Keycloak theo public IP. Username và tên DB lấy từ file mẫu.
5. Pull toàn bộ image rồi chạy Compose với `--no-build --pull never`, chờ healthcheck; MariaDB tự seed nếu volume mới. Nếu pull thất bại, kiểm tra hai image frontend/backend có tag `latest` và quyền truy cập; script không tự build thay thế.
6. Kiểm tra có ít nhất 3 sinh viên trong DB và gọi API đọc DB qua proxy.

Nếu `.env` đã có đủ mật khẩu hợp lệ, chạy lại không hỏi lại hoặc đổi mật khẩu.
Nếu còn thiếu hoặc còn giá trị mẫu, script chỉ hỏi những mật khẩu đó. Thao tác
nhập mật khẩu cần terminal SSH tương tác; không chạy lần đầu bằng cách pipe file
vào Bash. Khi chạy bằng EC2 user data không có terminal, cần chuẩn bị `.env` sẵn.
File `.env` được `.gitignore` bỏ qua nên `git clone` bình thường chỉ có `.env.example`.

Chạy lại setup giữ nguyên các volume và credential; nó không tự áp dụng lại SQL
seed trên DB cũ. Nếu public IP đổi, chạy lại để tự lấy IP mới và cập nhật issuer.
Tự nhận IP yêu cầu instance có public IPv4 và truy cập được IMDS. Nếu metadata
bị tắt hoặc bạn sử dụng domain riêng, truyền host như ví dụ trên.
Nếu dùng shell SSH trên EC2 để tự lấy token, vẫn truy cập Keycloak bằng public
host đã cấu hình để claim `iss` khớp cấu hình backend.

Nguồn: [AWS — truy cập metadata bằng IMDSv2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html).

File này cấu hình phần mềm **bên trong EC2**, không tạo EC2, Security Group hoặc
push Docker Hub. Cần tự chuẩn bị Security Group cho cổng 80 và các cổng demo
8081, 9000/9001, 9090, 3000 khi cần; giới hạn cổng quản trị theo IP nhóm.
Không cần mở DB hoặc Node Exporter công khai. Hoàn tất Docker Hub và minh chứng
AWS theo yêu cầu bài.

### Build/push ở máy cá nhân, pull/run trên EC2

`docker-compose.yml` khai báo `image:` cho cả 11 service. Chỉ có **2 custom image**
cần build và push; cấu hình build nằm trong `docker-compose.build.yml`:

| Image | Container sử dụng | Dockerfile |
| --- | --- | --- |
| `khangtrong/cloud-final-frontend:latest` | `minicloud-web` và `minicloud-web-2` | `web/Dockerfile` |
| `khangtrong/cloud-final-backend:latest` | `minicloud-app` | `app/Dockerfile` |

Hai web container dùng chung một frontend image. Web 2 mount riêng trang chủ và
config Nginx để nhận biết instance khi demo cân bằng tải. Chỉ build frontend
qua service `web-frontend-server`, không build hoặc push riêng web 2.

Gateway dùng image có sẵn `nginx:1.27-alpine`, mount
`proxy/nginx.conf` vào `/etc/nginx/conf.d/default.conf`. Không cần
Dockerfile hoặc custom image gateway. Cùng MariaDB, Keycloak, MinIO, Bind9,
Prometheus, Node Exporter và Grafana, có **8 service dùng image có sẵn**.
Tổng số container vẫn là 11, gồm 2 web + backend + 8 service hạ tầng.

Theo đề cần push ít nhất 1 custom image; với cách deploy này, publish đủ cả
`khangtrong/cloud-final-frontend:latest` và `khangtrong/cloud-final-backend:latest` trước khi chạy EC2.

Namespace là Docker ID `khangtrong`. Tên repository là `cloud-final-frontend`
và `cloud-final-backend`; `cloud-final` dùng làm tiền tố tên dự án trong repository.
Giữ tag `latest` cho cả hai image, không cần biến namespace/tag trong `.env`.
Đăng nhập đúng tài khoản `khangtrong` trước khi push. Đặt tên image trong Compose
không tạo tài khoản hoặc organization mới trên Docker Hub.

Trên máy cá nhân:

```powershell
docker login -u khangtrong
docker compose -f docker-compose.yml -f docker-compose.build.yml build
docker compose -f docker-compose.yml -f docker-compose.build.yml push web-frontend-server application-backend-server
```

Image phải hỗ trợ kiến trúc CPU của EC2 (`amd64` hoặc `arm64`); nếu máy build và
EC2 khác kiến trúc, cần build cho kiến trúc đích hoặc publish image đa nền tảng.

Trên EC2, `sudo bash setup-ec2.sh` tự thực hiện:

```bash
docker compose pull
docker compose up -d --no-build --pull never --wait --wait-timeout 300
```

Nếu các repository Docker Hub là private, đăng nhập bằng `sudo docker login`
trên EC2 trước khi chạy setup để Docker dưới quyền root có credential phù hợp.
Nguồn: [Docker Compose pull](https://docs.docker.com/reference/cli/docker/compose/pull/),
[Docker Compose push](https://docs.docker.com/reference/cli/docker/compose/push/).
