import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:todo/controllers/project_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/project.dart';
import 'package:todo/widgets/ui.dart';

class ThongKe_DuAn_Screen extends StatefulWidget {
  const ThongKe_DuAn_Screen({super.key});

  @override
  State<ThongKe_DuAn_Screen> createState() => _ThongKe_DuAn_ScreenState();
}

class _ThongKe_DuAn_ScreenState extends State<ThongKe_DuAn_Screen> {
  final projectController = ProjectController();

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isOverdue(ProjectModel project) {
    if (project.isArchived) return false;
    return _dateOnly(DateTime.now()).isAfter(_dateOnly(project.deadline));
  }

  bool _isDueSoon(ProjectModel project) {
    if (project.isArchived) return false;
    final daysLeft = _dateOnly(
      project.deadline,
    ).difference(_dateOnly(DateTime.now())).inDays;
    return daysLeft >= 0 && daysLeft <= 5;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const _InlineState(
        iconData: Icons.lock_outline,
        message: "Vui lòng đăng nhập để xem thống kê dự án.",
      );
    }

    return StreamBuilder<List<ProjectModel>>(
      stream: projectController.getMyProjects(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading();
        }

        if (snapshot.hasError) {
          return const _InlineState(
            iconData: Icons.error_outline,
            message: "Không thể tải thống kê dự án.",
          );
        }

        final projects = snapshot.data ?? [];
        final total = projects.length;
        final archived = projects.where((project) => project.isArchived).length;
        final active = total - archived;
        final overdue = projects.where(_isOverdue).length;
        final dueSoon = projects.where(_isDueSoon).length;
        final archivedPercent = total == 0
            ? 0
            : (archived / total * 100).round();
        final chartData = [
          ChartData('Đang hoạt động', active.toDouble(), AppColors.primary),
          ChartData('Đã lưu trữ', archived.toDouble(), AppColors.success),
          ChartData('Quá hạn', overdue.toDouble(), AppColors.danger),
          ChartData('Sắp đến hạn', dueSoon.toDouble(), AppColors.warning),
        ];

        return scroll(
          child: column(
            children: [
              grid(
                ratio: 1.25,
                shrinkWrap: true,
                children: [
                  cardThongKe(
                    iconData: Icons.folder,
                    title: "Tổng dự án",
                    subtitle: "$total",
                    note: "$active đang hoạt động",
                    color: AppColors.primary,
                  ),
                  cardThongKe(
                    iconData: Icons.inventory_2_outlined,
                    title: "Đã lưu trữ",
                    subtitle: "$archived",
                    note: "$archivedPercent% đã lưu trữ",
                    color: AppColors.success,
                  ),
                  cardThongKe(
                    iconData: Icons.warning,
                    title: "Quá hạn",
                    subtitle: "$overdue",
                    note: "Tính theo deadline",
                    color: AppColors.danger,
                  ),
                  cardThongKe(
                    iconData: Icons.timelapse,
                    title: "Sắp đến hạn",
                    subtitle: "$dueSoon",
                    note: "Trong 5 ngày tới",
                    color: AppColors.warning,
                  ),
                ],
              ),
              box(height: 16),
              _chartCard(
                child: SfCircularChart(
                  title: ChartTitle(
                    text: 'Phân bổ dự án',
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  legend: Legend(
                    isVisible: true,
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  series: <CircularSeries>[
                    PieSeries<ChartData, String>(
                      radius: '100%',
                      dataSource: chartData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      pointColorMapper: (ChartData data, _) => data.color,
                      dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        textStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _noteCard(),
              box(height: 50),
            ],
          ),
        );
      },
    );
  }

  Widget _chartCard({required Widget child}) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(height: 220, width: double.infinity, child: child),
      ),
    );
  }

  Widget _noteCard() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: padding(
        top: 12,
        left: 15,
        right: 15,
        bottom: 12,
        child: column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text("Ghi chú", weight: FontWeight.bold, size: 18),
            box(height: 8),
            text(
              "Dự án hoàn thành được lưu trữ từ tab Dự án. Màn này chưa tính progress task để tránh đọc quá nhiều document.",
              size: 13,
              maxLines: 4,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

Widget cardThongKe({
  IconData? iconData,
  String? title,
  String? subtitle,
  String? note,
  Color? color,
}) {
  final accent = color ?? AppColors.primary;
  return Card(
    elevation: 0,
    color: accent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            children: [
              icon(iconData ?? Icons.folder, size: 17, color: Colors.white),
              box(width: 6),
              Expanded(
                child: text(
                  title ?? "",
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          box(height: 10),
          text(
            subtitle ?? "",
            size: 24,
            weight: FontWeight.bold,
            color: Colors.white,
            maxLines: 1,
          ),
          box(height: 4),
          text(
            note ?? "",
            size: 11.5,
            color: Colors.white.withValues(alpha: 0.9),
            maxLines: 2,
          ),
        ],
      ),
    ),
  );
}

class ChartData {
  ChartData(this.x, this.y, [this.color]);
  final String x;
  final double y;
  final Color? color;
}

class _InlineState extends StatelessWidget {
  final IconData iconData;
  final String message;

  const _InlineState({required this.iconData, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: colors.onSurfaceVariant),
          box(height: 8),
          text(
            message,
            color: colors.onSurfaceVariant,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
