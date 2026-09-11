# Moodle trên GCP / AWS bằng Terraform

Mỗi cloud một root module, tạo VPC mới hoàn toàn rồi dựng một VM Debian 13 amd64
chạy Moodle sau Traefik.

VM không có source code và không build gì. Terraform đọc
`examples/traefik/docker-compose.yml` của repo, nhúng vào metadata của VM cùng file
`.env` đã sinh sẵn, và bootstrap script chỉ làm ba việc: cài Docker từ apt repo chính
thức, ghi hai file đó vào `/opt/moodle`, rồi `docker compose up -d` để pull
`abstechnology/moodle-standard:5.2.2-r5` từ Docker Hub.

```
make gcp   # VPC + VM + Moodle trên GCP
make aws   # VPC + VM + Moodle trên AWS
```

Cả hai đều chạy `terraform apply` ở chế độ tương tác: bạn xem plan rồi gõ `yes`.

## Quy trình đầy đủ

Bảy bước, hai giai đoạn: deploy ngay bằng nip.io để khách hàng dùng được luôn, rồi
chuyển sang domain và chứng chỉ thật khi đã mua.

### Giai đoạn 1 — deploy bằng nip.io

**1.** Điền `terraform/aws/terraform.tfvars`: `access_key`, `secret_key`, `region`,
`acme_email`, và `ssh_allowed_cidrs = ["0.0.0.0/0"]`. GCP thì điền `project_id` thay
cho key/secret. Xem file `.example` cạnh đó.

**2.** `make aws` (hoặc `make gcp`), xem plan rồi gõ `yes`. Khoảng 4–6 phút sau site có
HTTPS thật tại `https://moodle.<ip>.nip.io`, chứng chỉ Let's Encrypt, không cần làm gì
với DNS.

**3.** Lấy tài khoản admin của Moodle và IP:

```bash
terraform -chdir=terraform/aws output -raw moodle_admin_user      # absi_admin
terraform -chdir=terraform/aws output -raw moodle_admin_password  # Terraform sinh
terraform -chdir=terraform/aws output -raw public_ip              # ghi lại IP này
```

Đổi tên admin bằng `moodle_admin_user` trong tfvars trước khi apply; mật khẩu thì luôn
do Terraform sinh. Đây là tài khoản đăng nhập Moodle, khác với user SSH vào VM (`admin`
trên cả hai cloud).

**4.** Giao site cho khách hàng. IP ở bước 3 là địa chỉ tĩnh và **không đổi** về sau —
đó là lý do giai đoạn 2 nhẹ nhàng.

### Giai đoạn 2 — chuyển sang domain và cert của bạn

**5.** Trỏ A record của domain mới về đúng IP ở bước 3. Site nip.io vẫn chạy bình
thường suốt lúc chờ DNS lan, khách hàng chưa bị ảnh hưởng gì.

**6.** Đẩy cặp chứng chỉ lên máy:

```bash
scp -i terraform/aws/break-glass.pem fullchain.pem privkey.pem admin@<IP>:/tmp/
```

**7.** Vào máy và chạy một lệnh:

```bash
ssh -i terraform/aws/break-glass.pem admin@<IP>
cd /opt/moodle
sudo ./change-domain.sh --domain lms.example.com \
    --cert /tmp/fullchain.pem --key /tmp/privkey.pem
```

Gõ tên domain mới để xác nhận, khoảng 30 giây là xong. Muốn dùng Let's Encrypt cho
domain mới thay vì chứng chỉ đã mua thì thay hai tham số cert bằng `--letsencrypt`.

Hai điều cần biết trước khi chạy bước 7. `fullchain.pem` phải là chuỗi đầy đủ với cert
lá đứng đầu, và key không được đặt passphrase — script từ chối ngay trước khi đụng vào
gì nếu sai. Sau khi chạy, domain nip.io ngừng hoạt động và mọi người đang đăng nhập bị
đăng xuất, nên chọn giờ thấp điểm. Độ dài domain không quan trọng; xem
[Chuyển site đang chạy sang domain và cert của bạn](#chuyển-site-đang-chạy-sang-domain-và-cert-của-bạn).

## Truy cập SSH

Mặc định không cloud nào mở port 22 ra internet.

| | Cách vào | Cơ chế |
|---|---|---|
| GCP | `make gcp-ssh` | IAP TCP forwarding — firewall chỉ allow 22 từ `35.235.240.0/20`, cộng OS Login để phân quyền bằng IAM thay vì metadata key |
| AWS | `make aws-ssh` | SSM Session Manager — security group **không có** inbound 22 nào; agent tự mở kết nối ra ngoài |

Cả hai đường trên đều phụ thuộc credential của cloud CLI còn hạn. Muốn một đường
không phụ thuộc gì cả, xem SSH break-glass bên dưới.

Vì AMI Debian không cài sẵn SSM agent, bootstrap script tải và cài nó trước khi làm
việc khác. Nếu bước này lỗi thì `make aws-ssh` sẽ không vào được.

`aws ssm start-session` cần plugin cài riêng trên máy bạn:

```bash
brew install --cask session-manager-plugin
```

### SSH break-glass

SSM và IAP đều hỏng theo cùng một kiểu: token CLI hết hạn, hoặc agent không lên, là
mất đường vào VM. `ssh_allowed_cidrs` mở thêm một đường độc lập, có trên cả hai cloud:

```hcl
ssh_allowed_cidrs = ["1.2.3.4/32"]     # chỉ IP của bạn
ssh_allowed_cidrs = ["0.0.0.0/0"]      # mọi client
```

Terraform sinh key ED25519, ghi ra `terraform/<cloud>/break-glass.pem` quyền 0600, và
mở port 22 cho đúng các CIDR đó. Danh sách rỗng thì không có key pair nào và port 22
đóng hoàn toàn.

```bash
ssh -i terraform/aws/break-glass.pem admin@$(terraform -chdir=terraform/aws output -raw public_ip)
```

`make gcp-ssh` và `make aws-ssh` tự chọn đúng lệnh tùy biến này có được đặt hay không.

Mở `0.0.0.0/0` là chấp nhận được vì xác thực là key-only: image Debian của cả hai cloud
tắt sẵn `PasswordAuthentication` và `PermitRootLogin`, nên cái bạn nhận thêm chủ yếu là
log brute-force. Đổi lại là không bao giờ mất quyền vào máy khi IP nhà bạn thay đổi.

Hai khác biệt giữa hai cloud:

- **AWS**: thêm hoặc bỏ biến này sẽ **tạo lại VM**, vì `key_name` là thuộc tính không
  đổi được của EC2 instance. Quyết định trước khi có dữ liệu thật.
- **GCP**: đặt biến này sẽ **tắt OS Login**, vì OS Login cố tình bỏ qua metadata key.
  Phân quyền chuyển từ IAM sang việc ai giữ file `.pem`.

## Chuẩn bị

Cả hai cần Terraform >= 1.5 và một file `terraform.tfvars`:

```bash
cp terraform/gcp/terraform.tfvars.example terraform/gcp/terraform.tfvars
cp terraform/aws/terraform.tfvars.example terraform/aws/terraform.tfvars
```

`acme_email` bắt buộc và phải là TLD công khai thật — Let's Encrypt từ chối `.test`,
`.local` và các TLD dành riêng khác.

**GCP** — cần `project_id`, quyền tạo VPC/instance, và:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project <project_id>
```

Phải chạy **cả hai** lệnh auth. `gcloud auth login` chỉ cấp credential cho CLI, còn
Terraform đọc application-default credentials — một bộ hoàn toàn riêng. Nếu bạn đổi
account bằng `gcloud auth login` mà quên lệnh thứ hai, `gcloud projects list` sẽ chạy
đúng với account mới trong khi `terraform apply` vẫn bị 403 dưới identity cũ.

Hoặc dùng service account, không phụ thuộc credential cá nhân:

```hcl
credentials = "/path/to/sa-key.json"
```

Service account cần `roles/compute.admin`, và `roles/serviceusage.serviceUsageAdmin`
nếu để `enable_apis = true`.

Để `make gcp-ssh` hoạt động, account của bạn cần `roles/iap.tunnelResourceAccessor`
và `roles/compute.osLogin` (owner đã có sẵn). Module tự enable
`compute.googleapis.com`; nếu bạn không có quyền `serviceusage` thì đặt
`enable_apis = false`.

**AWS** — xác thực bằng access key và secret của một IAM user. Module tự tạo IAM role,
instance profile, VPC, subnet, IGW, security group và Elastic IP.

Khai báo trong `terraform/aws/terraform.tfvars` — file này đã được `.gitignore`:

```hcl
access_key = "AKIA..."
secret_key = "..."
region     = "ap-southeast-1"
acme_email = "admin@absi.tech"
```

Hai cách thay thế, nếu bạn không muốn key nằm trên đĩa trong repo:

```bash
# biến môi trường
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...

# hoặc named profile
aws configure --profile absi-moodle
echo 'profile = "absi-moodle"' >> terraform/aws/terraform.tfvars
```

Cả ba đều dùng chung một provider block; biến nào để trống thì bị bỏ qua. Provider
config không được ghi vào state, nên key không lọt vào `terraform.tfstate`.

IAM user cần quyền trên EC2 (VPC, subnet, internet gateway, route table, security
group, network interface, Elastic IP, instance) và IAM (`CreateRole`,
`AttachRolePolicy`, `CreateInstanceProfile`, `PassRole`) để dựng được instance profile
cho SSM. Dùng IAM user thay vì access key của root — key root có toàn quyền và không
thu hồi được từng phần.

## Dựng trong AWS Local Zone

```hcl
availability_zone = "ap-southeast-1-han-1a"
instance_type     = "m7i.large"
```

Ba điều bắt buộc phải biết, nếu sai thì `apply` sẽ đứt giữa đường:

**Zone group phải opt-in trước.** Terraform không làm được việc này:

```bash
aws ec2 modify-availability-zone-group \
  --group-name ap-southeast-1-han-1 --opt-in-status opted-in
```

**Local Zone không có họ instance burstable.** Hà Nội chỉ có `c7i`, `m7i`, `r7i` —
`t3.medium` mặc định sẽ bị từ chối. Liệt kê những gì zone đó có:

```bash
aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=location,Values=ap-southeast-1-han-1a \
  --query 'sort(InstanceTypeOfferings[].InstanceType)' --output text
```

**Elastic IP phải cấp đúng network border group.** Local Zone Hà Nội nằm trong group
`ap-southeast-1-han-1`, không phải `ap-southeast-1`. Module tự lấy giá trị này từ
`data.aws_availability_zone`, nên bạn chỉ cần đặt `availability_zone`. Nếu cấp EIP ở
group của region rồi gắn vào interface trong Local Zone, AWS trả về
`OperationNotPermitted: Cannot associate addresses across network border groups`.

Subnet Local Zone vẫn route ra internet qua internet gateway của region, và SSM Session
Manager vẫn hoạt động vì agent gọi ra endpoint region. gp3 được hỗ trợ. Giá instance ở
Local Zone cao hơn trong region, và không có lựa chọn burstable nên đừng để VM chạy
không.

## Domain và chứng chỉ

Để trống `moodle_domain` thì domain được suy ra từ IP tĩnh: `moodle.<ip>.nip.io`.
nip.io resolve wildcard nên không cần cấu hình DNS, và Traefik xin được chứng chỉ
Let's Encrypt thật ngay lần boot đầu.

Trên AWS, Elastic IP được gắn vào network interface **trước khi** VM launch, nên VM
boot lên là đã giữ đúng IP cuối cùng và domain resolve được ngay.

Muốn dùng domain riêng thì đặt `moodle_domain`, apply, lấy `public_ip` từ output rồi
trỏ A record vào đó. Traefik sẽ retry ACME tới khi DNS lan xong.

Khi test nhiều lần, bật `acme_staging = true` để tránh rate limit của Let's Encrypt
(chứng chỉ sẽ không được trust).

### Chuyển site đang chạy sang domain và cert của bạn

Các bước cụ thể nằm ở [Quy trình đầy đủ](#quy-trình-đầy-đủ) phía trên. Phần này giải
thích vì sao phải làm như vậy.

Đổi `moodle_domain` trong tfvars rồi apply lại **không** làm được việc này. Terraform
để `startup-script`/`user_data` dưới `ignore_changes` nên VM không bị đụng tới, và kể
cả có đụng thì cũng vô ích: image chỉ sinh `config.php` đúng một lần lúc cài, còn URL
cũ thì đã nằm rải rác trong database.

Nên việc này làm trên VM, bằng `change-domain.sh` mà Terraform đặt sẵn ở đó. Script
kiểm tra cert khớp key, đúng SAN, đủ chain và domain đã resolve về máy này trước khi
đụng vào bất cứ thứ gì; sau đó backup database, `config.php` và `moodledata`, bật
maintenance mode, sửa `wwwroot`, chạy `admin/tool/replace` trên toàn database, chuyển
địa chỉ no-reply, purge cache và session, rồi tự kiểm tra lại. Chi tiết và các cờ bỏ
bước nằm trong [../examples/traefik/README.md](../examples/traefik/README.md).

Domain mới dài hơn tên nip.io cũng không sao. Moodle mặc định từ chối trường hợp đó và
script tự truyền `--shorten` để đi tiếp; cột TEXT chứa nội dung khoá học vẫn được thay
nguyên vẹn, chỉ cột VARCHAR độ dài cố định đã sát giới hạn mới bị cắt phần tràn.

Sau khi chuyển, `moodle_domain` trong tfvars không còn là sự thật nữa; cập nhật lại cho
khớp để người sau đọc không hiểu nhầm, apply sẽ không làm gì thêm.

## Port mở

| Port | Lý do |
|---|---|
| 80/tcp | ACME HTTP-01 challenge, và redirect sang HTTPS |
| 443/tcp | HTTPS |
| 443/udp | HTTP/3 (QUIC) |
| 22/tcp | GCP: chỉ từ dải IAP. AWS: không mở. |

## Mật khẩu

Terraform sinh ngẫu nhiên mật khẩu admin Moodle và MariaDB. Đọc bằng:

```bash
terraform -chdir=terraform/gcp output -raw moodle_admin_password
terraform -chdir=terraform/aws output -raw moodle_admin_password
```

Bộ ký tự đặc biệt bị giới hạn ở `!@%^*-_=+` vì Docker Compose nội suy giá trị trong
`.env`, nên `$`, `` ` ``, `#`, dấu nháy và backslash sẽ làm sai mật khẩu.

State file chứa các mật khẩu này ở dạng plaintext. `.gitignore` đã loại `*.tfstate`
và `terraform/*/terraform.tfvars`; nếu dùng nhiều người thì chuyển sang backend GCS/S3
có mã hoá.

## Theo dõi lần boot đầu

Bootstrap mất khoảng 3–5 phút (cài Docker, pull image, Moodle tự cài schema). Xem log:

```bash
terraform -chdir=terraform/aws output -raw bootstrap_log_command   # rồi chạy lệnh in ra
```

Kiểm tra khi xong:

```bash
curl -sI "$(terraform -chdir=terraform/aws output -raw site_url)"        # 200
curl -s  "$(terraform -chdir=terraform/aws output -raw site_url)/readyz" # ready
```

## Xoá

```bash
make gcp-destroy
make aws-destroy
```

Destroy xoá luôn VM và disk, tức là mất toàn bộ data Moodle. Backup `/opt/moodle/data`
trước nếu cần giữ.

## Vì sao VM không bị replace ngoài ý muốn

Cả hai module `ignore_changes` trên bootstrap script (và trên `ami` ở AWS, vì
`data.aws_ami` cuộn tới bản mới mỗi tuần). Nếu không, một thay đổi nhỏ trong compose
file hoặc một AMI mới sẽ khiến `apply` huỷ VM đang chạy kèm dữ liệu. Muốn áp dụng
compose mới thì SSH vào và `cd /opt/moodle && docker compose up -d`, hoặc taint VM một
cách có ý thức.
