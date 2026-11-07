# VietType cho macOS

Bộ gõ tiếng Việt hỗ trợ Telex và VNI, dành cho macOS 13 trở lên trên Apple Silicon và Intel.

Repo này chứa các bản phân phối, script cài đặt và hướng dẫn sử dụng. Mã nguồn ứng dụng được quản lý riêng.

## Cài đặt

Mở Terminal và chạy bằng tài khoản người dùng, không thêm `sudo`:

```sh
curl -fsSL https://itsdothugo.github.io/viettype/install.sh | bash
```

Script tải file `VietType-<version>.app.zip` từ [GitHub Releases](https://github.com/itsdothugo/viettype-releases/releases),
kiểm tra phiên bản, chữ ký Developer ID và Gatekeeper, rồi cài vào
`~/Library/Input Methods/VietType.app`. Sau đó ứng dụng mở để hỏi quyền còn thiếu.
Nếu VietType đang được Homebrew quản lý, script cập nhật qua Homebrew.

Có thể [xem script](install.sh) hoặc xem trước các bước mà không cài ứng dụng:

```sh
curl -fsSL https://itsdothugo.github.io/viettype/install.sh | bash -s -- --dry-run
```

Nếu muốn tải script trực tiếp từ repo public này:

```sh
curl -fsSL https://raw.githubusercontent.com/itsdothugo/viettype-releases/main/install.sh | bash
```

Lệnh cài cần một bản release public có file ZIP tương ứng. Nếu chưa có release, bạn vẫn có thể chạy `--dry-run`.

## Bật bộ gõ

1. Mở **System Settings → Keyboard → Input Sources → Edit… → ＋**.
2. Chọn **Vietnamese → VietType → Add**.
3. Chuyển sang VietType bằng menu bộ gõ, phím 🌐 hoặc ⌃Space.
4. Bật quyền cho VietType trong **Privacy & Security → Accessibility**. Trên macOS 27,
   mục này có tên **Device Control and Data Access**.

Nếu chưa thấy VietType trong danh sách nguồn nhập, đăng xuất rồi đăng nhập lại và thử thêm lần nữa.

## Cài thủ công

Tải ZIP trong [Releases](https://github.com/itsdothugo/viettype-releases/releases), giải nén,
chép `VietType.app` vào `~/Library/Input Methods`, rồi mở ứng dụng để cấp quyền.
Khi thay bản cũ, chuyển sang ABC và thoát VietType trước khi chép app mới.

## Cập nhật

Chạy lại lệnh cài đặt hoặc mở **VietType → Cài đặt… → Chung → Kiểm tra cập nhật**.

## Báo lỗi

Gửi [issue](https://github.com/itsdothugo/viettype-releases/issues) kèm phiên bản macOS,
phiên bản VietType, tên ứng dụng bị lỗi, chuỗi phím đã gõ và kết quả mong đợi.
