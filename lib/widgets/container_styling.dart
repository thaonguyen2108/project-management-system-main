import 'package:flutter/material.dart';

// --------------------------------------------------------------------------
// NHÓM KHUNG CHỨA & TRANG TRÍ (CONTAINER & STYLING)
// --------------------------------------------------------------------------

/// Widget vạn năng dùng để tạo khung, đổ màu, bo góc và tạo bóng.
/// [radius]: Dùng BorderRadius.circular(số) để bo góc.
/// [shadow]: Danh sách các hiệu ứng đổ bóng (BoxShadow).
/// [border]: Viền của khung (Border.all).
import 'dart:ui'; // BẮT BUỘC phải có dòng này để dùng ImageFilter

Widget containerBox({
  Widget? child,
  double? width,
  double? height,
  Color? color,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets margin = EdgeInsets.zero,
  BorderRadius? radius,
  Border? border,
  List<BoxShadow>? shadow,
  double? blur, 
  Alignment? alignment,
  BoxConstraints? constraints,
}) {
  // 1. Tạo cái nội dung chính trước
  Widget current = Container(
    width: width,
    height: height,
    padding: padding,
    margin: margin,
    alignment: alignment,
    constraints: constraints,
    decoration: BoxDecoration(
      color: color,
      borderRadius: radius,
      border: border,
      boxShadow: shadow,
    ),
    child: child,
  );

  // 2. Nếu Đạt có truyền chỉ số blur, mình bọc thêm hiệu ứng mờ
  if (blur != null && blur > 0) {
    current = ClipRRect(
      borderRadius: radius ?? BorderRadius.zero, // Bo góc cho vết mờ không bị tràn
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: current,
      ),
    );
  }

  return current;
}



/// Tạo một khung hình chữ nhật có hiệu ứng đổ bóng và bo góc mặc định.
/// Thường dùng để làm các item trong danh sách cho nổi bật.
/// [elevation]: Độ cao của bóng đổ (càng lớn bóng càng đậm).
Widget card({
  required Widget child,
  double elevation = 2,
  EdgeInsets margin = const EdgeInsets.all(5),
  BorderRadius radius = const BorderRadius.all(Radius.circular(12)),
  Color? color,
}) {
  return Card(
    color: color,
    elevation: elevation,
    margin: margin,
    shape: RoundedRectangleBorder(
      borderRadius: radius,
    ),
    child: child,
  );
}

/// Làm mờ một Widget.
/// [opacity]: Độ đậm nhạt từ 0.0 (trong suốt) đến 1.0 (hiện rõ).
Widget opacityBox({
  required Widget child,
  double opacity = 1,
}) {
  return Opacity(
    opacity: opacity,
    child: child,
  );
}

/// Cắt Widget con theo một hình dạng bo góc.
/// Thường dùng để bo góc cho Hình ảnh (Image) vì Image không có thuộc tính radius.
Widget clipRRect({
  required Widget child,
  BorderRadius radius = const BorderRadius.all(Radius.circular(8)),
}) {
  return ClipRRect(
    borderRadius: radius,
    child: child,
  );
}

