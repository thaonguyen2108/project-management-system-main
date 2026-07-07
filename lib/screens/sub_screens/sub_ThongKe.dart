import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/core/pref_halper.dart';
import 'package:todo/screens/sub_screens/sub_ThongKe/ThongKe_CongViec.dart';
import 'package:todo/screens/sub_screens/sub_ThongKe/ThongKe_DuAn.dart';
import 'package:todo/widgets/ui.dart';

class Sub_ThongKe_Screen extends StatefulWidget {
  const Sub_ThongKe_Screen({super.key});

  @override
  State<Sub_ThongKe_Screen> createState() => _Sub_ThongKe_ScreenState();
}

class _Sub_ThongKe_ScreenState extends State<Sub_ThongKe_Screen> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final savedTab = PrefHelper.getUiPreference(uid, 'stats_tab', 'project');
    selectedIndex = savedTab == 'task' ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return screen(
      backgroundColor: colors.surface,
      body: stack(
        children: [
          padding(
            top: 12,
            left: 12,
            right: 12,
            child: column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text(
                  "Thống kê & Báo cáo",
                  weight: FontWeight.bold,
                  size: 20,
                  color: colors.onSurface,
                  align: TextAlign.left,
                ),
                text(
                  "Theo dõi tiến độ và hiệu suất",
                  size: 13,
                  color: colors.onSurfaceVariant,
                  align: TextAlign.left,
                ),
                box(height: 16),
                _SegmentedTabs(
                  selectedIndex: selectedIndex,
                  onChanged: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                    PrefHelper.setUiPreference(
                      FirebaseAuth.instance.currentUser?.uid,
                      'stats_tab',
                      index == 1 ? 'task' : 'project',
                    );
                  },
                ),
                box(height: 12),
                flexible(
                  child: Builder(
                    builder: (context) {
                      if (selectedIndex == 0) {
                        return const ThongKe_DuAn_Screen();
                      }

                      if (selectedIndex == 1) {
                        return const ThongKe_CongViec_Screen();
                      }

                      return const Center(child: Text("Chưa hỗ trợ"));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          _tabButton(label: "Dự án", index: 0),
          _tabButton(label: "Công việc", index: 1),
        ],
      ),
    );
  }

  Widget _tabButton({required String label, required int index}) {
    final selected = selectedIndex == index;
    return Expanded(
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;

          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
