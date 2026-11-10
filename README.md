# MiniCloud

MiniCloud là dự án mô phỏng hạ tầng cloud bằng Docker Compose, gồm frontend HTML, backend Flask API và các dịch vụ cơ sở dữ liệu, xác thực, lưu trữ, DNS, giám sát. Dự án có thể chạy toàn bộ trên một EC2 Ubuntu.

## Thành phần dự án

| Thư mục | Vai trò |
| --- | --- |
| `web/` | Frontend HTML/CSS, blog và cấu hình hai web server |
| `app/` | Backend Flask, API sinh viên, kết nối MariaDB và xác thực token |
| `proxy/` | Nginx gateway, định tuyến API và cân bằng tải giữa hai web server |
| `db/init/` | SQL tạo database và dữ liệu ban đầu |
| `auth/realm/` | Realm, client và user mẫu của Keycloak |
| `dns/` | Bind9 và các bản ghi nội bộ `cloud.local` |
| `monitor/` | Cấu hình Prometheus; Node Exporter cung cấp số liệu hệ thống |
| `grafana/` | Datasource và dashboard Grafana |

MinIO chạy bằng image có sẵn và lưu file trong Docker volume. Các dịch vụ giao tiếp qua mạng `cloud-net`. Hai web server dùng chung image frontend; backend dùng một image riêng. `docker-compose.yml` dùng để pull/chạy dịch vụ, `docker-compose.build.yml` bổ sung cấu hình build frontend và backend. `setup-ec2.sh` tự động cấu hình và khởi động trên Ubuntu EC2.

## 1. Chuẩn bị EC2 và Security Group

Tạo một EC2 Ubuntu có public IPv4, chọn key pair và tải file `.pem` về máy. Tất cả dịch vụ chạy bằng Docker Compose trên cùng EC2.

Trong **EC2 → Instances → chọn instance → Security → Security group → Edit inbound rules**, thêm các cổng sau. Các cổng truy cập từ máy bên ngoài được cấu hình như sau:

| Type | Port range | Protocol | Source | Dịch vụ |
| --- | --- | --- | --- | --- |
| Custom TCP | 9001 | TCP | 0.0.0.0/0 | MinIO Console |
| Custom TCP | 3000 | TCP | 0.0.0.0/0 | Grafana |
| Custom TCP | 9090 | TCP | 0.0.0.0/0 | Prometheus |
| Custom TCP | 8081 | TCP | 0.0.0.0/0 | Keycloak |
| SSH | 22 | TCP | 0.0.0.0/0 | SSH |
| HTTP | 80 | TCP | 0.0.0.0/0 | Gateway, frontend và API |
| Custom TCP | 9000 | TCP | 0.0.0.0/0 | MinIO API và file public |

Bấm **Save rules**. Rule ID và tên Security Group do AWS cấp cho từng môi trường, không cần giống máy mẫu. `0.0.0.0/0` cho phép mọi IP truy cập; nên giới hạn SSH và các cổng quản trị bằng **My IP** khi dùng thực tế.

Để sử dụng các URL bên dưới, không cần mở thêm cổng 8080, 8085, 3307, 1053 hoặc 9100. Truy cập HTTP không ghi cổng sẽ dùng cổng 80.

## 2. SSH vào EC2 và chạy setup

Trên máy Windows, mở PowerShell tại thư mục chứa key:

```powershell
ssh -i ".\Cloud-Final.pem" ubuntu@PUBLIC_IP_EC2
```

Thay `PUBLIC_IP_EC2` bằng public IPv4 trong AWS Console. Lần đầu kết nối, nhập `yes` nếu đã xác nhận đúng instance.

Sau khi vào Ubuntu, clone dự án và chạy:

```bash
git clone https://github.com/BuiTrongKhang0911/Cloud_Computing_Final.git
cd Cloud_Computing_Final
sudo bash setup-ec2.sh
```

Script tự lấy public IP qua EC2 metadata, cài Docker/Compose nếu chưa có, tạo `.env` từ `.env.example` và hỏi 5 mật khẩu: MariaDB root, MariaDB application user, Keycloak admin, MinIO admin và Grafana admin. Mật khẩu nhập ẩn, tối thiểu 8 ký tự và cần xác nhận lại.

Script pull image từ Docker Hub và khởi động các dịch vụ; EC2 không build image. Hai image `khangtrong/cloud-final-frontend:latest` và `khangtrong/cloud-final-backend:latest` phải được publish trước. Script cũng tự cho phép HTTP cho các realm Keycloak `master`, `minicloud`, `realm_sv001`.

Nếu đã clone và muốn cập nhật bản mới:

```bash
cd ~/Cloud_Computing_Final
git pull
sudo bash setup-ec2.sh
```

Chạy lại giữ dữ liệu trong volume và mật khẩu đã cấu hình. MariaDB chỉ tự nhập SQL khởi tạo khi volume dữ liệu còn mới. Script không tự tạo bucket hay cấp quyền public MinIO.

Kiểm tra phiên bản Docker và trạng thái các dịch vụ:

```bash
docker --version
sudo docker compose version
sudo docker compose ps
```

Nếu tự nhận public IP thất bại, có thể truyền IP vào:

```bash
sudo bash setup-ec2.sh PUBLIC_IP_EC2
```

## 3. Truy cập ứng dụng và dịch vụ

Thay `PUBLIC_IP_EC2` trong các URL dưới đây bằng IP thật. Các URL này truy cập từ trình duyệt hoặc Postman trên máy bạn.

| Thành phần | URL | Nội dung kiểm tra |
| --- | --- | --- |
| Frontend qua gateway | `http://PUBLIC_IP_EC2/` | Trang chủ |
| Blog | `http://PUBLIC_IP_EC2/blog/` | Danh sách bài và ba bài blog có ảnh, liên kết |
| Backend hello qua gateway | `http://PUBLIC_IP_EC2/api/hello` | JSON lời chào |
| API sinh viên từ JSON | `http://PUBLIC_IP_EC2/api/student` | 5 sinh viên |
| API sinh viên từ MariaDB | `http://PUBLIC_IP_EC2/api/students-db` | Ít nhất 3 sinh viên |
| Route student qua gateway | `http://PUBLIC_IP_EC2/student/` | Danh sách sinh viên |
| API cần token | `http://PUBLIC_IP_EC2/api/secure` | 401 khi không có token; 200 khi token hợp lệ |
| Keycloak | `http://PUBLIC_IP_EC2:8081/admin/` | Quản trị realm, user và client |
| Prometheus targets | `http://PUBLIC_IP_EC2:9090/targets` | Các target UP |
| Prometheus query | `http://PUBLIC_IP_EC2:9090/query` | Truy vấn `node_cpu_seconds_total` |
| Grafana | `http://PUBLIC_IP_EC2:3000/` | Dashboard và datasource |
| MinIO Console | `http://PUBLIC_IP_EC2:9001/` | Tạo bucket, upload/download |
| MinIO object | `http://PUBLIC_IP_EC2:9000/TEN_BUCKET/TEN_FILE` | Đọc file nếu đã cấp quyền public |

Tài khoản mặc định trong file mẫu: Keycloak `admin`, Grafana `admin`, MinIO `minioadmin`. Dùng mật khẩu tương ứng đã nhập khi chạy setup.

Để đối chiếu backend trực tiếp với gateway, chạy trên terminal SSH EC2; không cần mở cổng 8085 ra Internet:

```bash
curl --fail http://127.0.0.1:8085/hello
curl --fail http://127.0.0.1/api/hello
```

Hai lệnh phải trả cùng JSON lời chào.

### Keycloak và Postman

Realm mẫu `realm_sv001` có user `sv01`, `sv02` và public client `flask-app` với Direct access grants bật. Có thể quản lý tại các mục **Users** và **Clients** trong Keycloak.

Endpoint `/api/secure` yêu cầu Bearer token. Nếu gọi `GET http://PUBLIC_IP_EC2/api/secure` với **No Auth**, API trả về 401.

Để lấy token, tạo request **POST**:

```text
http://PUBLIC_IP_EC2:8081/realms/realm_sv001/protocol/openid-connect/token
```

Chọn **No Auth → Body → x-www-form-urlencoded**:

| Key | Value |
| --- | --- |
| grant_type | password |
| client_id | flask-app |
| username | sv01 |
| password | Mật khẩu hiện tại của sv01 |

Mật khẩu khởi tạo của user demo `sv01` trong file realm là `Sv01-demo-change-me`; nếu đã đổi trong Keycloak thì dùng mật khẩu mới. Đây là mật khẩu user demo, khác mật khẩu quản trị.

Copy `access_token` từ phản hồi. Gọi lại `/api/secure`, chọn **Authorization → Bearer Token** và dán token. Token hợp lệ sẽ nhận response 200 cùng thông tin user.

Nếu đổi tên realm `realm_sv001`, cần cập nhật đồng bộ file realm import, cấu hình backend trong Compose, issuer trong `.env`, script setup và URL lấy token. Thay file import không tự đổi realm đã tồn tại trong volume Keycloak.

### Grafana

Vào **Dashboards → MiniCloud → System Health of SV001**, hoặc:

```text
http://PUBLIC_IP_EC2:3000/d/system-health-sv001
```

Chọn **Last 15 minutes → Refresh** để xem CPU, Memory và Network. Nếu mới khởi động thì đợi vài phút để thu thập số liệu.

Vào **Connections → Data sources → Prometheus**, kiểm tra URL nội bộ:

```text
http://monitoring-prometheus-server:9090
```

Bấm **Save & test** để kiểm tra kết nối. Datasource và dashboard được provision sẵn từ thư mục `grafana/`.

## 4. Vận hành và xử lý sự cố

Các thao tác dưới đây dùng khi cần xem dữ liệu, cấu hình quyền truy cập hoặc kiểm tra kết nối; không cần chạy toàn bộ sau mỗi lần khởi động.

### Xem dữ liệu MariaDB

Chạy trong terminal SSH EC2 tại thư mục dự án:

```bash
sudo docker compose exec relational-database-server mariadb -u root -p
```

Nhập mật khẩu **MariaDB root** đã đặt khi setup. Khi xuất hiện dấu nhắc MariaDB, chạy SQL riêng như sau:

```sql
USE studentdb;
DESCRIBE students;
SELECT * FROM students;
```

Bảng gồm `id`, `student_id`, `fullname`, `dob`, `major`; dữ liệu khởi tạo có 3 sinh viên. API `/api/students-db` đọc từ database, còn `/api/student` trả danh sách 5 sinh viên từ file JSON.

Thoát MariaDB trước khi chạy các lệnh Linux tiếp theo:

```sql
exit;
```

### Quản lý file và cấp quyền đọc công khai trong MinIO

Mở MinIO Console ở cổng 9001 để tạo bucket, upload và download file. Ví dụ: bucket `profile-pics` chứa ảnh và `documents` chứa tài liệu PDF. Tên bucket và file do người dùng lựa chọn.

Giao diện Object Browser hiện tại không có mục chỉnh public policy. Khi cần chia sẻ file không yêu cầu đăng nhập, dùng `mc` trong container để cấp quyền đọc/tải xuống cho bucket đã tạo.

**Ví dụ bạn có bucket tên `profile-pics`**, chạy trên terminal SSH EC2:

```bash
sudo docker compose exec object-storage-server sh -eu -c '
mc alias set demo-local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
mc anonymous set download demo-local/profile-pics
mc anonymous get demo-local/profile-pics
'
```

**Thay `profile-pics` ở cả hai dòng cuối bằng tên bucket của bạn.** `demo-local` là tên kết nối tới MinIO. Lệnh chỉ thay đổi policy của bucket được chỉ định; các bucket khác giữ nguyên. Mọi file hiện có và upload sau này trong bucket đó được đọc/tải xuống ẩn danh; không cấp quyền upload hoặc xóa ẩn danh.

Mở cửa sổ ẩn danh và truy cập đúng tên file, ví dụ:

```text
http://PUBLIC_IP_EC2:9000/profile-pics/avatar.jpg
```

Nếu file thật là `OIP.webp` thì dùng:

```text
http://PUBLIC_IP_EC2:9000/profile-pics/OIP.webp
```

MinIO hỗ trợ nhiều định dạng file. URL phải khớp chính xác tên bucket và tên object, bao gồm chữ hoa/thường và phần mở rộng. Dùng cửa sổ ẩn danh để kiểm tra file có truy cập được khi chưa đăng nhập hay không.

### Kiểm tra DNS nội bộ

Chạy trong terminal SSH EC2:

```bash
sudo docker compose exec internal-dns-server sh -eu -c '
for name in web-frontend-server.cloud.local app-backend.cloud.local minio.cloud.local keycloak.cloud.local; do
    echo "=== $name ==="
    dig @127.0.0.1 "$name" A +short
done
'
```

Kết quả theo zone hiện tại:

| Tên miền | IP nội bộ Docker |
| --- | --- |
| web-frontend-server.cloud.local | 172.28.0.11 |
| app-backend.cloud.local | 172.28.0.12 |
| minio.cloud.local | 172.28.0.15 |
| keycloak.cloud.local | 172.28.0.13 |

Đối chiếu IP trả về với bảng trên. Đây là kiểm tra DNS nội bộ, không cần mở cổng 1053 ra Internet.

### Kiểm tra kết nối giữa các container

Lệnh tạo container kiểm tra tạm trong mạng `cloud-net`, ping 11 container rồi tự xóa container kiểm tra. Lần đầu Docker có thể tải image BusyBox.

```bash
sudo docker run --rm --network cloud-net busybox:1.36 sh -c '
failed=0
for service in \
web-frontend-server \
web-frontend-server-2 \
application-backend-server \
relational-database-server \
authentication-identity-server \
object-storage-server \
internal-dns-server \
monitoring-prometheus-server \
monitoring-node-exporter-server \
monitoring-grafana-dashboard-server \
api-gateway-proxy-server
do
    if ping -c 2 -W 3 "$service" >/dev/null 2>&1; then
        printf "PASS  %s\n" "$service"
    else
        printf "FAIL  %s\n" "$service"
        failed=1
    fi
done
exit "$failed"
'
```

Kết quả bình thường có 11 dòng PASS. Nếu có FAIL, kiểm tra container tương ứng và mạng `cloud-net`. Ping kiểm tra thông mạng; dùng healthcheck và request API để kiểm tra trạng thái ứng dụng.

### Kiểm tra cân bằng tải

Copy nguyên khối sau vào terminal SSH, gồm cả dòng `PY` cuối cùng. Python được cài bởi script setup.

```bash
python3 - <<'PY'
import http.client

conn = http.client.HTTPConnection("127.0.0.1", 80, timeout=10)
seen = set()

for number in range(1, 9):
    conn.request("GET", "/")
    response = conn.getresponse()
    backend = response.getheader("X-Backend-Instance")
    response.read()
    print(f"Request {number}: HTTP {response.status} | Backend: {backend}")
    if response.status == 200 and backend:
        seen.add(backend)

conn.close()
expected = {"web-frontend-server", "web-frontend-server-2"}
passed = expected.issubset(seen)
print("\nLoad balancing:", "PASS - both web servers responded" if passed else "FAIL - check results")
raise SystemExit(0 if passed else 1)
PY
```

Kết quả bình thường có HTTP 200 từ cả `web-frontend-server` và `web-frontend-server-2`, cùng dòng `Load balancing: PASS - both web servers responded`. Nếu FAIL, kiểm tra trạng thái hai web server và cấu hình upstream trong `proxy/nginx.conf`.

Lệnh gọi gateway ở `127.0.0.1:80` trên EC2. Dùng cùng kết nối để quan sát hai backend qua Nginx. DNS, ping và load balancing ở đây đều chạy trên EC2; không cần mở thêm cổng Security Group.

### Xem trạng thái và log

Chạy tại thư mục dự án trên EC2:

```bash
sudo docker compose ps
sudo docker compose logs --tail=100
```

Để xem log một dịch vụ, ví dụ backend:

```bash
sudo docker compose logs --tail=100 application-backend-server
```

Khởi động lại một dịch vụ sau khi sửa cấu hình bind mount, ví dụ gateway:

```bash
sudo docker compose restart api-gateway-proxy-server
```

Nếu trình duyệt báo timeout nhưng dịch vụ vẫn healthy, kiểm tra public IP, cổng và Source trong Security Group. Các lệnh Docker ở đây dùng `sudo` để tránh lỗi quyền truy cập `/var/run/docker.sock`.
