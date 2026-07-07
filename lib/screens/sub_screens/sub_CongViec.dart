import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/controllers/task_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/core/pref_halper.dart';
import 'package:todo/models/task.dart';
import 'package:todo/widgets/ui.dart';

class Sub_CongViec_Screen extends StatefulWidget {
  const Sub_CongViec_Screen({super.key});

  @override
  State<Sub_CongViec_Screen> createState() => _Sub_CongViec_ScreenState();
}

class _Sub_CongViec_ScreenState extends State<Sub_CongViec_Screen> {
  final taskController = TaskController();
  final searchController = TextEditingController();
  final updatingTaskIds = <String>{};

  final List<String> trangThai = const [
    "Tất cả",
    "Chưa hoàn thành",
    "Đã hoàn thành",
    "Sắp đến hạn",
    "Quá hạn",
  ];
  final List<String> archiveFilters = const [
    "Đang hoạt động",
    "Đã lưu trữ",
    "Tất cả",
  ];
  final List<String> sortOptions = const [
    "Deadline gần nhất",
    "Deadline xa nhất",
    "Ưu tiên cao nhất",
    "Mới nhất",
    "Cũ nhất",
    "Tên A-Z",
  ];

  String selectTrangThai = "Tất cả";
  String selectArchive = "Đang hoạt động";
  String selectSort = "Deadline gần nhất";

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final savedArchive = PrefHelper.getUiPreference(
      uid,
      'task_archive_filter',
      selectArchive,
    );
    final savedStatus = PrefHelper.getUiPreference(
      uid,
      'task_status_filter',
      selectTrangThai,
    );
    final savedSort = PrefHelper.getUiPreference(uid, 'task_sort', selectSort);
    if (archiveFilters.contains(savedArchive)) selectArchive = savedArchive;
    if (trangThai.contains(savedStatus)) selectTrangThai = savedStatus;
    if (sortOptions.contains(savedSort)) selectSort = savedSort;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _isDone(TaskModel task) {
    return task.status.trim().toLowerCase() == "done";
  }

  bool _isOverdue(TaskModel task) {
    final today = _dateOnly(DateTime.now());
    final deadline = _dateOnly(task.deadline);
    return !_isDone(task) && !task.isArchived && today.isAfter(deadline);
  }

  bool _isDueSoon(TaskModel task) {
    if (_isDone(task) || task.isArchived) return false;
    final today = _dateOnly(DateTime.now());
    final deadline = _dateOnly(task.deadline);
    final daysLeft = deadline.difference(today).inDays;
    return daysLeft >= 0 && daysLeft <= 3;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _taskTime(TaskModel task) {
    return task.updatedAt ?? task.createdAt ?? task.deadline;
  }

  List<TaskModel> _filteredTasks(List<TaskModel> tasks) {
    final query = searchController.text.trim().toLowerCase();

    final result = tasks.where((task) {
      if (selectArchive == "Đang hoạt động" && task.isArchived) return false;
      if (selectArchive == "Đã lưu trữ" && !task.isArchived) return false;

      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      switch (selectTrangThai) {
        case "Chưa hoàn thành":
          return !_isDone(task) && !task.isArchived;
        case "Đã hoàn thành":
          return _isDone(task);
        case "Sắp đến hạn":
          return _isDueSoon(task);
        case "Quá hạn":
          return _isOverdue(task);
        default:
          return true;
      }
    }).toList();

    result.sort((a, b) {
      switch (selectSort) {
        case "Deadline xa nhất":
          return b.deadline.compareTo(a.deadline);
        case "Ưu tiên cao nhất":
          return b.priority.compareTo(a.priority);
        case "Mới nhất":
          return _taskTime(b).compareTo(_taskTime(a));
        case "Cũ nhất":
          return _taskTime(a).compareTo(_taskTime(b));
        case "Tên A-Z":
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case "Deadline gần nhất":
        default:
          return a.deadline.compareTo(b.deadline);
      }
    });

    return result;
  }

  String _statusLabel(TaskModel task) {
    if (task.isArchived) return "Đã lưu trữ";
    if (_isDone(task)) return "Đã hoàn thành";
    if (_isOverdue(task)) return "Quá hạn";
    if (_isDueSoon(task)) return "Sắp đến hạn";
    return "Chưa hoàn thành";
  }

  Color _statusColor(TaskModel task) {
    if (task.isArchived) return AppColors.textSecondary;
    if (_isDone(task)) return AppColors.success;
    if (_isOverdue(task)) return AppColors.danger;
    if (_isDueSoon(task)) return AppColors.warning;
    return AppColors.primary;
  }

  String _priorityLabel(int priority) {
    if (priority >= 3) return "Ưu tiên cao";
    if (priority == 2) return "Ưu tiên vừa";
    return "Ưu tiên thấp";
  }

  Future<void> _markDone(TaskModel task) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != task.assigneeId) {
      snack(
        context,
        message: "Bạn chỉ có thể hoàn thành công việc được giao cho mình",
        backgroundColor: AppColors.danger,
      );
      return;
    }

    if (task.isArchived) {
      snack(
        context,
        message: "Công việc đã lưu trữ, không thể cập nhật trạng thái.",
        backgroundColor: AppColors.danger,
      );
      return;
    }

    setState(() {
      updatingTaskIds.add(task.id);
    });

    try {
      final error = await taskController.markDone(task);
      if (!mounted) return;

      if (error != null) {
        snack(
          context,
          message: "Không thể cập nhật trạng thái công việc",
          backgroundColor: AppColors.danger,
        );
        return;
      }

      snack(
        context,
        message: "Đã đánh dấu công việc hoàn thành",
        backgroundColor: AppColors.primary,
      );
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          updatingTaskIds.remove(task.id);
        });
      }
    }
  }

  Future<void> _setTaskArchived(TaskModel task, bool archived) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != task.assigneeId) {
      snack(
        context,
        message: "Bạn chỉ có thể lưu trữ công việc được giao cho mình",
        backgroundColor: AppColors.danger,
      );
      return;
    }

    if (archived && !_isDone(task)) {
      snack(
        context,
        message: "Chỉ có thể lưu trữ công việc đã hoàn thành.",
        backgroundColor: AppColors.danger,
      );
      return;
    }

    setState(() {
      updatingTaskIds.add(task.id);
    });

    try {
      final error = archived
          ? await taskController.archiveTask(task, currentUser.uid)
          : await taskController.unarchiveTask(task);

      if (!mounted) return;

      if (error != null) {
        snack(
          context,
          message: archived
              ? "Không thể lưu trữ công việc"
              : "Không thể khôi phục công việc",
          backgroundColor: AppColors.danger,
        );
        return;
      }

      snack(
        context,
        message: archived ? "Đã lưu trữ công việc" : "Đã khôi phục công việc",
        backgroundColor: AppColors.primary,
      );
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          updatingTaskIds.remove(task.id);
        });
      }
    }
  }

  void _showTaskDetail(TaskModel task) {
    final isDone = _isDone(task);
    final isUpdating = updatingTaskIds.contains(task.id);
    final colors = Theme.of(context).colorScheme;

    showAppModal(
      context: context,
      title: "Chi tiết công việc",
      initialSize: 0.62,
      child: column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text(task.title, size: 18, weight: FontWeight.bold, maxLines: 2),
          box(height: 10),
          text(
            task.description.isEmpty ? "Không có mô tả" : task.description,
            size: 14,
            maxLines: 8,
            color: colors.onSurfaceVariant,
          ),
          box(height: 14),
          _infoRow(
            iconData: Icons.calendar_month,
            label: "Deadline",
            value: DateFormat('dd/MM/yyyy').format(task.deadline),
          ),
          box(height: 8),
          _infoRow(
            iconData: Icons.flag_outlined,
            label: "Trạng thái",
            value: _statusLabel(task),
            valueColor: _statusColor(task),
          ),
          box(height: 8),
          _infoRow(
            iconData: Icons.priority_high_rounded,
            label: "Độ ưu tiên",
            value: _priorityLabel(task.priority),
          ),
          box(height: 18),
          if (task.isArchived)
            button(
              label: isUpdating ? "Đang khôi phục..." : "Khôi phục công việc",
              width: double.infinity,
              color: isUpdating ? const Color(0xFFB8C0CC) : AppColors.primary,
              textColor: Colors.white,
              onPressed: () {
                if (!isUpdating) _setTaskArchived(task, false);
              },
            )
          else ...[
            if (!isDone)
              button(
                label: isUpdating ? "Đang cập nhật..." : "Đánh dấu hoàn thành",
                width: double.infinity,
                color: isUpdating ? const Color(0xFFB8C0CC) : AppColors.primary,
                textColor: Colors.white,
                onPressed: () {
                  if (!isUpdating) _markDone(task);
                },
              )
            else
              containerBox(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                radius: BorderRadius.circular(AppRadius.md),
                color: AppColors.successSoft,
                child: text(
                  "Công việc đã hoàn thành",
                  color: AppColors.success,
                  weight: FontWeight.bold,
                  align: TextAlign.center,
                ),
              ),
            box(height: 10),
            button(
              label: isUpdating ? "Đang lưu trữ..." : "Lưu trữ công việc",
              width: double.infinity,
              color: isDone ? AppColors.textSecondary : const Color(0xFFB8C0CC),
              textColor: Colors.white,
              onPressed: () {
                if (!isUpdating) _setTaskArchived(task, true);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData iconData,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final colors = Theme.of(context).colorScheme;

    return row(
      children: [
        icon(iconData, size: 18, color: colors.onSurfaceVariant),
        box(width: 8),
        text(
          "$label: ",
          weight: FontWeight.bold,
          size: 14,
          color: colors.onSurface,
        ),
        flexible(
          child: text(
            value,
            size: 14,
            color: valueColor ?? colors.onSurface,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _taskCard(TaskModel task) {
    final statusColor = _statusColor(task);
    final colors = Theme.of(context).colorScheme;

    return pressable(
      onTap: () => _showTaskDetail(task),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: task.isArchived
            ? colors.surfaceContainerHighest.withValues(alpha: 0.82)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  flexible(
                    child: text(
                      task.title.isEmpty
                          ? "Công việc chưa đặt tên"
                          : task.title,
                      weight: FontWeight.bold,
                      size: 16,
                      color: colors.onSurface,
                      maxLines: 2,
                    ),
                  ),
                  box(width: 8),
                  _chip(label: _statusLabel(task), color: statusColor),
                ],
              ),
              box(height: 6),
              text(
                task.description.isEmpty ? "Không có mô tả" : task.description,
                size: 13,
                color: colors.onSurfaceVariant,
                maxLines: 2,
              ),
              box(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(
                    iconData: Icons.calendar_month,
                    label: DateFormat('dd/MM/yyyy').format(task.deadline),
                  ),
                  _infoChip(
                    iconData: Icons.priority_high_rounded,
                    label: _priorityLabel(task.priority),
                  ),
                  if (task.isArchived)
                    _infoChip(
                      iconData: Icons.archive_outlined,
                      label: "Đã lưu trữ",
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({required String label, required Color color}) {
    return containerBox(
      color: color.withValues(alpha: 0.12),
      radius: BorderRadius.circular(AppRadius.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: text(label, color: color, size: 12, weight: FontWeight.bold),
    );
  }

  Widget _infoChip({required IconData iconData, required String label}) {
    final colors = Theme.of(context).colorScheme;

    return containerBox(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      radius: BorderRadius.circular(AppRadius.sm),
      color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
      child: row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(iconData, size: 16, color: colors.onSurfaceVariant),
          box(width: 5),
          text(label, size: 12, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (currentUser == null) {
      return screen(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const _StateMessage(
          iconData: Icons.lock_outline,
          title: "Bạn chưa đăng nhập",
          message: "Vui lòng đăng nhập để xem công việc.",
        ),
      );
    }

    return StreamBuilder<List<TaskModel>>(
      stream: taskController.getTasksByUser(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return screen(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: loading(),
          );
        }

        if (snapshot.hasError) {
          return screen(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const _StateMessage(
              iconData: Icons.error_outline,
              title: "Không thể tải công việc",
              message: "Vui lòng thử lại sau hoặc kiểm tra kết nối.",
            ),
          );
        }

        final tasks = _filteredTasks(snapshot.data ?? []);

        return screen(
          backgroundColor: theme.scaffoldBackgroundColor,
          resizeToAvoidBottomInset: false,
          body: padding(
            left: 12,
            right: 12,
            top: 12,
            child: column(
              children: [
                align(
                  alignment: Alignment.centerLeft,
                  child: column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text(
                        "Công việc của tôi",
                        weight: FontWeight.bold,
                        size: 20,
                        color: colors.onSurface,
                        align: TextAlign.left,
                      ),
                      text(
                        "${tasks.length} công việc phù hợp",
                        size: 12,
                        color: colors.onSurfaceVariant,
                        align: TextAlign.left,
                      ),
                    ],
                  ),
                ),
                box(height: 12),
                formInput(
                  controller: searchController,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  label: "Tìm kiếm",
                  hint: "Tên hoặc mô tả công việc",
                  prefixIcon: Icons.search,
                  fillColor: AppColors.surface,
                  labelColor: AppColors.textPrimary,
                  borderRadius: AppRadius.lg,
                  onChanged: (_) => setState(() {}),
                ),
                box(height: 10),
                row(
                  children: [
                    flexible(
                      child: dropdown<String>(
                        list: archiveFilters,
                        value: selectArchive,
                        fillColor: AppColors.surface,
                        borderRadius: AppRadius.lg,
                        onChanged: (val) {
                          setState(() {
                            selectArchive = val ?? "Đang hoạt động";
                          });
                          PrefHelper.setUiPreference(
                            currentUser.uid,
                            'task_archive_filter',
                            selectArchive,
                          );
                        },
                        hint: "Lưu trữ",
                      ),
                    ),
                    box(width: 10),
                    flexible(
                      child: dropdown<String>(
                        list: trangThai,
                        value: selectTrangThai,
                        fillColor: AppColors.surface,
                        borderRadius: AppRadius.lg,
                        onChanged: (val) {
                          setState(() {
                            selectTrangThai = val ?? "Tất cả";
                          });
                          PrefHelper.setUiPreference(
                            currentUser.uid,
                            'task_status_filter',
                            selectTrangThai,
                          );
                        },
                        hint: "Trạng thái",
                      ),
                    ),
                  ],
                ),
                box(height: 10),
                dropdown<String>(
                  list: sortOptions,
                  value: selectSort,
                  fillColor: AppColors.surface,
                  borderRadius: AppRadius.lg,
                  onChanged: (val) {
                    setState(() {
                      selectSort = val ?? "Deadline gần nhất";
                    });
                    PrefHelper.setUiPreference(
                      currentUser.uid,
                      'task_sort',
                      selectSort,
                    );
                  },
                  hint: "Sắp xếp",
                ),
                box(height: 12),
                if (tasks.isEmpty)
                  const Flexible(
                    fit: FlexFit.tight,
                    child: _StateMessage(
                      iconData: Icons.assignment_outlined,
                      title: "Không có công việc phù hợp",
                      message:
                          "Thử đổi bộ lọc hoặc kiểm tra lại từ khóa tìm kiếm.",
                    ),
                  )
                else
                  flexible(
                    child: list(
                      children: [
                        for (final task in tasks) _taskCard(task),
                        box(height: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData iconData;
  final String title;
  final String message;

  const _StateMessage({
    required this.iconData,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 38, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
