# Hướng dẫn bài Lab: Amazon Macie & Cảnh báo qua Email (SNS)

Tài liệu này hướng dẫn bạn cách thiết lập và chạy bài Lab tự động hóa phát hiện dữ liệu nhạy cảm bằng **Amazon Macie** trên AWS S3 và gửi thông tin cảnh báo về **Email** thông qua **EventBridge** và **SNS**.

---

## Các thành phần đã chuẩn bị sẵn
1. **[main.tf](file:///d:/uni/xbrain/phase_2/w10/fri-lab/main.tf)**: Script Terraform tự động cấu hình:
   - Tạo S3 Bucket ngẫu nhiên và tải file dữ liệu lên.
   - Kích hoạt Amazon Macie.
   - Tạo SNS Topic và đăng ký nhận email (Subscription).
   - Tạo EventBridge Rule để bắt sự kiện "Macie Finding".
   - Tạo Amazon Macie Classification Job quét tự động một lần (ONE_TIME).
2. **[sensitive_data.txt](file:///d:/uni/xbrain/phase_2/w10/fri-lab/sensitive_data.txt)**: File dữ liệu chứa các thông tin nhạy cảm giả lập (Credit Card, SSN, Phone, Email...) để Macie phát hiện.

---

## Hướng dẫn các bước chạy chi tiết

### Bước 1: Cấu hình AWS CLI với tài khoản của bạn
Trước khi chạy, hãy chắc chắn rằng bạn đã đăng nhập đúng tài khoản AWS `783459135560` với username `ductran`.
Chạy lệnh sau trên terminal/cmd:
```powershell
aws configure
```
Nhập các thông tin sau:
- **AWS Access Key ID**: Access Key của user `ductran`
- **AWS Secret Access Key**: Secret Key của user `ductran`
- **Default region name**: `ap-southeast-1` (hoặc vùng bạn muốn triển khai)
- **Default output format**: `json`

Kiểm tra kết nối bằng lệnh:
```powershell
aws sts get-caller-identity
```

---

### Bước 2: Khởi tạo và triển khai hạ tầng với Terraform

> [!WARNING]
> **Lưu ý lỗi `SubscriptionRequiredException`**:
> Nếu bạn gặp lỗi `api error SubscriptionRequiredException: The AWS Access Key Id needs a subscription for the service` khi kích hoạt `aws_macie2_account.macie`, điều này có nghĩa là tài khoản AWS của bạn chưa kích hoạt dịch vụ Amazon Macie, hoặc tài khoản dạng Sandbox (như AWS Academy Learner Lab) bị hạn chế dịch vụ này.
> **Cách xử lý**:
> 1. Đăng nhập vào **AWS Management Console** bằng tài khoản `ductran` (ID `783459135560`).
> 2. Tìm dịch vụ **Amazon Macie** trên ô tìm kiếm.
> 3. Click nút **Get Started** và bấm **Enable Macie** để kích hoạt dịch vụ thủ công trên Console trước.
> 4. Nếu AWS Console cho phép kích hoạt thành công, hãy chạy lại lệnh `terraform apply`.
> 5. Nếu AWS Console báo không có quyền hoặc dịch vụ bị chặn (do chính sách của tài khoản Lab), bạn cần sử dụng một tài khoản AWS cá nhân chuẩn để thực hiện bài Lab này.

Mở Powershell/Terminal tại thư mục `d:\uni\xbrain\phase_2\w10\fri-lab` và thực hiện các lệnh sau:

1. **Khởi tạo Terraform**:
   ```powershell
   terraform init
   ```

2. **Triển khai hạ tầng**:
   ```powershell
   terraform apply
   ```
   *Nhập `yes` khi hệ thống yêu cầu xác nhận. (Hạ tầng đã được cấu hình mặc định gửi cảnh báo về email `rondepzai9@gmail.com`)*

---

### Bước 3: Xác nhận Email Subscription (RẤT QUAN TRỌNG)
1. Sau khi `terraform apply` hoàn thành, hãy mở hộp thư email bạn đã nhập ở trên.
2. Tìm thư từ **AWS Notifications** với tiêu đề **AWS Notification - Subscription Confirmation**.
3. Bấm vào link **Confirm subscription** trong email. 
4. Trình duyệt hiển thị trang thông báo **Subscription confirmed!** là thành công. Nếu không xác nhận bước này, bạn sẽ không nhận được cảnh báo về email.

---

### Bước 4: Đợi Amazon Macie hoàn thành quét và kiểm tra kết quả

1. **Quét dữ liệu**: 
   Terraform đã tạo sẵn một Classification Job trên Macie để quét S3 bucket của bạn. Tiến trình này thường diễn ra từ 5 - 15 phút.
   Bạn có thể vào AWS Console: **Amazon Macie** -> **Jobs** để theo dõi trạng thái job (Status: `Complete`).

2. **Chụp hình yêu cầu 1: Phát hiện nhạy cảm trong Macie (Detect in Macie)**
   - Truy cập **Amazon Macie** Console -> **Findings**.
   - Bạn sẽ thấy các Finding xuất hiện tương tự như: `SensitiveData:S3Object/Personal` hoặc `SensitiveData:S3Object/Financial`.
   - Bấm vào chi tiết Finding để thấy các thông tin như Số thẻ tín dụng (Credit Card), SSN bị phát hiện trong file `sensitive_data.txt`.
   - **Chụp ảnh màn hình này** (Đây là hình số 1 yêu cầu).

3. **Chụp hình yêu cầu 2: Cảnh báo gửi về Mail (Email Notification)**
   - Khi Macie tạo Finding, EventBridge sẽ kích hoạt rule gửi cảnh báo qua SNS đến Email của bạn.
   - Kiểm tra hộp thư Email của bạn, bạn sẽ nhận được một Email chứa định dạng JSON chi tiết về Finding từ Macie (bao gồm Account ID, S3 Bucket name, loại dữ liệu nhạy cảm phát hiện...).
   - **Chụp ảnh màn hình Email này** (Đây là hình số 2 yêu cầu).

---

## Dọn dẹp tài nguyên (Hủy sau khi hoàn thành)
Để tránh phát sinh chi phí AWS, sau khi đã có được 2 hình chụp màn hình, hãy chạy lệnh sau để hủy toàn bộ tài nguyên:
   ```powershell
   terraform destroy
   ```
   *Nhập `yes` để xác nhận xóa.*
