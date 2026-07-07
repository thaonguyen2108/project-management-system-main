# 📝 Ứng dụng ToDo & Quản lý Dự án Thông minh (Tích hợp Gemini AI)

[![Flutter](https://img.shields.io/badge/Flutter-v3.10.7-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Core%20%7C%20Firestore%20%7C%20Auth%20%7C%20FCM-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/Gemini%20AI-2.5--flash-9E7EC8?logo=google-gemini&logoColor=white)](https://deepmind.google/technologies/gemini/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)](#)

Một ứng dụng quản lý công việc và dự án toàn diện được phát triển bằng **Flutter** và hệ sinh thái **Firebase**, nổi bật với khả năng tương tác với **Trợ lý ảo Gemini AI** giúp tự động hóa việc lên kế hoạch, phân rã công việc trực quan, cùng các tính năng tương tác xã hội (Chat & Kết bạn) và biểu đồ thống kê tiến độ chuyên nghiệp.

---

## 🚀 Tính năng nổi bật

### 1. 🗂️ Quản lý Dự án & Công việc Chuyên sâu
*   **Dự án cá nhân & Nhóm:** Tạo, cập nhật, lưu trữ (archive) dự án linh hoạt với mã màu nhận diện riêng.
*   **Task Dependencies (Mối quan hệ phụ thuộc):** Hỗ trợ thiết lập các công việc phụ thuộc lẫn nhau (`dependsOnTaskID`), giúp kiểm soát thứ tự thực hiện nhiệm vụ hiệu quả.
*   **Trạng thái & Mức độ ưu tiên:** Phân loại công việc trực quan (`todo`, `doing`, `done`, `later`) kết hợp 3 cấp độ ưu tiên (Thấp, Trung bình, Cao).
*   **Lọc & Sắp xếp:** Bộ lọc thông minh theo trạng thái hoạt động/lưu trữ kết hợp sắp xếp theo thời gian tạo, hạn chót (deadline), bảng chữ cái hoặc độ khẩn cấp.

### 2. 🤖 Trợ lý AI Gemini Thông minh (Gemini 2.5 Flash)
*   **Lập kế hoạch bằng ngôn ngữ tự nhiên:** Trò chuyện trực tiếp với AI để mô tả nhu cầu dự án (Ví dụ: *"Lập kế hoạch chuẩn bị đám cưới"*, *"Xây dựng kế hoạch ra mắt sản phẩm"*).
*   **Phân tách công việc tự động:** AI phân tích và phản hồi cấu trúc dự án gồm tên, mô tả chi tiết, hạn định tổng quan và phân rã từ **3 đến 8 công việc con** có ngày bắt đầu (offsetDays) và độ ưu tiên hợp lý.
*   **Xem trước & Tạo nhanh:** Người dùng có thể xem trước bản phác thảo do AI đề xuất và lưu trực tiếp vào Firestore chỉ với 1 chạm thông qua biểu mẫu chỉnh sửa trực quan.

### 3. 💬 Cộng tác Nhóm & Nhắn tin Thời gian thực
*   **Hệ thống kết bạn:** Gửi, nhận, từ chối lời mời kết bạn và quản lý danh sách bạn bè trực quan.
*   **Chat cá nhân & Nhóm:** Phòng trò chuyện real-time đồng bộ tức thì qua Firestore, tích hợp hiển thị trạng thái chưa đọc (unread count) cho từng cuộc hội thoại.

### 4. 🔔 Thông báo đẩy thời gian thực (Push Notifications)
*   **Firebase Cloud Messaging (FCM):** Tự động gửi thông báo đẩy đến thiết bị khi có tin nhắn mới, cập nhật trạng thái công việc hoặc lời mời kết bạn.
*   **Background Handler:** Xử lý và hiển thị thông báo ngay cả khi ứng dụng đang chạy nền hoặc đã đóng.

### 5. 📊 Biểu đồ Thống kê Trực quan
*   **Báo cáo tiến độ trực quan:** Tích hợp `syncfusion_flutter_charts` để hiển thị biểu đồ tròn biểu thị tỷ lệ hoàn thành công việc và biểu đồ cột tiến độ dự án, giúp nhà quản lý có cái nhìn tổng quan tức thì.

### 6. 🎨 Trải nghiệm Người dùng Tối ưu
*   **Chế độ Sáng/Tối (Light & Dark Mode):** Giao diện thiết kế theo ngôn ngữ Material 3 hiện đại, dễ dàng chuyển đổi tự động hoặc thủ công.
*   **Splash Screen & Icon:** Màn hình chào sắc nét cùng icon ứng dụng đồng bộ trên cả nền tảng Android.

---

## 🛠️ Công nghệ & Thư viện sử dụng

| Lớp (Layer) | Công nghệ / Thư viện | Mô tả |
| :--- | :--- | :--- |
| **Frontend Framework** | `Flutter (SDK ^3.10.7)` | Phát triển ứng dụng đa nền tảng |
| **Database & Realtime** | `Cloud Firestore` | Lưu trữ dữ liệu dự án, công việc, bạn bè, tin nhắn thời gian thực |
| **Authentication** | `Firebase Auth & Google Sign-In` | Xác thực người dùng bảo mật |
| **Serverless Logic** | `Firebase Cloud Functions (NodeJS v2)` | Xử lý logic nghiệp vụ và tích hợp Gemini API phía server |
| **AI Integration** | `Google Gemini API` (`gemini-2.5-flash`) | Phân tích prompt và sinh cấu trúc dự án dưới dạng JSON |
| **Push Notifications** | `Firebase Messaging` & `flutter_local_notifications` | Xử lý thông báo đẩy đa nền tảng |
| **Charts & Visuals** | `syncfusion_flutter_charts` | Vẽ biểu đồ thống kê tiến độ |
| **Local Storage** | `shared_preferences` | Lưu trữ cấu hình theme và trạng thái giao diện của người dùng |

---

## 📂 Cấu trúc thư mục mã nguồn (lib/)

Dự án được tổ chức theo kiến trúc phân lớp sạch sẽ (Clean-like Architecture) giúp tách biệt rõ ràng giữa Giao diện (UI), Nghiệp vụ (Controllers), và Dịch vụ (Services):

```text
lib/
├── core/                  # Cấu hình hệ thống, styles, định dạng giao diện, helpers
│   ├── ai_config.dart     # Cấu hình Gemini API Key cục bộ
│   ├── app_style.dart     # Định nghĩa ThemeData (Light/Dark), màu sắc, typography
│   └── app_notification_service.dart  # Quản lý cấu hình FCM & thông báo nội bộ
├── models/                # Định nghĩa cấu trúc dữ liệu (Data models)
│   ├── project.dart       # Model Dự án
│   ├── task.dart          # Model Công việc
│   ├── user.dart          # Model Người dùng
│   ├── message.dart       # Model Tin nhắn
│   └── ai_project_draft.dart # Bản nháp kế hoạch sinh bởi AI
├── controllers/           # Điều phối luồng dữ liệu giữa UI và Services
│   ├── project_Controller.dart
│   ├── task_Controller.dart
│   └── chat_Controller.dart
├── services/              # Kết nối trực tiếp với Firebase & các API bên ngoài
│   ├── aiAssistantService.dart   # Dịch vụ gọi Gemini API trực tiếp từ Client
│   ├── chatService.dart          # Quản lý nhắn tin Firestore
│   └── userService.dart          # Quản lý thông tin người dùng Firestore
├── screens/               # Màn hình giao diện ứng dụng (UI Screens)
│   ├── authGate.dart      # Kiểm tra trạng thái đăng nhập
│   ├── scr_login.dart     # Màn hình Đăng nhập
│   ├── scr_home.dart      # Màn hình chính điều hướng (Dashboard)
│   ├── sub_screens/       # Các tab chức năng (Dự án, Công việc, Thống kê, Thông báo)
│   └── modalScreen/       # Các trang dạng BottomSheet (Trợ lý AI, Hồ sơ, Form tạo)
└── widgets/               # Các custom widgets dùng chung trong dự án
```

---

## ⚙️ Hướng dẫn cấu hình & Chạy ứng dụng

### 1. Chuẩn bị môi trường
*   Cài đặt **Flutter SDK** (khuyên dùng bản `3.10.7` trở lên phù hợp với SDK quy định trong `pubspec.yaml`).
*   Tài khoản **Firebase Console** và cài đặt sẵn **Firebase CLI** trên máy tính.
*   Cài đặt **Node.js** nếu muốn chạy/triển khai Firebase Cloud Functions.

### 2. Cấu hình Firebase cho dự án Flutter
1.  Tạo một project mới trên [Firebase Console](https://console.firebase.google.com/).
2.  Bật các dịch vụ: **Authentication** (Email/Password & Google), **Cloud Firestore**, và **Cloud Functions**.
3.  Tải tệp cấu hình `google-services.json` đặt vào thư mục `android/app/`.
4.  Khởi tạo cấu hình Firebase trong Flutter:
    ```bash
    flutterfire configure
    ```

### 3. Cấu hình Gemini API Key
Ứng dụng hỗ trợ cấu hình API Key linh hoạt bằng một trong hai cách:

*   **Cách 1: Chạy trực tiếp từ Client (Thông qua `--dart-define`)**
    Chạy lệnh hoặc cấu hình IDE chạy ứng dụng kèm cờ cấu hình môi trường:
    ```bash
    flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY_HERE
    ```
*   **Cách 2: Chạy qua Firebase Cloud Functions**
    Lưu khoá API của bạn trong cấu hình biến môi trường của Firebase Cloud Functions (`functions/.env`):
    ```env
    GEMINI_API_KEY=YOUR_GEMINI_API_KEY_HERE
    ```

### 4. Triển khai Firebase Cloud Functions (Nếu sử dụng dịch vụ AI phía Server)
1.  Truy cập thư mục `functions`:
    ```bash
    cd functions
    ```
2.  Cài đặt các gói phụ thuộc:
    ```bash
    npm install
    ```
3.  Triển khai các hàm lên Firebase:
    ```bash
    firebase deploy --only functions
    ```

---
