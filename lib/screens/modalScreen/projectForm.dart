import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:todo/screens/modalScreen/taskForm.dart';
import 'package:todo/widgets/ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/ai_project_draft.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';
import 'package:todo/models/user.dart';
import 'package:todo/controllers/account_Controller.dart';
import 'package:todo/controllers/friend_Controller.dart';
import 'package:todo/controllers/project_Controller.dart';
import 'package:todo/controllers/task_Controller.dart';
import 'package:todo/screens/modalScreen/user_profile_sheet.dart';
import 'dart:async';

class FormDuAn extends StatefulWidget {
  final ProjectModel? project;
  final AiProjectDraft? initialDraft;

  const FormDuAn({super.key, this.project, this.initialDraft});

  @override
  State<FormDuAn> createState() => FormDuAnState();
}

class FormDuAnState extends State<FormDuAn> {
  final _formKey = GlobalKey<FormState>();

  final taskKey = GlobalKey<TaskFormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  final startDateController = TextEditingController();
  final endDateController = TextEditingController();

  final String? owner = FirebaseAuth.instance.currentUser?.uid;
  final accController = AccountController();
  final projectController = ProjectController();
  final taskController = TaskController();
  StreamSubscription<List<TaskModel>>? _taskSubscription;

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  String mainColor = "FF03A9F4";
  bool isSubmitting = false;
  bool isSavingTask = false;
  bool isLoadingUsers = false;
  bool isLoadingTasks = false;

  String? userLoadError;
  String? taskLoadError;
  String taskArchiveFilter = "Đang hoạt động";

  List<TaskModel> tasks = [];
  List<UserModel> users = [];

  List<String> usersString = [];

  bool get isEdit => widget.project != null;
  bool get hasInitialDraft => !isEdit && widget.initialDraft != null;
  bool get isArchivedProject => widget.project?.isArchived == true;
  bool get canEditProject => canManageProject && !isArchivedProject;

  bool get canManageProject {
    if (!isEdit) return true;

    final currentUid = owner?.trim();
    final projectOwnerId = protectedOwnerId?.trim();

    return currentUid != null &&
        currentUid.isNotEmpty &&
        projectOwnerId != null &&
        projectOwnerId.isNotEmpty &&
        currentUid == projectOwnerId;
  }

  String? get protectedOwnerId {
    final projectOwnerId = widget.project?.ownerId.trim() ?? "";
    return projectOwnerId.isNotEmpty ? projectOwnerId : owner;
  }

  @override
  void initState() {
    super.initState();

    if (isEdit) {
      final project = widget.project!;
      nameController.text = project.name;
      descriptionController.text = project.description;
      startDateController.text = DateFormat(
        'dd/MM/yyyy',
      ).format(project.startTime);
      endDateController.text = DateFormat(
        'dd/MM/yyyy',
      ).format(project.deadline);
      selectedStartDate = project.startTime;
      selectedEndDate = project.deadline;
      mainColor = project.mainColor ?? "FF03A9F4";
      usersString = project.members ?? [];
      _loadUsersFromIds(usersString);
      _listenProjectTasks(project.id);
    } else if (widget.initialDraft != null) {
      _applyInitialDraft(widget.initialDraft!);
      if (owner != null && owner!.isNotEmpty) {
        _loadUsersFromIds([owner!]);
      }
    } else if (owner != null && owner!.isNotEmpty) {
      _loadUsersFromIds([owner!]);
    }
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    nameController.dispose();
    descriptionController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  void _loadUsersFromIds(List<String> ids) {
    if (ids.isEmpty) return;

    isLoadingUsers = true;
    userLoadError = null;

    accController
        .getUsersFromIds(ids)
        .then((fetchedUsers) {
          if (!mounted) return;

          setState(() {
            users = fetchedUsers;
            isLoadingUsers = false;
          });
        })
        .catchError((_) {
          if (!mounted) return;

          setState(() {
            users = [];
            isLoadingUsers = false;
            userLoadError = "Không thể tải danh sách nhân sự";
          });
        });
  }

  void _listenProjectTasks(String projectId) {
    if (projectId.trim().isEmpty) return;

    isLoadingTasks = true;
    taskLoadError = null;

    _taskSubscription = taskController
        .getTasksByProject(projectId)
        .listen(
          (fetchedTasks) {
            if (!mounted) return;

            setState(() {
              tasks = fetchedTasks;
              isLoadingTasks = false;
              taskLoadError = null;
            });
          },
          onError: (_) {
            if (!mounted) return;

            setState(() {
              tasks = [];
              isLoadingTasks = false;
              taskLoadError = "Không thể tải danh sách công việc";
            });
          },
        );
  }

  void _applyInitialDraft(AiProjectDraft draft) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final durationDays = draft.durationDays.clamp(1, 365).toInt();
    final endDate = startDate.add(Duration(days: durationDays));
    final ownerId = owner?.trim() ?? "";

    nameController.text = draft.name;
    descriptionController.text = draft.description;
    selectedStartDate = startDate;
    selectedEndDate = endDate;
    startDateController.text = DateFormat('dd/MM/yyyy').format(startDate);
    endDateController.text = DateFormat('dd/MM/yyyy').format(endDate);

    tasks = draft.tasks.map((taskDraft) {
      final offset = taskDraft.offsetDays.clamp(0, durationDays).toInt();
      return TaskModel.empty().copyWith(
        title: taskDraft.title,
        description: taskDraft.description,
        deadline: startDate.add(Duration(days: offset)),
        priority: taskDraft.priority,
        status: "todo",
        ownerId: ownerId,
        assigneeId: ownerId,
        dependsOnTaskID: const [],
      );
    }).toList();
  }

  Future<void> pickDate({
    required TextEditingController controller,
    required Function(DateTime) onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(picked);
        onSelected(picked);
      });
    }
  }

  String toHex(Color color) {
    return color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  Color parseColor(String color) {
    final rawColor = color.trim();
    final hex = rawColor.startsWith("#") ? rawColor.substring(1) : rawColor;
    final normalizedHex = hex.length == 6 ? "FF$hex" : hex;
    final value = int.tryParse(normalizedHex, radix: 16);
    return Color(value ?? 0xFF03A9F4);
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  bool _hasMember(UserModel user) {
    final email = _normalizeEmail(user.email);

    return users.any((member) {
      final memberEmail = _normalizeEmail(member.email);
      return member.uid == user.uid ||
          (email.isNotEmpty && memberEmail == email);
    });
  }

  void _addMember(UserModel user) {
    if (isArchivedProject) {
      _showSubmitError("Dự án đã lưu trữ, không thể chỉnh sửa.");
      return;
    }

    if (_hasMember(user)) {
      snack(
        context,
        message: "Người này đã có trong danh sách nhân sự",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
      return;
    }

    setState(() {
      users.add(user);
    });
  }

  void _removeMember(UserModel user) {
    if (isArchivedProject) {
      _showSubmitError("Dự án đã lưu trữ, không thể chỉnh sửa.");
      return;
    }

    if (user.uid == protectedOwnerId) {
      snack(
        context,
        message: "Không thể xóa chủ dự án khỏi danh sách nhân sự",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
      return;
    }

    final assignedTasks = tasks
        .where((task) => task.assigneeId.trim() == user.uid.trim())
        .toList();

    if (assignedTasks.isNotEmpty) {
      final taskNames = assignedTasks.map((task) => task.title).join(", ");
      _showSubmitError(
        "Không thể xóa nhân sự này vì đang được giao các công việc: $taskNames. Vui lòng đổi người phụ trách trước khi xóa.",
      );
      return;
    }

    final email = _normalizeEmail(user.email);

    setState(() {
      users.removeWhere((member) {
        final memberEmail = _normalizeEmail(member.email);
        return member.uid == user.uid ||
            (email.isNotEmpty && memberEmail == email);
      });
    });
  }

  void showMemberForm() {
    showAppModal(
      context: context,
      title: "Thêm nhân sự",
      initialSize: 0.65,
      maxSize: 0.85,
      child: _MemberSearchModal(
        selectedMembers: users,
        onUserSelected: _addMember,
      ),
      listButtons: padding(
        right: 10,
        top: 10,
        bottom: 10,
        child: align(
          alignment: Alignment.bottomRight,
          child: button(
            label: "Xong",
            onPressed: () => Navigator.pop(context),
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  String? _avatarUrl(UserModel user) {
    final photoUrl = user.photoUrl.trim();
    return photoUrl.isEmpty ? null : photoUrl;
  }

  Widget memberAvatarItem(UserModel user) {
    final isOwner = user.uid == protectedOwnerId;
    final canRemove = !isOwner && (!isEdit || canEditProject);

    return containerBox(
      width: 95,
      margin: const EdgeInsets.only(right: 10),
      child: column(
        mainAxisSize: MainAxisSize.min,
        children: [
          stack(
            children: [
              align(
                alignment: Alignment.center,
                child: pressable(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => showUserProfileSheet(
                    context,
                    userId: user.uid,
                    projectId: widget.project?.id,
                  ),
                  child: avatar(
                    imageUrl: _avatarUrl(user),
                    child: const Icon(Icons.person, color: Colors.grey),
                    backgroundColor: const Color.fromARGB(115, 237, 245, 255),
                    radius: 26,
                  ),
                ),
              ),
              positioned(
                top: 0,
                right: 18,
                child: pressable(
                  onTap: canRemove ? () => _removeMember(user) : null,
                  child: containerBox(
                    width: 20,
                    height: 20,
                    radius: BorderRadius.circular(10),
                    color: canRemove
                        ? const Color.fromARGB(255, 220, 55, 55)
                        : const Color.fromARGB(255, 180, 180, 180),
                    child: icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          box(height: 6),
          pressable(
            onTap: () => showUserProfileSheet(
              context,
              userId: user.uid,
              projectId: widget.project?.id,
            ),
            child: text(
              user.name.isEmpty ? user.email : user.name,
              size: 12,
              weight: FontWeight.w500,
              align: TextAlign.center,
              maxLines: 1,
            ),
          ),
          text(
            isOwner ? "Chủ dự án" : user.email,
            size: 10,
            color: const Color.fromARGB(255, 85, 85, 85),
            align: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  void _showSubmitError(String message) {
    snack(
      context,
      message: message,
      backgroundColor: const Color.fromARGB(255, 136, 9, 0),
    );
  }

  List<String> _selectedMemberIds(String ownerId) {
    final memberIds = <String>{ownerId};

    for (final user in users) {
      final uid = user.uid.trim();
      if (uid.isNotEmpty) {
        memberIds.add(uid);
      }
    }

    return memberIds.toList();
  }

  List<TaskModel>? _validatedTasks(String ownerId) {
    final result = <TaskModel>[];

    for (final task in tasks) {
      if (task.title.trim().isEmpty) {
        _showSubmitError("Tên công việc không được để trống");
        return null;
      }

      result.add(
        task.copyWith(
          ownerId: task.ownerId.trim().isEmpty ? ownerId : task.ownerId,
          assigneeId: task.assigneeId.trim().isEmpty
              ? ownerId
              : task.assigneeId,
        ),
      );
    }

    return result;
  }

  List<TaskModel> get visibleTasks {
    return tasks.where((task) {
      switch (taskArchiveFilter) {
        case "Đã lưu trữ":
          return task.isArchived;
        case "Tất cả":
          return true;
        case "Đang hoạt động":
        default:
          return !task.isArchived;
      }
    }).toList();
  }

  bool _validateProjectFields() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return false;
    }

    final startTime = selectedStartDate;
    final deadline = selectedEndDate;

    if (startTime == null) {
      _showSubmitError("Ngày bắt đầu không hợp lệ");
      return false;
    }

    if (deadline == null) {
      _showSubmitError("Deadline không hợp lệ");
      return false;
    }

    if (startTime.isAfter(deadline)) {
      _showSubmitError("Ngày bắt đầu không được sau deadline");
      return false;
    }

    return true;
  }

  void _showProjectSaveError(Object error, String fallbackMessage) {
    if (error is FirebaseException && error.code == "permission-denied") {
      _showSubmitError("Bạn không có quyền cập nhật dự án này");
      return;
    }

    _showSubmitError(fallbackMessage);
  }

  void _showTaskSaveError(Object error, String fallbackMessage) {
    final message = error.toString().toLowerCase();

    if ((error is FirebaseException && error.code == "permission-denied") ||
        message.contains("permission-denied")) {
      _showSubmitError(
        "Bạn không có quyền thao tác với công việc trong dự án này",
      );
      return;
    }

    _showSubmitError(fallbackMessage);
  }

  Future<void> _createTaskForExistingProject(TaskModel taskForm) async {
    final project = widget.project;
    if (project == null) return;

    if (isArchivedProject) {
      _showSubmitError("Dự án đã lưu trữ, không thể chỉnh sửa.");
      return;
    }

    final projectId = project.id.trim();
    if (projectId.isEmpty) {
      _showSubmitError("Không xác định được dự án hiện tại");
      return;
    }

    if (!canEditProject) {
      _showSubmitError("Bạn không có quyền thêm công việc vào dự án này");
      return;
    }

    final taskTitle = taskForm.title.trim();
    if (taskTitle.isEmpty) {
      _showSubmitError("Tên công việc không được để trống");
      return;
    }

    final assigneeId = taskForm.assigneeId.trim();
    if (assigneeId.isEmpty) {
      _showSubmitError("Hãy chọn nhân sự thực hiện công việc");
      return;
    }

    final ownerId = project.ownerId.trim().isNotEmpty
        ? project.ownerId.trim()
        : (owner?.trim() ?? "");
    if (ownerId.isEmpty) {
      _showSubmitError("Không xác định được chủ công việc");
      return;
    }

    final taskId = taskForm.id.trim().isEmpty
        ? FirebaseFirestore.instance.collection("tasks").doc().id
        : taskForm.id.trim();

    final newTask = taskForm.copyWith(
      id: taskId,
      projectId: projectId,
      ownerId: ownerId,
      assigneeId: assigneeId,
      dependsOnTaskID: taskForm.dependsOnTaskID ?? [],
    );

    setState(() {
      isSavingTask = true;
    });

    try {
      final error = await taskController.createTask(task: newTask);
      if (!mounted) return;

      if (error != null) {
        _showTaskSaveError(error, "Thêm công việc thất bại. Vui lòng thử lại");
        return;
      }

      snack(
        context,
        message: "Thêm công việc thành công",
        backgroundColor: Colors.indigo,
      );
    } catch (error) {
      if (mounted) {
        _showTaskSaveError(error, "Thêm công việc thất bại. Vui lòng thử lại");
      }
    } finally {
      if (mounted) {
        setState(() {
          isSavingTask = false;
        });
      }
    }
  }

  Future<void> _updateTaskForExistingProject(
    TaskModel originalTask,
    TaskModel taskForm,
  ) async {
    final project = widget.project;
    if (project == null) return;

    if (isArchivedProject || originalTask.isArchived) {
      _showSubmitError(
        "Công việc đã lưu trữ hoặc dự án đã lưu trữ, không thể chỉnh sửa.",
      );
      return;
    }

    if (!canEditProject) {
      _showSubmitError("Bạn không có quyền cập nhật công việc trong dự án này");
      return;
    }

    final assigneeId = taskForm.assigneeId.trim();
    if (assigneeId.isEmpty) {
      _showSubmitError("Hãy chọn nhân sự thực hiện công việc");
      return;
    }

    final ownerId = originalTask.ownerId.trim().isNotEmpty
        ? originalTask.ownerId.trim()
        : project.ownerId.trim();

    if (ownerId.isEmpty) {
      _showSubmitError("Không xác định được chủ công việc");
      return;
    }

    final updatedTask = originalTask.copyWith(
      title: taskForm.title.trim(),
      description: taskForm.description.trim(),
      deadline: taskForm.deadline,
      assigneeId: assigneeId,
      dependsOnTaskID: taskForm.dependsOnTaskID ?? [],
      priority: taskForm.priority,
      projectId: originalTask.projectId ?? project.id,
      ownerId: ownerId,
      status: originalTask.status,
      createdAt: originalTask.createdAt,
      updatedAt: originalTask.updatedAt,
    );

    setState(() {
      isSavingTask = true;
    });

    try {
      final error = await taskController.updateTask(updatedTask);
      if (!mounted) return;

      if (error != null) {
        _showTaskSaveError(
          error,
          "Cập nhật công việc thất bại. Vui lòng thử lại",
        );
        return;
      }

      snack(
        context,
        message: "Cập nhật công việc thành công",
        backgroundColor: Colors.indigo,
      );
    } catch (error) {
      if (mounted) {
        _showTaskSaveError(
          error,
          "Cập nhật công việc thất bại. Vui lòng thử lại",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSavingTask = false;
        });
      }
    }
  }

  void _deleteTask(TaskModel task) {
    if (isArchivedProject || task.isArchived) {
      _showSubmitError(
        "Công việc đã lưu trữ hoặc dự án đã lưu trữ, không thể xóa.",
      );
      return;
    }

    final dependentTasks = tasks
        .where((item) => (item.dependsOnTaskID ?? []).contains(task.id))
        .toList();

    if (dependentTasks.isNotEmpty) {
      final names = dependentTasks.map((item) => item.title).join(", ");
      _showSubmitError(
        "Không thể xóa công việc này vì đang được phụ thuộc bởi: $names",
      );
      return;
    }

    if (!isEdit) {
      setState(() {
        tasks.removeWhere((item) => item.id == task.id);
      });
      return;
    }

    if (!canEditProject) {
      _showSubmitError("Bạn không có quyền xóa công việc trong dự án này");
      return;
    }

    dialog(
      context,
      title: "Xác nhận xóa công việc",
      message:
          "Công việc không thể khôi phục sau khi xóa. Nhấn xóa để tiếp tục.",
      okText: "Xóa",
      okColor: Colors.red,
      onOk: () => _deleteTaskFromFirestore(task),
    );
  }

  Future<void> _deleteTaskFromFirestore(TaskModel task) async {
    setState(() {
      isSavingTask = true;
    });

    try {
      final error = await taskController.deleteTask(task.id);
      if (!mounted) return;

      if (error != null) {
        _showTaskSaveError(error, "Xóa công việc thất bại. Vui lòng thử lại");
        return;
      }

      snack(
        context,
        message: "Xóa công việc thành công",
        backgroundColor: Colors.indigo,
      );
    } catch (error) {
      if (mounted) {
        _showTaskSaveError(error, "Xóa công việc thất bại. Vui lòng thử lại");
      }
    } finally {
      if (mounted) {
        setState(() {
          isSavingTask = false;
        });
      }
    }
  }

  bool _isDone(TaskModel task) => task.status.trim().toLowerCase() == "done";

  Future<void> _setTaskArchived(TaskModel task, bool archived) async {
    if (isArchivedProject) {
      _showSubmitError("Dự án đã lưu trữ, không thể chỉnh sửa.");
      return;
    }

    if (!canEditProject) {
      _showSubmitError(
        "Bạn không có quyền thao tác với công việc trong dự án này",
      );
      return;
    }

    if (archived && !_isDone(task)) {
      _showSubmitError("Chỉ có thể lưu trữ công việc đã hoàn thành.");
      return;
    }

    setState(() {
      isSavingTask = true;
    });

    try {
      final error = archived
          ? await taskController.archiveTask(task, owner?.trim() ?? "")
          : await taskController.unarchiveTask(task);

      if (!mounted) return;

      if (error != null) {
        _showTaskSaveError(
          error,
          archived
              ? "Lưu trữ công việc thất bại. Vui lòng thử lại"
              : "Khôi phục công việc thất bại. Vui lòng thử lại",
        );
        return;
      }

      snack(
        context,
        message: archived ? "Đã lưu trữ công việc" : "Đã khôi phục công việc",
        backgroundColor: Colors.indigo,
      );
    } catch (error) {
      if (mounted) {
        _showTaskSaveError(
          error,
          archived
              ? "Lưu trữ công việc thất bại. Vui lòng thử lại"
              : "Khôi phục công việc thất bại. Vui lòng thử lại",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSavingTask = false;
        });
      }
    }
  }

  Future<bool> submitProject() async {
    if (isSubmitting) return false;

    if (isEdit) {
      return _updateProject();
    }

    final ownerId = owner;
    if (ownerId == null || ownerId.isEmpty) {
      _showSubmitError("Không xác định được người dùng hiện tại");
      return false;
    }

    if (!_validateProjectFields()) {
      return false;
    }

    final startTime = selectedStartDate!;
    final deadline = selectedEndDate!;

    final validTasks = _validatedTasks(ownerId);
    if (validTasks == null) return false;

    final project = ProjectModel(
      id: "",
      name: nameController.text.trim(),
      description: descriptionController.text.trim(),
      mainColor: mainColor,
      startTime: startTime,
      deadline: deadline,
      ownerId: ownerId,
      members: _selectedMemberIds(ownerId),
      createdAt: null,
      updatedAt: null,
      isArchived: widget.project?.isArchived ?? false,
    );

    setState(() {
      isSubmitting = true;
    });

    var shouldResetSubmitting = true;

    try {
      await projectController.createProjectWithTasks(
        project: project,
        tasks: validTasks,
      );

      if (mounted) {
        shouldResetSubmitting = false;
        snack(
          context,
          message: "Tạo dự án thành công",
          backgroundColor: Colors.indigo,
        );
        Navigator.pop(context);
      }

      return true;
    } catch (error) {
      if (mounted) {
        _showProjectSaveError(error, "Tạo dự án thất bại. Vui lòng thử lại");
      }
      return false;
    } finally {
      if (shouldResetSubmitting && mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _updateProject() async {
    final currentProject = widget.project;
    if (currentProject == null) return false;

    if (currentProject.isArchived) {
      _showSubmitError("Dự án đã lưu trữ, không thể chỉnh sửa.");
      return false;
    }

    if (!canEditProject) {
      _showSubmitError("Bạn không có quyền cập nhật dự án này");
      return false;
    }

    final ownerId = currentProject.ownerId.trim();
    if (ownerId.isEmpty) {
      _showSubmitError("Không xác định được chủ dự án");
      return false;
    }

    if (!_validateProjectFields()) {
      return false;
    }

    final members = _selectedMemberIds(ownerId);
    if (!members.contains(ownerId)) {
      _showSubmitError("Danh sách nhân sự phải có chủ dự án");
      return false;
    }

    final updatedProject = currentProject.copyWith(
      name: nameController.text.trim(),
      description: descriptionController.text.trim(),
      mainColor: mainColor,
      startTime: selectedStartDate!,
      deadline: selectedEndDate!,
      ownerId: ownerId,
      members: members,
      createdAt: currentProject.createdAt,
      updatedAt: currentProject.updatedAt,
      isArchived: currentProject.isArchived,
    );

    setState(() {
      isSubmitting = true;
    });

    var shouldResetSubmitting = true;

    try {
      await projectController.updateProjectInfo(updatedProject);

      if (mounted) {
        shouldResetSubmitting = false;
        snack(
          context,
          message: "Cập nhật dự án thành công",
          backgroundColor: Colors.indigo,
        );
        Navigator.pop(context);
      }

      return true;
    } catch (error) {
      if (mounted) {
        _showProjectSaveError(
          error,
          "Cập nhật dự án thất bại. Vui lòng thử lại",
        );
      }
      return false;
    } finally {
      if (shouldResetSubmitting && mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isArchivedProject) ...[
            containerBox(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              radius: BorderRadius.circular(AppRadius.md),
              color: AppColors.warningSoft,
              border: Border.all(color: const Color(0xFFFFE3B0)),
              child: row(
                children: [
                  icon(Icons.archive_outlined, color: AppColors.warning),
                  box(width: 8),
                  flexible(
                    child: text(
                      "Dự án đã lưu trữ. Bạn chỉ có thể xem thông tin, không thể chỉnh sửa.",
                      maxLines: 3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            box(height: 16),
          ],
          if (hasInitialDraft) ...[
            containerBox(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              radius: BorderRadius.circular(AppRadius.md),
              color: AppColors.primarySoft,
              border: Border.all(color: const Color(0xFFD8E8FF)),
              child: row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon(Icons.auto_awesome, color: AppColors.primary),
                  box(width: 8),
                  flexible(
                    child: text(
                      "Các công việc AI gợi ý đang được giao mặc định cho bạn. Hãy chỉnh lại nhân sự phụ trách nếu cần.",
                      maxLines: 4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            box(height: 16),
          ],
          formInput(
            controller: nameController,
            isEnabled: canEditProject,
            label: "Tên dự án",
            hint: "VD: Lập trình app ToDo",
            prefixIcon: Icons.work,
            validator: (v) => v == null || v.isEmpty
                ? "Tên dự án không được để trống!"
                : null,
          ),

          box(height: 20),

          formInput(
            controller: descriptionController,
            isEnabled: canEditProject,
            label: "Mô tả dự án",
            hint: "Hãy mô tả về dự án của bạn",
            prefixIcon: Icons.description,
            maxLines: 5,
            validator: (v) =>
                v == null || v.isEmpty ? "Hãy mô tả dự án!" : null,
          ),
          box(height: 20),

          GestureDetector(
            onTap: canEditProject
                ? () => pickDate(
                    controller: startDateController,
                    onSelected: (d) => selectedStartDate = d,
                  )
                : null,
            child: AbsorbPointer(
              child: formInput(
                controller: startDateController,
                label: "Ngày bắt đầu",
                hint: "Chọn ngày",
                prefixIcon: Icons.calendar_month,
                validator: (v) =>
                    v == null || v.isEmpty ? "Hãy chọn ngày bắt đầu!" : null,
              ),
            ),
          ),

          box(height: 20),

          GestureDetector(
            onTap: canEditProject
                ? () => pickDate(
                    controller: endDateController,
                    onSelected: (d) => selectedEndDate = d,
                  )
                : null,
            child: AbsorbPointer(
              child: formInput(
                controller: endDateController,
                label: "Hạn hoàn thành",
                hint: "Chọn ngày",
                prefixIcon: Icons.calendar_month,
                validator: (v) =>
                    v == null || v.isEmpty ? "Hãy chọn hạn hoàn thành!" : null,
              ),
            ),
          ),

          box(height: 20),

          row(
            children: [
              text("Màu chủ đạo:"),
              box(width: 10),
              flexible(
                child: pressable(
                  child: containerBox(
                    radius: BorderRadius.circular(10),
                    color: parseColor(mainColor),
                    height: 30,
                  ),
                  onTap: canEditProject
                      ? () {
                          showAppModal(
                            context: context,
                            title: "Chọn màu dự án",
                            initialSize: 0.7,
                            child: Column(
                              children: [
                                ColorPicker(
                                  pickerColor: parseColor(mainColor),
                                  enableAlpha: false,
                                  displayThumbColor: true,
                                  onColorChanged: (color) {
                                    setState(() {
                                      mainColor = toHex(color);
                                    });
                                  },
                                ),

                                box(height: 10),

                                button(
                                  label: "Xong",
                                  onPressed: () => Navigator.pop(context),
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ],
          ), // row

          box(height: 20),

          row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              text("Danh sách nhân sự:"),

              if (!isEdit || canEditProject)
                button(
                  label: "+ Nhân sự",
                  height: 35,
                  color: const Color.fromARGB(255, 216, 240, 255),
                  onPressed: showMemberForm,
                ), // button
            ],
          ), // row

          box(height: 8),

          dropdown<String>(
            list: const ["Đang hoạt động", "Đã lưu trữ", "Tất cả"],
            value: taskArchiveFilter,
            fillColor: Colors.white,
            borderRadius: 12,
            hint: "Bộ lọc công việc",
            onChanged: (value) {
              setState(() {
                taskArchiveFilter = value ?? "Đang hoạt động";
              });
            },
          ),

          box(height: 8),

          containerBox(
            width: double.infinity,
            height: 115,
            color: const Color.fromARGB(255, 211, 225, 247),
            radius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey, width: 1),
            child: padding(
              top: 10,
              bottom: 8,
              left: 10,
              right: 10,
              child: isLoadingUsers
                  ? loading()
                  : userLoadError != null
                  ? align(
                      child: text(
                        userLoadError!,
                        color: const Color.fromARGB(255, 136, 9, 0),
                      ),
                    )
                  : users.isEmpty
                  ? align(
                      child: text(
                        "Chưa có nhân sự nào",
                        color: const Color.fromARGB(255, 90, 90, 90),
                      ),
                    )
                  : scroll(
                      direction: Axis.horizontal,
                      child: row(
                        children: [
                          for (int i = 0; i < users.length; i++)
                            memberAvatarItem(users[i]),
                        ],
                      ),
                    ),
            ), // padding
          ), // containerBox

          box(height: 20),

          row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              text("Danh sách công việc:"),

              if (!isEdit || canEditProject)
                button(
                  label: isSavingTask ? "Đang lưu..." : "+ Công việc",
                  height: 35,
                  color: isSavingTask
                      ? const Color.fromARGB(255, 190, 190, 190)
                      : const Color.fromARGB(255, 224, 224, 224),
                  onPressed: () {
                    if (isSavingTask) return;
                    if (isEdit && isLoadingUsers) {
                      _showSubmitError(
                        "Vui lòng chờ tải danh sách nhân sự trước khi thêm công việc",
                      );
                      return;
                    }

                    showTaskForm(users: users, tasks: tasks);
                  },
                ), // button
            ],
          ), // row

          box(height: 5),

          containerBox(
            width: double.infinity,
            height: 200,
            color: const Color.fromARGB(255, 164, 181, 209),
            radius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey, width: 1),
            child: padding(
              top: 2,
              child: isLoadingTasks
                  ? loading()
                  : taskLoadError != null
                  ? align(
                      child: text(
                        taskLoadError!,
                        color: const Color.fromARGB(255, 136, 9, 0),
                      ),
                    )
                  : visibleTasks.isEmpty
                  ? align(
                      child: text(
                        "Chưa có công việc nào",
                        color: const Color.fromARGB(255, 90, 90, 90),
                      ),
                    )
                  : list(
                      children: [
                        for (int i = 0; i < visibleTasks.length; i++) ...[
                          cardCongViec(task: visibleTasks[i]),
                        ],
                      ],
                    ), // list
            ), // padding
          ), // containerBox

          if (isSubmitting || isSavingTask) ...[box(height: 12), loading()],
        ],
      ),
    );
  }

  void showTaskForm({
    TaskModel? task,
    required List<UserModel> users,
    required List<TaskModel> tasks,
  }) {
    if (isArchivedProject || task?.isArchived == true) {
      if (task != null) {
        _showTaskReadOnlyDetail(task);
      } else {
        _showSubmitError("Dự án đã lưu trữ, không thể chỉnh sửa.");
      }
      return;
    }

    bool isCreate = task == null;

    showAppModal(
      context: context,
      maxSize: 0.8,
      title: isCreate ? "Thêm công việc mới" : "Cập nhật công việc",
      child: TaskForm(
        key: taskKey,
        task: task,
        users: users,
        tasks: tasks,
        doneForm: (taskForm) {
          if (isEdit) {
            if (isCreate) {
              _createTaskForExistingProject(taskForm);
            } else {
              _updateTaskForExistingProject(task, taskForm);
            }
            return;
          }

          setState(() {
            if (isCreate) {
              tasks.add(taskForm);
            } else {
              final index = tasks.indexWhere((item) => item.id == task.id);
              if (index >= 0) {
                tasks[index] = taskForm;
              }
            }
          });
        },
      ),

      listButtons: padding(
        right: 10,
        top: 10,
        bottom: 10,
        child: align(
          alignment: Alignment.bottomRight,
          child: row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              button(
                label: isCreate ? "Thêm" : "Cập nhật",
                onPressed: () {
                  taskKey.currentState?.returnForm();
                },
                color: isCreate
                    ? Colors.blue
                    : const Color.fromARGB(255, 204, 204, 204),
              ),
              box(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskReadOnlyDetail(TaskModel task) {
    showAppModal(
      context: context,
      title: "Chi tiết công việc",
      initialSize: 0.5,
      child: column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text(task.title, size: 18, weight: FontWeight.bold, maxLines: 2),
          box(height: 10),
          text(
            task.description.isEmpty ? "Không có mô tả" : task.description,
            maxLines: 8,
            color: AppColors.textSecondary,
          ),
          box(height: 12),
          text("Deadline: ${DateFormat('dd/MM/yyyy').format(task.deadline)}"),
          box(height: 6),
          text(
            "Trạng thái: ${_isDone(task) ? "Đã hoàn thành" : "Chưa hoàn thành"}",
          ),
          if (task.isArchived) ...[
            box(height: 8),
            containerBox(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              radius: BorderRadius.circular(AppRadius.sm),
              color: AppColors.surfaceMuted,
              child: text(
                "Đã lưu trữ",
                color: AppColors.textSecondary,
                weight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget cardCongViec({required TaskModel task}) {
    return card(
      child: padding(
        top: 10,
        bottom: 10,
        left: 10,
        right: 10,

        child: row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            flexible(
              child: pressable(
                child: column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text(
                      "Tên: ${task.title}",
                      weight: FontWeight.bold,
                      size: 16,
                    ),

                    if (task.isArchived) ...[
                      box(height: 4),
                      containerBox(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        radius: BorderRadius.circular(AppRadius.sm),
                        color: const Color(0xFFE8ECF2),
                        child: text(
                          "Đã lưu trữ",
                          size: 11,
                          color: AppColors.textSecondary,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],

                    box(height: 5),

                    text(
                      "Mô tả: ${task.description}",
                      weight: FontWeight.normal,
                      size: 14,
                      overflow: TextOverflow.ellipsis,
                    ),

                    box(height: 5),

                    text(
                      "Hạn deadline: ${DateFormat('dd/MM/yyyy').format(task.deadline)}",
                      weight: FontWeight.normal,
                      size: 14,
                    ),
                  ],
                ), // column

                onTap: () {
                  if ((!isEdit || canEditProject) && !task.isArchived) {
                    showTaskForm(task: task, users: users, tasks: tasks);
                  } else {
                    _showTaskReadOnlyDetail(task);
                  }
                },
              ), // pressable
            ), // flexible

            if (canEditProject && !task.isArchived)
              pressable(
                child: icon(
                  Icons.archive_outlined,
                  color: _isDone(task) ? AppColors.primary : Colors.grey,
                  size: 20,
                ),
                onTap: () => _setTaskArchived(task, true),
              ),

            if (canEditProject && task.isArchived)
              pressable(
                child: icon(
                  Icons.unarchive_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onTap: () => _setTaskArchived(task, false),
              ),

            if ((!isEdit || canEditProject) && !task.isArchived)
              pressable(
                child: icon(Icons.delete, color: Colors.red, size: 20),
                onTap: () {
                  _deleteTask(task);
                },
              ),
          ],
        ), // row
      ),
    );
  }

  Widget cardNhanSu({required UserModel user}) {
    return card(
      radius: BorderRadius.circular(25),
      child: padding(
        top: 5,
        bottom: 5,
        left: 5,
        right: 5,

        child: row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            pressable(
              child: row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar(
                    imageUrl: user.photoUrl,
                    child: Icon(Icons.person, color: Colors.grey),
                    backgroundColor: const Color.fromARGB(115, 237, 245, 255),
                    radius: 20,
                  ), // avatar

                  box(width: 10),

                  text(user.name, size: 18),
                ],
              ), // row

              onTap: () {},
            ), // pressable

            pressable(
              child: icon(
                Icons.delete,
                color: user.uid == protectedOwnerId ? Colors.grey : Colors.red,
                size: 20,
              ),
              onTap: user.uid == protectedOwnerId
                  ? null
                  : () {
                      dialog(
                        context,
                        title: "Xác nhận xóa nhân sự",
                        message:
                            "Bạn chắc chắn muốn xóa người này khỏi dự án! Nhấn xóa để tiếp tục!",
                        onOk: () {
                          // setState(() {
                          //   tasks.remove(task);
                          // });
                        },
                        okText: "Xóa",
                      );
                    },
            ),
          ],
        ), // row
      ),
    );
  }
}

class _MemberSearchModal extends StatefulWidget {
  final List<UserModel> selectedMembers;
  final ValueChanged<UserModel> onUserSelected;

  const _MemberSearchModal({
    required this.selectedMembers,
    required this.onUserSelected,
  });

  @override
  State<_MemberSearchModal> createState() => _MemberSearchModalState();
}

class _MemberSearchModalState extends State<_MemberSearchModal> {
  final emailController = TextEditingController();
  final accController = AccountController();
  final friendController = FriendController();

  bool isSearching = false;
  UserModel? foundUser;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  bool _hasSelectedEmail(String email) {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) return false;

    return widget.selectedMembers.any(
      (member) => _normalizeEmail(member.email) == normalizedEmail,
    );
  }

  bool _hasSelectedUser(UserModel user) {
    final email = _normalizeEmail(user.email);

    return widget.selectedMembers.any((member) {
      final memberEmail = _normalizeEmail(member.email);
      return member.uid == user.uid ||
          (email.isNotEmpty && memberEmail == email);
    });
  }

  Future<void> searchUser() async {
    final email = _normalizeEmail(emailController.text);

    if (email.isEmpty) {
      snack(
        context,
        message: "Vui lòng nhập email cần tìm",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
      return;
    }

    if (_hasSelectedEmail(email)) {
      setState(() {
        foundUser = null;
      });
      snack(
        context,
        message: "Người này đã có trong danh sách nhân sự",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
      return;
    }

    setState(() {
      isSearching = true;
      foundUser = null;
    });

    UserModel? user;
    try {
      user = await accController.findUserByEmail(email);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isSearching = false;
      });

      snack(
        context,
        message: "Không thể tìm nhân sự lúc này",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      isSearching = false;
      foundUser = user;
    });

    if (user == null) {
      snack(
        context,
        message: "Không tìm thấy người dùng với email này",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
      return;
    }

    if (_hasSelectedUser(user)) {
      setState(() {
        foundUser = null;
      });
      snack(
        context,
        message: "Người này đã có trong danh sách nhân sự",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
    }
  }

  void selectUser(UserModel user) {
    if (_hasSelectedUser(user)) {
      snack(
        context,
        message: "Người này đã có trong danh sách nhân sự",
        backgroundColor: const Color.fromARGB(255, 136, 9, 0),
      );
      return;
    }

    widget.onUserSelected(user);

    setState(() {
      foundUser = null;
      emailController.clear();
    });

    snack(
      context,
      message: "Đã thêm nhân sự vào danh sách",
      backgroundColor: Colors.indigo,
    );
  }

  String? _avatarUrl(UserModel user) {
    final photoUrl = user.photoUrl.trim();
    return photoUrl.isEmpty ? null : photoUrl;
  }

  Widget searchResultCard(UserModel user) {
    return card(
      child: padding(
        all: 10,
        child: row(
          children: [
            avatar(
              imageUrl: _avatarUrl(user),
              child: const Icon(Icons.person, color: Colors.grey),
              backgroundColor: const Color.fromARGB(115, 237, 245, 255),
            ),
            box(width: 10),
            flexible(
              child: column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text(
                    user.name.isEmpty ? user.email : user.name,
                    weight: FontWeight.bold,
                    size: 15,
                  ),
                  text(
                    user.email,
                    size: 13,
                    color: const Color.fromARGB(255, 90, 90, 90),
                  ),
                ],
              ),
            ),
            button(
              label: "Chọn",
              height: 36,
              color: const Color.fromARGB(255, 216, 240, 255),
              onPressed: () => selectUser(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget friendList() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.trim().isEmpty) {
      return text(
        "Đăng nhập để xem danh sách bạn bè.",
        size: 13,
        color: AppColors.textSecondary,
      );
    }

    return StreamBuilder<List<UserModel>>(
      stream: friendController.streamFriends(currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loading(size: 20);
        }

        if (snapshot.hasError) {
          return text(
            "Không thể tải danh sách bạn bè lúc này.",
            size: 13,
            color: AppColors.danger,
            maxLines: 2,
          );
        }

        final friends = (snapshot.data ?? <UserModel>[])
            .where((friend) => !_hasSelectedUser(friend))
            .toList();

        if (friends.isEmpty) {
          return text(
            "Chưa có bạn bè phù hợp để thêm. Bạn vẫn có thể tìm nhân sự bằng email.",
            size: 13,
            color: AppColors.textSecondary,
            maxLines: 3,
          );
        }

        return column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final friend in friends)
              containerBox(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                radius: BorderRadius.circular(AppRadius.md),
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                child: row(
                  children: [
                    pressable(
                      onTap: () =>
                          showUserProfileSheet(context, userId: friend.uid),
                      child: avatar(
                        imageUrl: _avatarUrl(friend),
                        child: const Icon(Icons.person, color: Colors.grey),
                        backgroundColor: const Color.fromARGB(
                          115,
                          237,
                          245,
                          255,
                        ),
                      ),
                    ),
                    box(width: 10),
                    flexible(
                      child: pressable(
                        onTap: () =>
                            showUserProfileSheet(context, userId: friend.uid),
                        child: column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text(
                              friend.name.isEmpty ? friend.email : friend.name,
                              weight: FontWeight.bold,
                              size: 14,
                              maxLines: 1,
                            ),
                            text(
                              friend.email,
                              size: 12,
                              color: AppColors.textSecondary,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    button(
                      label: "Thêm",
                      height: 34,
                      color: AppColors.primarySoft,
                      onPressed: () => selectUser(friend),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        formInput(
          controller: emailController,
          label: "Email nhân sự",
          hint: "example@gmail.com",
          prefixIcon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
          onChanged: (_) {
            if (foundUser != null) {
              setState(() {
                foundUser = null;
              });
            }
          },
        ),
        box(height: 12),
        button(
          label: isSearching ? "Đang tìm..." : "Tìm",
          width: double.infinity,
          color: isSearching
              ? const Color.fromARGB(255, 190, 190, 190)
              : Colors.blue,
          textColor: Colors.white,
          onPressed: () {
            if (!isSearching) {
              searchUser();
            }
          },
        ),
        box(height: 16),
        if (isSearching) loading(),
        if (foundUser != null) searchResultCard(foundUser!),
        box(height: 16),
        text("Bạn bè", size: 15, weight: FontWeight.bold),
        box(height: 8),
        friendList(),
      ],
    );
  }
}
