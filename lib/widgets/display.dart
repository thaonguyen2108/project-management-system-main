import 'package:flutter/material.dart';

// --------------------------------------------------------------------------
// NHÓM HIỂN THỊ NỘI DUNG (DISPLAY WIDGETS)
// --------------------------------------------------------------------------

/// Hiển thị văn bản với các tùy chỉnh nhanh về kiểu dáng.
/// [size]: Kích thước chữ.
/// [weight]: Độ đậm nhạt (FontWeight.bold, .w500...).
/// [align]: Căn lề trái, phải, giữa.
/// [maxLines]: Số dòng tối đa trước khi bị cắt bớt.
/// [height]: Khoảng cách giữa các dòng (Line height).
Widget text(
  String data, {
  double size = 14,
  FontWeight weight = FontWeight.normal,
  Color? color,
  TextAlign align = TextAlign.start,
  int? maxLines,
  TextOverflow overflow =
      TextOverflow.ellipsis, // Đổi mặc định thành ellipsis (dấu ...) cho đẹp
  double? height,
  double? letterSpacing,
  FontStyle fontStyle = FontStyle.normal,
}) {
  return Builder(
    builder: (context) {
      final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;

      return Text(
        data,
        textAlign: align,
        maxLines: maxLines,
        overflow: overflow,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: effectiveColor,
          height: height,
          letterSpacing: letterSpacing,
          fontStyle: fontStyle,
        ),
      );
    },
  );
}

/// Hiển thị hình ảnh từ Network hoặc Assets và hỗ trợ bo góc.
/// [src]: Đường dẫn ảnh (bắt đầu bằng 'http' sẽ tự hiểu là ảnh mạng).
/// [fit]: Cách ảnh lấp đầy khung (Cover, Contain...).
/// [radius]: Dùng BorderRadius.circular(số) để bo tròn góc ảnh.
Widget image(
  String src, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius? radius,
}) {
  // Tự động kiểm tra nguồn ảnh
  Widget img = src.startsWith('http')
      ? Image.network(src, width: width, height: height, fit: fit)
      : Image.asset(src, width: width, height: height, fit: fit);

  // Nếu có truyền radius thì bọc trong ClipRRect để bo góc
  if (radius != null) {
    return ClipRRect(borderRadius: radius, child: img);
  }
  return img;
}

/// Hiển thị Icon từ bộ Material Icons.
/// [iconData]: Tên icon (Icons.home, Icons.person...).
Widget icon(IconData iconData, {double size = 24, Color? color}) {
  return Icon(iconData, size: size, color: color);
}

/// Hiển thị ảnh đại diện hình tròn.
/// [imageUrl]: Link ảnh mạng.
/// [child]: Nếu không có ảnh, có thể hiện chữ cái đầu hoặc Icon thay thế.
Widget avatar({
  String? imageUrl,
  double radius = 20,
  Widget? child,
  Color? backgroundColor,
}) {
  final safeUrl = imageUrl?.trim();

  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    backgroundImage: safeUrl != null && safeUrl.isNotEmpty
        ? NetworkImage(safeUrl)
        : null,
    child: safeUrl == null || safeUrl.isEmpty ? child : null,
  );
}

/// Gắn một nhãn thông báo (số lượng, tin nhắn mới) lên trên một Widget khác.
/// [label]: Nội dung hiện trong badge (ví dụ: "1", "New").
/// [color]: Màu nền của badge (mặc định màu đỏ).
Widget badge({
  required Widget child,
  String? label,
  Color color = Colors.red,
  double size = 18,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
}) {
  if (label == null || label.isEmpty) return child;

  return Stack(
    clipBehavior: Clip.none, // Để badge có thể nằm chờm ra ngoài khung
    children: [
      child,
      Positioned(
        right: -4,
        top: -4,
        child: Container(
          padding: padding,
          constraints: BoxConstraints(minWidth: size, minHeight: size),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Đường kẻ ngang (Horizontal Divider).
Widget hDivider({
  double height = 16,
  double thickness = 1,
  Color? color,
  double indent = 0,
  double endIndent = 0,
}) {
  return Divider(
    height: height,
    thickness: thickness,
    color: color,
    indent: indent,
    endIndent: endIndent,
  );
}

/// Đường kẻ dọc (Vertical Divider).
/// LƯU Ý: Phải đặt trong một Widget có chiều cao xác định (ví dụ: SizedBox hoặc Row cao).
Widget vDivider({
  double width = 16,
  double thickness = 1,
  Color? color,
  double indent = 0,
  double endIndent = 0,
}) {
  return VerticalDivider(
    width: width,
    thickness: thickness,
    color: color,
    indent: indent,
    endIndent: endIndent,
  );
}

Widget progressBar({
  required double value,
  Color backgroundColor = Colors.grey, // Màu nền của thanh
  Color valueColor = Colors.blue, //màu tiến độ
  double minHeight = 8,
  BorderRadius? borderRadius, // Bo tròn
}) {
  return LinearProgressIndicator(
    value: value, // Giá trị từ 0.0 đến 1.0 (0.7 tương ứng với 70%)
    backgroundColor: backgroundColor, // Màu nền của thanh
    valueColor: AlwaysStoppedAnimation<Color>(valueColor), // Màu của tiến độ
    minHeight: minHeight, // Độ dày của thanh
    borderRadius: borderRadius, // Bo tròn cho hiện đại
  );
}
