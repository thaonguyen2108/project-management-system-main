import 'package:flutter/material.dart';

// --------------------------------------------------------------------------
// NHÓM THÔNG BÁO & PHẢN HỒI (FEEDBACK & DIALOGS)
// --------------------------------------------------------------------------

/// Hiển thị thông báo nhanh (SnackBar) ở dưới cùng màn hình.
/// [message]: Nội dung thông báo.
/// [duration]: Thời gian hiển thị (mặc định 2 giây).
/// [backgroundColor]: Màu nền của thanh thông báo.
void snack(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
  Color? backgroundColor,
  Color textColor = Colors.white,
}) {
  // Xóa SnackBar cũ đang hiển thị (nếu có) để hiện cái mới ngay lập tức
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message, 
        style: TextStyle(color: textColor),
      ),
      duration: duration,
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating, // Hiển thị dạng nổi nhìn sẽ hiện đại hơn
    ),
  );
}

/// Hiển thị hộp thoại xác nhận (AlertDialog).
/// [title]: Tiêu đề hộp thoại.
/// [message]: Nội dung chi tiết.
/// [onOk]: Hàm thực hiện khi nhấn nút Đồng ý.
/// [okText] & [cancelText]: Nhãn của các nút bấm.
Future<void> dialog(
  BuildContext context, {
  required String title,
  required String message,
  String okText = "OK",
  String cancelText = "Hủy",
  VoidCallback? onOk,
  Color? okColor,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          // Nút Hủy: Chỉ đóng hộp thoại
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelText, style: const TextStyle(color: Colors.grey)),
          ),
          // Nút Đồng ý: Đóng hộp thoại và thực hiện hành động
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: Text(
              okText, 
              style: TextStyle(color: okColor ?? Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}

/// Hiển thị vòng tròn xoay (Loading) khi đang tải dữ liệu.
/// [size]: Kích thước của vòng xoay.
/// [strokeWidth]: Độ dày của đường xoay.
Widget loading({
  double size = 24,
  Color? color,
  double strokeWidth = 3,
}) {
  return Center( // Bọc trong Center để luôn nằm giữa khung chứa
    child: SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: color != null ? AlwaysStoppedAnimation<Color>(color) : null,
      ),
    ),
  );
}