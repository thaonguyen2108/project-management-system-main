import 'package:flutter/material.dart';

// --------------------------------------------------------------------------
// NHÓM CẤU TRÚC MÀN HÌNH (SCAFFOLD & NAVIGATION)
// --------------------------------------------------------------------------

/// Khung sườn của một màn hình.
/// [appBar]: Thanh tiêu đề phía trên.
/// [fab]: Nút tròn lơ lửng (Floating Action Button).
/// [bottomNav]: Thanh menu dưới cùng.
/// [drawer]: Menu vuốt từ cạnh trái.
Widget screen({
  required Widget body,
  PreferredSizeWidget? appBar,
  Widget? drawer,
  Widget? bottomNav,
  Widget? fab,
  FloatingActionButtonLocation? fabLocation,
  Color? backgroundColor,
  bool safeArea = true,
  bool? resizeToAvoidBottomInset,
}) {
  return Scaffold(
    appBar: appBar,
    drawer: drawer,
    body: safeArea ? SafeArea(child: body) : body,
    bottomNavigationBar: bottomNav,
    floatingActionButton: fab,
    floatingActionButtonLocation: fabLocation,
    backgroundColor: backgroundColor,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
  );
}

/// Thanh tiêu đề phía trên cùng của màn hình.
/// [actions]: Danh sách các nút bên phải (ví dụ: nút Tìm kiếm, Cài đặt).
/// [leading]: Widget nằm bên trái cùng (thường là nút Back hoặc Menu).
PreferredSizeWidget appBar({
  required String title,
  List<Widget>? actions,
  Widget? leading,
  bool centerTitle = false,
  Color? backgroundColor,
  Color? foregroundColor,
  double elevation = 2.0, // Thêm độ đổ bóng
  Color? shadowColor,
  double borderRadius = 20.0, // Thêm bo góc dưới
  PreferredSizeWidget? bottom, // Để gắn TabBar sau này
}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
    ),
    actions: actions,
    leading: leading,
    centerTitle: centerTitle,
    backgroundColor:
        backgroundColor ??
        const Color.fromARGB(255, 255, 255, 255), // Màu mặc định của ông
    foregroundColor: foregroundColor ?? const Color.fromARGB(255, 0, 0, 0),
    elevation: elevation,

    // Đổ bóng mờ mờ cho sang
    shadowColor: shadowColor,

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(borderRadius),
      ),
    ),

    // bottom: bottom,
  );
}

/// Thanh điều hướng dưới cùng (Menu chính của App).
/// [currentIndex]: Vị trí tab đang được chọn (0, 1, 2...).
/// [items]: Danh sách các BottomNavigationBarItem (Icon + Label).
Widget bottomNav({
  required int currentIndex,
  required List<BottomNavigationBarItem> items,
  required ValueChanged<int> onTap,
  Color? selectedColor,
  Color? backgroundColor,
}) {
  return BottomNavigationBar(
    currentIndex: currentIndex,
    items: items,
    onTap: onTap,
    selectedItemColor: selectedColor,
    backgroundColor: backgroundColor,
    type: BottomNavigationBarType
        .fixed, // Giúp menu không bị giật khi có > 3 item
  );
}

/// Nút bấm tròn lơ lửng (Floating Action Button).
/// Thường dùng cho các hành động quan trọng nhất như "Thêm mới".
Widget fab({
  required IconData icon,
  required VoidCallback onPressed,
  String? tooltip,
  Color? backgroundColor,
}) {
  return FloatingActionButton(
    onPressed: onPressed,
    tooltip: tooltip,
    backgroundColor: backgroundColor,
    child: Icon(icon),
  );
}

/// Menu vuốt từ bên trái (Drawer).
Widget drawerMenu({
  required List<Widget> children,
  Widget? header, // Thường dùng để hiện thông tin User ở đầu Drawer
}) {
  return Drawer(
    child: ListView(padding: EdgeInsets.zero, children: [?header, ...children]),
  );
}

// --------------------------------------------------------------------------
// NHÓM TAB BAR (CHUYỂN TAB TRONG TRANG)
// --------------------------------------------------------------------------

/// Thanh chọn Tab (Thường nằm dưới AppBar hoặc trong Body).
/// LƯU Ý: Widget cha của cái này PHẢI là DefaultTabController.
PreferredSizeWidget tabBar({
  required List<Tab> tabs,
  Color? labelColor,
  Color? unselectedLabelColor,
}) {
  return TabBar(
    tabs: tabs,
    labelColor: labelColor,
    unselectedLabelColor: unselectedLabelColor,
    indicatorSize: TabBarIndicatorSize.tab,
  );
}

/// Nội dung hiển thị tương ứng của các Tab.
Widget tabView({required List<Widget> children}) {
  return TabBarView(children: children);
}
