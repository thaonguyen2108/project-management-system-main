import 'package:flutter/material.dart';

// --------------------------------------------------------------------------
// NHÓM DANH SÁCH & CUỘN (LISTS & SCROLLING)
// --------------------------------------------------------------------------

/// Danh sách cuộn cơ bản (ListView).
/// Dùng khi số lượng phần tử ít và đã biết trước.
/// [shrinkWrap]: Đặt thành true nếu danh sách nằm trong một Column.
Widget list({
  required List<Widget> children,
  Axis direction = Axis.vertical,
  EdgeInsets padding = EdgeInsets.zero,
  bool shrinkWrap = false,
  ScrollPhysics? physics,
}) {
  return ListView(
    scrollDirection: direction,
    padding: padding,
    shrinkWrap: shrinkWrap,
    physics: physics, // Ví dụ: BouncingScrollPhysics() cho iOS style
    children: children,
  );
}

/// Danh sách cuộn tối ưu cho số lượng lớn (ListView.builder).
/// Chỉ vẽ các phần tử đang hiện trên màn hình (đỡ tốn RAM).
/// [itemBuilder]: Hàm tạo giao diện cho từng phần tử dựa trên index.
Widget listBuilder({
  required int itemCount,
  required Widget Function(BuildContext, int) itemBuilder,
  Axis direction = Axis.vertical,
  EdgeInsets padding = EdgeInsets.zero,
  bool shrinkWrap = false,
}) {
  return ListView.builder(
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    scrollDirection: direction,
    padding: padding,
    shrinkWrap: shrinkWrap,
  );
}

/// Hiển thị danh sách dạng lưới (GridView).
/// [columns]: Số cột hiển thị (mặc định là 2).
/// [spacing]: Khoảng cách giữa các cột.
/// [runSpacing]: Khoảng cách giữa các hàng.
/// [ratio]: Tỉ lệ khung hình của ô (Chiều rộng / Chiều cao).
Widget grid({
  required List<Widget> children,
  int columns = 2,
  double spacing = 8,
  double runSpacing = 8,
  double ratio = 1,
  bool shrinkWrap = false,
}) {
  return GridView.count(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: runSpacing,
    childAspectRatio: ratio,
    shrinkWrap: shrinkWrap,
    children: children,
  );
}

/// Một dòng chuẩn trong danh sách (ListTile).
/// Rất hợp để làm dòng Task: [leading] là Checkbox, [title] là tên Task.
Widget tile({
  Widget? leading, //Bên trái
  required String title, //Giữa trên
  String? subtitle, // Giữa dưới
  Widget? trailing, //Bên phải
  VoidCallback? onTap,
  Color? tileColor,
  EdgeInsetsGeometry? contentPadding,
}) {
  return ListTile(
    leading: leading,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: subtitle != null ? Text(subtitle) : null,
    trailing: trailing,
    onTap: onTap,
    tileColor: tileColor,
    contentPadding: contentPadding,
  );
}

/// Cho phép một Widget đơn lẻ có thể cuộn được (SingleChildScrollView).
/// Thường bọc ngoài [Column] khi nội dung dài quá màn hình.
Widget scroll({
  required Widget child,
  Axis direction = Axis.vertical,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return SingleChildScrollView(
    scrollDirection: direction,
    padding: padding,
    child: child,
  );
}