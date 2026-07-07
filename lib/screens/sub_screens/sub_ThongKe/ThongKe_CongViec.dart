import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:todo/controllers/task_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/task.dart';
import 'package:todo/widgets/ui.dart';

class ThongKe_CongViec_Screen extends StatefulWidget {
  const ThongKe_CongViec_Screen({super.key});

  @override
  State<ThongKe_CongViec_Screen> createState() =>
      _ThongKe_CongViec_ScreenState();
}

class _ThongKe_CongViec_ScreenState extends State<ThongKe_CongViec_Screen> {
  final taskController = TaskController();

  bool _isDone(TaskModel task) => task.status.trim().toLowerCase() == "done";

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isOverdue(TaskModel task) {
    return !_isDone(task) &&
        !task.isArchived &&
        _dateOnly(DateTime.now()).isAfter(_dateOnly(task.deadline));
  }

  bool _isDueSoon(TaskModel task) {
    if (_isDone(task) || task.isArchived) return false;
    final daysLeft = _dateOnly(
      task.deadline,
    ).difference(_dateOnly(DateTime.now())).inDays;
    return daysLeft >= 0 && daysLeft <= 3;
  }

  List<TaskModel> _dueSoonTasks(List<TaskModel> tasks) {
    return tasks.where(_isDueSoon).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const _InlineState(
        iconData: Icons.lock_outline,
        message: "Vui lòng đăng nhập để xem thống kê công việc.",
      );
    }

    return StreamBuilder<List<TaskModel>>(
      stream: taskController.getTasksByUser(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading();
        }

        if (snapshot.hasError) {
          return const _InlineState(
            iconData: Icons.error_outline,
            message: "Không thể tải thống kê công việc.",
          );
        }

        final tasks = snapshot.data ?? [];
        final total = tasks.length;
        final archived = tasks.where((task) => task.isArchived).length;
        final activeTasks = tasks.where((task) => !task.isArchived).toList();
        final done = tasks.where(_isDone).length;
        final overdue = tasks.where(_isOverdue).length;
        final dueSoon = tasks.where(_isDueSoon).length;
        final pending = activeTasks.where((task) => !_isDone(task)).length;
        final donePercent = total == 0 ? 0 : (done / total * 100).round();
        final chartData = [
          ChartData('Đã hoàn thành', done.toDouble(), AppColors.success),
          ChartData('Chưa hoàn thành', pending.toDouble(), AppColors.primary),
          ChartData('Quá hạn', overdue.toDouble(), AppColors.danger),
          ChartData('Sắp đến hạn', dueSoon.toDouble(), AppColors.warning),
        ];
        final priorityData = [
          {
            'priority': 'Cao',
            'value': tasks.where((t) => t.priority >= 3).length,
            'color': AppColors.danger,
          },
          {
            'priority': 'Vừa',
            'value': tasks.where((t) => t.priority == 2).length,
            'color': AppColors.warning,
          },
          {
            'priority': 'Thấp',
            'value': tasks.where((t) => t.priority <= 1).length,
            'color': AppColors.textSecondary,
          },
        ];

        return scroll(
          child: column(
            children: [
              grid(
                ratio: 1.25,
                shrinkWrap: true,
                children: [
                  cardThongKe(
                    iconData: Icons.task_alt,
                    title: "Tổng công việc",
                    subtitle: "$total",
                    note: "$pending đang xử lý",
                    color: AppColors.primary,
                  ),
                  cardThongKe(
                    iconData: Icons.check_circle,
                    title: "Hoàn thành",
                    subtitle: "$done",
                    note: "$donePercent% đã hoàn thành",
                    color: AppColors.success,
                  ),
                  cardThongKe(
                    iconData: Icons.archive_outlined,
                    title: "Đã lưu trữ",
                    subtitle: "$archived",
                    note: "Ẩn khỏi danh sách mặc định",
                    color: AppColors.textSecondary,
                  ),
                  cardThongKe(
                    iconData: Icons.warning,
                    title: "Quá hạn",
                    subtitle: "$overdue",
                    note: "Tính động theo deadline",
                    color: AppColors.danger,
                  ),
                  cardThongKe(
                    iconData: Icons.timelapse,
                    title: "Sắp đến hạn",
                    subtitle: "$dueSoon",
                    note: "Trong 3 ngày tới",
                    color: AppColors.warning,
                  ),
                ],
              ),
              box(height: 16),
              _chartCard(
                child: SfCircularChart(
                  title: ChartTitle(
                    text: 'Phân bổ công việc',
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
              _chartCard(
                child: chartUuTien(
                  context: context,
                  title: "Phân bổ theo độ ưu tiên",
                  dataSource: priorityData,
                ),
              ),
              _dueSoonCard(tasks),
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

  Widget _dueSoonCard(List<TaskModel> tasks) {
    final dueSoonTasks = _dueSoonTasks(tasks);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warningBackground = isDark
        ? colors.surfaceContainerHighest
        : AppColors.warningSoft;
    final warningBorder = isDark
        ? AppColors.warning.withValues(alpha: 0.45)
        : const Color(0xFFFFE3B0);

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
            text("Công việc sắp đến hạn", weight: FontWeight.bold, size: 18),
            box(height: 12),
            if (dueSoonTasks.isEmpty)
              text(
                "Không có công việc sắp đến hạn",
                color: colors.onSurfaceVariant,
              )
            else
              for (final task in dueSoonTasks.take(5))
                padding(
                  bottom: 8,
                  child: containerBox(
                    width: double.infinity,
                    color: warningBackground,
                    radius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: warningBorder),
                    padding: const EdgeInsets.all(10),
                    child: column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        text(task.title, weight: FontWeight.bold, size: 15),
                        text(
                          DateFormat('dd/MM/yyyy').format(task.deadline),
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
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

Widget chartUuTien({
  required BuildContext context,
  String? title,
  required List<Map<String, dynamic>> dataSource,
}) {
  final colors = Theme.of(context).colorScheme;

  return SfCartesianChart(
    title: ChartTitle(
      text: title ?? "Phân bổ theo độ ưu tiên",
      alignment: ChartAlignment.near,
      textStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: colors.onSurface,
      ),
    ),
    primaryXAxis: CategoryAxis(
      majorGridLines: const MajorGridLines(width: 0),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      axisLine: AxisLine(color: colors.outlineVariant),
    ),
    primaryYAxis: NumericAxis(
      minimum: 0,
      interval: 1,
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      axisLine: AxisLine(color: colors.outlineVariant),
      majorGridLines: MajorGridLines(color: colors.outlineVariant),
    ),
    series: <CartesianSeries>[
      ColumnSeries<Map<String, dynamic>, String>(
        dataSource: dataSource,
        xValueMapper: (data, _) => data['priority'] as String,
        yValueMapper: (data, _) => data['value'] as int,
        pointColorMapper: (data, _) => data['color'] as Color,
        dataLabelSettings: DataLabelSettings(
          isVisible: true,
          labelAlignment: ChartDataLabelAlignment.outer,
          textStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.onSurfaceVariant,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        width: 0.6,
      ),
    ],
  );
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
