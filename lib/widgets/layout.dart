import 'package:flutter/material.dart';

// --------------------------------------------------------------------------
// NHÓM BỐ CỤC & KHOẢNG CÁCH (LAYOUT & SPACING)
// --------------------------------------------------------------------------

/// Tạo khoảng cách lề bên ngoài cho Widget con.
/// [all]: Nếu truyền [all], các phía khác sẽ bị bỏ qua và lấy giá trị này.
/// [top, bottom, left, right]: Khoảng cách cụ thể cho từng phía.
Widget padding({
  required Widget child,
  double? top,
  double? bottom,
  double? left,
  double? right,
  double? all,
}) {
  return Padding(
    padding: EdgeInsets.only(
      top: all ?? top ?? 0,
      bottom: all ?? bottom ?? 0,
      left: all ?? left ?? 0,
      right: all ?? right ?? 0,
    ),
    child: child,
  );
}

/// Căn vị trí của Widget con trong không gian của cha.
/// Các vị trí phổ biến: center, topLeft, bottomRight, topCenter...
Widget align({
  required Widget child,
  Alignment alignment = Alignment.center,
}) {
  return Align(
    alignment: alignment,
    child: child,
  );
}

/// Định vị Widget con theo tọa độ chính xác (Chỉ dùng bên trong Stack).
Widget positioned({
  required Widget child,
  double? top,
  double? bottom,
  double? left,
  double? right,
}) {
  return Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: child,
  );
}

/// Ép Widget con chiếm không gian theo tỉ lệ (Chỉ dùng trong Row hoặc Column).
/// [flex]: Tỉ lệ chiếm chỗ so với các widget khác (mặc định là 1).
/// [fit]: Cách widget lấp đầy không gian (loose hoặc tight).
Widget flexible({
  required Widget child,
  int flex = 1,
  FlexFit fit = FlexFit.loose,
}) {
  return Flexible(
    flex: flex,
    fit: fit,
    child: child,
  );
}

/// Sắp xếp các Widget con theo hàng ngang.
/// [mainAxisAlignment]: Căn chỉnh theo chiều ngang (thường dùng Start hoặc Center).
/// [crossAxisAlignment]: Căn chỉnh các widget theo chiều dọc trong hàng.
Widget row({
  required List<Widget> children, 
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start, // Đổi sang Start cho tự nhiên
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  MainAxisSize mainAxisSize = MainAxisSize.max,
}) {
  return Row(
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    mainAxisSize: mainAxisSize,
    children: children,
  );
}

/// Sắp xếp các Widget con theo hàng dọc.
/// [mainAxisAlignment]: Căn chỉnh các widget theo chiều dọc.
/// [crossAxisAlignment]: Căn chỉnh các widget theo chiều ngang trong cột.
Widget column({
  required List<Widget> children,
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  MainAxisSize mainAxisSize = MainAxisSize.max,
}) {
  return Column(
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    mainAxisSize: mainAxisSize,
    children: children,
  );
}

/// Tự động xuống dòng khi các widget con không đủ chỗ chứa trên một hàng.
/// [spacing]: Khoảng cách giữa các widget trên cùng 1 hàng.
/// [runSpacing]: Khoảng cách giữa các hàng với nhau.
Widget wrap({
  required List<Widget> children,
  Axis direction = Axis.horizontal,
  double spacing = 0,
  double runSpacing = 0,
  WrapAlignment alignment = WrapAlignment.start,
}) {
  return Wrap(
    direction: direction,
    spacing: spacing,
    runSpacing: runSpacing,
    alignment: alignment,
    children: children,
  );
}

/// Xếp chồng các Widget lên nhau (theo trục Z - từ dưới lên trên).
Widget stack({
  required List<Widget> children,
  Alignment alignment = Alignment.topLeft,
  StackFit fit = StackFit.loose,
}) {
  return Stack(
    alignment: alignment,
    fit: fit,
    children: children,
  );
}

/// Tạo khoảng cách trống theo chiều ngang (SizedBox width).
Widget gapW(double width) => SizedBox(width: width);

/// Tạo khoảng cách trống theo chiều dọc (SizedBox height).
Widget gapH(double height) => SizedBox(height: height);

/// Tạo một khung chứa với kích thước cố định.
Widget box({
  Widget? child,
  double? width,
  double? height,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: child,
  );
}