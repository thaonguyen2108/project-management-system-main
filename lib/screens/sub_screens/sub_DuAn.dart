import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/controllers/project_Controller.dart';
import 'package:todo/controllers/task_Controller.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/core/pref_halper.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';
import 'package:todo/screens/modalScreen/projectForm.dart';
import 'package:todo/widgets/ui.dart';

class Sub_DuAn_Screen extends StatefulWidget {
  const Sub_DuAn_Screen({super.key});

  @override
  State<Sub_DuAn_Screen> createState() => _Sub_DuAn_ScreenState();
}

class _Sub_DuAn_ScreenState extends State<Sub_DuAn_Screen> {
  final projectController = ProjectController();
  final taskController = TaskController();
  final searchController = TextEditingController();

  final List<String> boLoc = const ["Đang hoạt động", "Đã lưu trữ", "Tất cả"];
  final List<String> sapXep = const [
    "Mới nhất",
    "Cũ nhất",
    "Deadline gần nhất",
    "Tên A-Z",
    "Trạng thái",
  ];

  String selectBoLoc = "Đang hoạt động";
  String selectSapXep = "Mới nhất";

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final savedFilter = PrefHelper.getUiPreference(
      uid,
      'project_filter',
      selectBoLoc,
    );
    final savedSort = PrefHelper.getUiPreference(
      uid,
      'project_sort',
      selectSapXep,
    );
    if (boLoc.contains(savedFilter)) selectBoLoc = savedFilter;
    if (sapXep.contains(savedSort)) selectSapXep = savedSort;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool? get selectedArchiveFilter {
    if (selectBoLoc == "Đã lưu trữ") return true;
    if (selectBoLoc == "Tất cả") return null;
    return false;
  }

  List<ProjectModel> _visibleProjects(List<ProjectModel> projects) {
    final query = searchController.text.trim().toLowerCase();
    final result = projects.where((project) {
      if (query.isEmpty) return true;
      return project.name.toLowerCase().contains(query) ||
          project.description.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      switch (selectSapXep) {
        case "Cũ nhất":
          return _projectTime(a).compareTo(_projectTime(b));
        case "Deadline gần nhất":
          return a.deadline.compareTo(b.deadline);
        case "Tên A-Z":
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case "Trạng thái":
          return _projectStatusSortScore(
            a,
          ).compareTo(_projectStatusSortScore(b));
        case "Mới nhất":
        default:
          return _projectTime(b).compareTo(_projectTime(a));
      }
    });

    return result;
  }

  DateTime _projectTime(ProjectModel project) {
    return project.updatedAt ?? project.createdAt ?? project.startTime;
  }

  int _projectStatusSortScore(ProjectModel project) {
    if (project.isArchived) return 4;

    final today = _dateOnly(DateTime.now());
    final startDate = _dateOnly(project.startTime);
    final deadline = _dateOnly(project.deadline);
    final daysUntilDeadline = deadline.difference(today).inDays;

    if (today.isAfter(deadline)) return 0;
    if (daysUntilDeadline >= 0 && daysUntilDeadline <= 5) return 1;
    if (today.isBefore(startDate)) return 3;
    return 2;
  }

  Color projectColor(ProjectModel project) {
    const fallbackColor = AppColors.primary;
    final rawColor = project.mainColor?.trim();
    if (rawColor == null || rawColor.isEmpty) return fallbackColor;

    final hex = rawColor.startsWith("#") ? rawColor.substring(1) : rawColor;
    final normalizedHex = hex.length == 6 ? "FF$hex" : hex;
    final colorValue = int.tryParse(normalizedHex, radix: 16);

    return colorValue == null ? fallbackColor : Color(colorValue);
  }

  void openProjectForm({ProjectModel? project}) {
    final isEdit = project != null;
    final isArchived = project?.isArchived == true;
    final projectFormKey = GlobalKey<FormDuAnState>();
    bool isSavingProject = false;

    showAppModal(
      context: context,
      title: isEdit
          ? (isArchived ? "Chi tiết dự án đã lưu trữ" : "Chi tiết dự án")
          : "Thêm dự án mới",
      child: FormDuAn(key: projectFormKey, project: project),
      listButtons: StatefulBuilder(
        builder: (context, setModalState) {
          return padding(
            right: 10,
            top: 10,
            bottom: 10,
            child: align(
              alignment: Alignment.bottomRight,
              child: row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isArchived)
                    button(
                      label: "Đóng",
                      onPressed: () => Navigator.pop(context),
                      color: AppColors.surfaceMuted,
                    )
                  else
                    button(
                      label: isSavingProject
                          ? "Đang lưu..."
                          : isEdit
                          ? "Lưu thay đổi"
                          : "Thêm",
                      onPressed: () async {
                        if (isSavingProject) return;

                        setModalState(() {
                          isSavingProject = true;
                        });

                        final success =
                            await projectFormKey.currentState
                                ?.submitProject() ??
                            false;

                        if (!success && context.mounted) {
                          setModalState(() {
                            isSavingProject = false;
                          });
                        }
                      },
                      color: isSavingProject
                          ? const Color(0xFFB8C0CC)
                          : AppColors.primary,
                      textColor: Colors.white,
                    ),
                  box(width: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void archiveProject({
    required ProjectModel project,
    required int totalTasks,
    required int completedTasks,
  }) {
    if (project.isArchived) {
      snack(
        context,
        message: "Dự án này đã được lưu trữ",
        backgroundColor: AppColors.textSecondary,
      );
      return;
    }

    if (totalTasks == 0 || completedTasks != totalTasks) {
      snack(
        context,
        message: "Chỉ có thể lưu trữ dự án khi tất cả công việc đã hoàn thành.",
        backgroundColor: AppColors.danger,
      );
      return;
    }

    dialog(
      context,
      title: "Lưu trữ dự án",
      message: "Dự án đã hoàn thành. Bạn có muốn lưu trữ dự án này không?",
      okText: "Lưu trữ",
      okColor: AppColors.primary,
      onOk: () async {
        try {
          await projectController.archiveProject(project);
          if (!mounted) return;

          snack(
            context,
            message: "Đã lưu trữ dự án",
            backgroundColor: AppColors.primary,
          );
        } catch (_) {
          if (!mounted) return;

          snack(
            context,
            message: "Không thể lưu trữ dự án. Vui lòng thử lại",
            backgroundColor: AppColors.danger,
          );
        }
      },
    );
  }

  void unarchiveProject(ProjectModel project) {
    dialog(
      context,
      title: "Khôi phục dự án",
      message: "Dự án sẽ quay lại danh sách đang hoạt động.",
      okText: "Khôi phục",
      okColor: AppColors.primary,
      onOk: () async {
        try {
          await projectController.unarchiveProject(project);
          if (!mounted) return;

          snack(
            context,
            message: "Đã khôi phục dự án",
            backgroundColor: AppColors.primary,
          );
        } catch (_) {
          if (!mounted) return;

          snack(
            context,
            message: "Không thể khôi phục dự án. Vui lòng thử lại",
            backgroundColor: AppColors.danger,
          );
        }
      },
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
          message: "Vui lòng đăng nhập để xem danh sách dự án.",
        ),
      );
    }

    return StreamBuilder<List<ProjectModel>>(
      stream: projectController.getMyProjects(
        currentUser.uid,
        isArchived: selectedArchiveFilter,
      ),
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
              title: "Không thể tải dự án",
              message: "Vui lòng thử lại sau hoặc kiểm tra kết nối.",
            ),
          );
        }

        final projects = _visibleProjects(snapshot.data ?? []);

        return screen(
          backgroundColor: theme.scaffoldBackgroundColor,
          resizeToAvoidBottomInset: false,
          body: stack(
            children: [
              padding(
                left: 12,
                right: 12,
                top: 12,
                child: column(
                  children: [
                    _ProjectToolbar(
                      textColor: colors.onSurface,
                      secondaryTextColor: colors.onSurfaceVariant,
                      projectsCount: projects.length,
                      currentFilter: selectBoLoc,
                      filters: boLoc,
                      currentSort: selectSapXep,
                      sorts: sapXep,
                      searchController: searchController,
                      onSearchChanged: (_) => setState(() {}),
                      onFilterChanged: (val) {
                        setState(() {
                          selectBoLoc = val ?? "Đang hoạt động";
                        });
                        PrefHelper.setUiPreference(
                          currentUser.uid,
                          'project_filter',
                          selectBoLoc,
                        );
                      },
                      onSortChanged: (val) {
                        setState(() {
                          selectSapXep = val ?? "Mới nhất";
                        });
                        PrefHelper.setUiPreference(
                          currentUser.uid,
                          'project_sort',
                          selectSapXep,
                        );
                      },
                    ),
                    box(height: 14),
                    if (projects.isEmpty)
                      const Flexible(
                        fit: FlexFit.tight,
                        child: _StateMessage(
                          iconData: Icons.folder_open_outlined,
                          title: "Chưa có dự án nào",
                          message:
                              "Tạo dự án mới hoặc đổi bộ lọc để xem dự án phù hợp.",
                        ),
                      )
                    else
                      flexible(
                        child: list(
                          children: [
                            for (final project in projects)
                              cardDuAn(
                                project: project,
                                accentColor: projectColor(project),
                                taskController: taskController,
                                onTap: () => openProjectForm(project: project),
                                onArchive: archiveProject,
                                onUnarchive: unarchiveProject,
                              ),
                            box(height: 80),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (selectedArchiveFilter != true)
                padding(
                  bottom: 16,
                  right: 16,
                  child: align(
                    alignment: Alignment.bottomRight,
                    child: pressable(
                      onTap: () => openProjectForm(),
                      borderRadius: BorderRadius.circular(28),
                      child: containerBox(
                        color: AppColors.primary,
                        width: 56,
                        height: 56,
                        radius: BorderRadius.circular(28),
                        shadow: AppShadows.card,
                        child: icon(Icons.add, size: 30, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectToolbar extends StatelessWidget {
  final int projectsCount;
  final String currentFilter;
  final List<String> filters;
  final String currentSort;
  final List<String> sorts;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onFilterChanged;
  final ValueChanged<String?> onSortChanged;
  final Color textColor;
  final Color secondaryTextColor;

  const _ProjectToolbar({
    required this.projectsCount,
    required this.currentFilter,
    required this.filters,
    required this.currentSort,
    required this.sorts,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return column(
      children: [
        align(
          alignment: Alignment.centerLeft,
          child: column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text(
                "Dự án của bạn",
                weight: FontWeight.bold,
                size: 20,
                color: textColor,
              ),
              text(
                "$projectsCount dự án - $currentFilter",
                size: 12,
                color: secondaryTextColor,
              ),
            ],
          ),
        ),
        box(height: 10),
        formInput(
          controller: searchController,
          label: "Tìm kiếm",
          hint: "Tên hoặc mô tả dự án",
          prefixIcon: Icons.search,
          fillColor: AppColors.surface,
          borderRadius: AppRadius.lg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          onChanged: onSearchChanged,
        ),
        box(height: 10),
        row(
          children: [
            flexible(
              child: dropdown(
                list: filters,
                value: currentFilter,
                fillColor: AppColors.surface,
                dropdownColor: AppColors.surface,
                borderRadius: AppRadius.md,
                onChanged: onFilterChanged,
                hint: "Bộ lọc",
              ),
            ),
            box(width: 10),
            flexible(
              child: dropdown(
                list: sorts,
                value: currentSort,
                fillColor: AppColors.surface,
                dropdownColor: AppColors.surface,
                borderRadius: AppRadius.md,
                onChanged: onSortChanged,
                hint: "Sắp xếp",
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget cardDuAn({
  required ProjectModel project,
  required Color accentColor,
  required TaskController taskController,
  VoidCallback? onTap,
  void Function({
    required ProjectModel project,
    required int totalTasks,
    required int completedTasks,
  })?
  onArchive,
  void Function(ProjectModel project)? onUnarchive,
}) {
  return StreamBuilder<List<TaskModel>>(
    stream: taskController.getTasksByProject(project.id),
    builder: (context, snapshot) {
      final isTaskLoading =
          snapshot.connectionState == ConnectionState.waiting &&
          !snapshot.hasData;
      final hasTaskError = snapshot.hasError;
      final tasks = hasTaskError ? <TaskModel>[] : snapshot.data ?? [];
      final totalTasks = tasks.length;
      final completedTasks = tasks
          .where((task) => task.status.trim().toLowerCase() == "done")
          .length;
      final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
      final status = _projectCardStatus(
        project: project,
        totalTasks: totalTasks,
        completedTasks: completedTasks,
      );

      return _ProjectCardContent(
        project: project,
        accentColor: accentColor,
        status: status,
        progress: progress,
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        isTaskLoading: isTaskLoading,
        hasTaskError: hasTaskError,
        onTap: onTap,
        onArchive: onArchive,
        onUnarchive: onUnarchive,
      );
    },
  );
}

enum _ProjectCardStatus { notStarted, inProgress, dueSoon, overdue, completed }

_ProjectCardStatus _projectCardStatus({
  required ProjectModel project,
  required int totalTasks,
  required int completedTasks,
}) {
  final today = _dateOnly(DateTime.now());
  final startDate = _dateOnly(project.startTime);
  final deadline = _dateOnly(project.deadline);
  final daysUntilDeadline = deadline.difference(today).inDays;

  if (totalTasks > 0 && completedTasks == totalTasks) {
    return _ProjectCardStatus.completed;
  }

  if (today.isAfter(deadline)) {
    return _ProjectCardStatus.overdue;
  }

  if (today.isBefore(startDate)) {
    return _ProjectCardStatus.notStarted;
  }

  if (daysUntilDeadline >= 0 && daysUntilDeadline <= 5) {
    return _ProjectCardStatus.dueSoon;
  }

  return _ProjectCardStatus.inProgress;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _statusLabel(_ProjectCardStatus status) {
  switch (status) {
    case _ProjectCardStatus.completed:
      return "Hoàn thành";
    case _ProjectCardStatus.overdue:
      return "Quá hạn";
    case _ProjectCardStatus.notStarted:
      return "Chưa bắt đầu";
    case _ProjectCardStatus.dueSoon:
      return "Sắp đến hạn";
    case _ProjectCardStatus.inProgress:
      return "Đang thực hiện";
  }
}

Color _statusBackgroundColor(_ProjectCardStatus status) {
  switch (status) {
    case _ProjectCardStatus.completed:
      return AppColors.successSoft;
    case _ProjectCardStatus.overdue:
      return AppColors.dangerSoft;
    case _ProjectCardStatus.notStarted:
      return AppColors.surfaceMuted;
    case _ProjectCardStatus.dueSoon:
      return AppColors.warningSoft;
    case _ProjectCardStatus.inProgress:
      return AppColors.surface;
  }
}

Color _statusBadgeColor(_ProjectCardStatus status) {
  switch (status) {
    case _ProjectCardStatus.completed:
      return const Color(0xFFD8F1DF);
    case _ProjectCardStatus.overdue:
      return const Color(0xFFFFDCDC);
    case _ProjectCardStatus.notStarted:
      return const Color(0xFFE6E9EE);
    case _ProjectCardStatus.dueSoon:
      return const Color(0xFFFFE7C2);
    case _ProjectCardStatus.inProgress:
      return const Color(0xFFE0ECFF);
  }
}

Color _statusTextColor(_ProjectCardStatus status) {
  switch (status) {
    case _ProjectCardStatus.completed:
      return const Color(0xFF237A3B);
    case _ProjectCardStatus.overdue:
      return const Color(0xFFB42318);
    case _ProjectCardStatus.notStarted:
      return const Color(0xFF4B5563);
    case _ProjectCardStatus.dueSoon:
      return const Color(0xFF9A5B00);
    case _ProjectCardStatus.inProgress:
      return const Color(0xFF1D4E89);
  }
}

class _ProjectCardContent extends StatelessWidget {
  final ProjectModel project;
  final Color accentColor;
  final _ProjectCardStatus status;
  final double progress;
  final int totalTasks;
  final int completedTasks;
  final bool isTaskLoading;
  final bool hasTaskError;
  final VoidCallback? onTap;
  final void Function({
    required ProjectModel project,
    required int totalTasks,
    required int completedTasks,
  })?
  onArchive;
  final void Function(ProjectModel project)? onUnarchive;

  const _ProjectCardContent({
    required this.project,
    required this.accentColor,
    required this.status,
    required this.progress,
    required this.totalTasks,
    required this.completedTasks,
    required this.isTaskLoading,
    required this.hasTaskError,
    this.onTap,
    this.onArchive,
    this.onUnarchive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final description = project.description.trim();
    final percent = (progress * 100).round();
    final startDate = DateFormat('dd/MM/yyyy').format(project.startTime);
    final deadline = DateFormat('dd/MM/yyyy').format(project.deadline);
    final memberCount = project.members?.length ?? 0;

    return pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Card(
        color: project.isArchived
            ? (isDark
                  ? colors.surfaceContainerHighest
                  : const Color(0xFFF5F7FA))
            : (isDark ? colors.surface : _statusBackgroundColor(status)),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 7, color: accentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                project.name.isEmpty
                                    ? "Dự án chưa đặt tên"
                                    : project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            project.isArchived
                                ? _archivedBadge()
                                : _statusBadge(status),
                            const SizedBox(width: 4),
                            if (!project.isArchived)
                              pressable(
                                borderRadius: BorderRadius.circular(12),
                                onTap: onArchive == null
                                    ? null
                                    : () => onArchive!(
                                        project: project,
                                        totalTasks: totalTasks,
                                        completedTasks: completedTasks,
                                      ),
                                child: const Icon(
                                  Icons.archive_outlined,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            else if (onUnarchive != null)
                              pressable(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => onUnarchive!(project),
                                child: const Icon(
                                  Icons.unarchive_outlined,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _infoPill(
                              icon: Icons.play_arrow_rounded,
                              label: startDate,
                            ),
                            _infoPill(
                              icon: Icons.flag_rounded,
                              label: deadline,
                            ),
                            _infoPill(
                              icon: Icons.group_outlined,
                              label: "$memberCount nhân sự",
                            ),
                            _infoPill(
                              icon: Icons.check_circle_outline,
                              label: "$completedTasks/$totalTasks task",
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Tiến độ",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            Text(
                              isTaskLoading ? "Đang tính" : "$percent%",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        LinearProgressIndicator(
                          value: isTaskLoading ? null : progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: colors.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                        if (hasTaskError) ...[
                          const SizedBox(height: 6),
                          const Text(
                            "Chưa tải được tiến độ công việc",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A4B00),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _statusBadge(_ProjectCardStatus status) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: _statusBadgeColor(status),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      _statusLabel(status),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _statusTextColor(status),
      ),
    ),
  );
}

Widget _archivedBadge() {
  return Builder(
    builder: (context) {
      final colors = Theme.of(context).colorScheme;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Đã lưu trữ",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    },
  );
}

Widget _infoPill({required IconData icon, required String label}) {
  return Builder(
    builder: (context) {
      final colors = Theme.of(context).colorScheme;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      );
    },
  );
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
