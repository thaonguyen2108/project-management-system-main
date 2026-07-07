import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/app_style.dart';
import 'package:todo/models/task.dart';
import 'package:todo/models/user.dart';
import 'package:todo/widgets/ui.dart';

class TaskForm extends StatefulWidget {
  final Function(TaskModel task)? doneForm;
  final TaskModel? task;
  final List<UserModel>? users;
  final List<TaskModel>? tasks;

  const TaskForm({super.key, this.doneForm, this.task, this.users, this.tasks});

  @override
  State<TaskForm> createState() => TaskFormState();
}

class TaskFormState extends State<TaskForm> {
  final _taskFormKey = GlobalKey<FormState>();

  DateTime? selectedEndDate;
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final endDateController = TextEditingController();

  UserModel? nhanSu;
  bool dependsOnTaskBool = false;
  List<String> dependsOnTask = [];

  bool get isInProject => widget.users != null;
  bool get isEdit => widget.task != null;

  List<TaskModel> get availableTasks => widget.tasks ?? [];

  @override
  void initState() {
    super.initState();

    final task = widget.task;
    if (task == null) return;

    nameController.text = task.title;
    descriptionController.text = task.description;
    selectedEndDate = task.deadline;
    endDateController.text = DateFormat('dd/MM/yyyy').format(task.deadline);

    nhanSu = _findUserById(task.assigneeId);
    dependsOnTask = _sanitizeDependencies(task.dependsOnTaskID ?? []);
    dependsOnTaskBool = dependsOnTask.isNotEmpty;
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  UserModel? _findUserById(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return null;

    for (final user in widget.users ?? <UserModel>[]) {
      if (user.uid == normalizedUid) return user;
    }

    return null;
  }

  TaskModel? _findTaskById(String id) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;

    for (final task in availableTasks) {
      if (task.id == normalizedId) return task;
    }

    return null;
  }

  List<String> _sanitizeDependencies(List<String> ids) {
    final currentId = widget.task?.id;
    final deadline = selectedEndDate;

    return ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != currentId)
        .where((id) {
          final task = _findTaskById(id);
          if (task == null) return false;
          if (deadline == null) return true;
          return !task.deadline.isAfter(deadline);
        })
        .toSet()
        .toList();
  }

  String? _dependencyValidationError({
    required DateTime deadline,
    required List<String> selectedDependencies,
  }) {
    final currentTask = widget.task;

    if (dependsOnTaskBool && selectedDependencies.isEmpty) {
      return "Hãy chọn công việc phụ thuộc hoặc tắt tùy chọn phụ thuộc";
    }

    if (currentTask != null && selectedDependencies.contains(currentTask.id)) {
      return "Công việc không thể phụ thuộc chính nó";
    }

    for (final dependencyId in selectedDependencies) {
      final dependency = _findTaskById(dependencyId);
      if (dependency == null) {
        return "Một công việc phụ thuộc không còn tồn tại";
      }

      if (dependency.deadline.isAfter(deadline)) {
        return "Deadline của công việc phụ thuộc phải trước hoặc bằng deadline hiện tại";
      }

      if (currentTask != null && _reachesTask(dependencyId, currentTask.id)) {
        return "Không thể tạo vòng lặp phụ thuộc giữa các công việc";
      }
    }

    if (currentTask != null) {
      final dependents = availableTasks.where(
        (task) => (task.dependsOnTaskID ?? []).contains(currentTask.id),
      );

      for (final dependent in dependents) {
        if (deadline.isAfter(dependent.deadline)) {
          return "Deadline mới không được sau deadline của công việc đang phụ thuộc vào nó: ${dependent.title}";
        }
      }
    }

    return null;
  }

  bool _reachesTask(String fromTaskId, String targetTaskId) {
    final visited = <String>{};

    bool visit(String id) {
      if (!visited.add(id)) return false;

      final task = _findTaskById(id);
      if (task == null) return false;

      final dependencies = task.id == widget.task?.id
          ? dependsOnTask
          : task.dependsOnTaskID ?? [];

      for (final dependencyId in dependencies) {
        if (dependencyId == targetTaskId) return true;
        if (visit(dependencyId)) return true;
      }

      return false;
    }

    return visit(fromTaskId);
  }

  bool _wouldCreateCycle(String dependencyId) {
    final currentTaskId = widget.task?.id;
    if (currentTaskId == null) return false;
    return _reachesTask(dependencyId, currentTaskId);
  }

  bool _canSelectDependency(TaskModel task) {
    final deadline = selectedEndDate;
    if (deadline == null) return false;
    if (task.id == widget.task?.id) return false;
    if (task.deadline.isAfter(deadline)) return false;
    return !_wouldCreateCycle(task.id);
  }

  void _showFormError(String message) {
    snack(context, message: message, backgroundColor: AppColors.danger);
  }

  void returnForm() {
    final isValid = _taskFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final deadline = selectedEndDate;
    if (deadline == null) {
      _showFormError("Deadline không hợp lệ");
      return;
    }

    final selectedDependencies = dependsOnTaskBool
        ? _sanitizeDependencies(dependsOnTask)
        : <String>[];

    final dependencyError = _dependencyValidationError(
      deadline: deadline,
      selectedDependencies: selectedDependencies,
    );

    if (dependencyError != null) {
      _showFormError(dependencyError);
      return;
    }

    final callback = widget.doneForm;
    if (callback == null) {
      _showFormError("Form công việc chưa có hàm xử lý lưu");
      return;
    }

    final baseTask = widget.task ?? TaskModel.empty();
    final task = baseTask.copyWith(
      title: nameController.text.trim(),
      description: descriptionController.text.trim(),
      deadline: deadline,
      assigneeId: nhanSu?.uid ?? baseTask.assigneeId,
      dependsOnTaskID: selectedDependencies,
      priority: baseTask.priority,
      status: baseTask.status,
      projectId: baseTask.projectId,
      ownerId: baseTask.ownerId,
      createdAt: baseTask.createdAt,
      updatedAt: baseTask.updatedAt,
    );

    callback(task);
    Navigator.pop(context);
  }

  Future<void> pickDate({
    required TextEditingController controller,
    required Function(DateTime) onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;

    if (picked == null) return;

    setState(() {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
      onSelected(picked);
      dependsOnTask = _sanitizeDependencies(dependsOnTask);
      dependsOnTaskBool = dependsOnTask.isNotEmpty && dependsOnTaskBool;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _taskFormKey,
      child: column(
        mainAxisSize: MainAxisSize.min,
        children: [
          formInput(
            controller: nameController,
            label: "Tên công việc",
            hint: "VD: Thiết kế giao diện đăng nhập",
            prefixIcon: Icons.work,
            validator: (v) => v == null || v.trim().isEmpty
                ? "Tên công việc không được để trống!"
                : null,
          ),
          box(height: 18),
          formInput(
            controller: descriptionController,
            label: "Mô tả công việc",
            hint: "Hãy mô tả chi tiết công việc",
            prefixIcon: Icons.description,
            maxLines: 5,
            validator: (v) =>
                v == null || v.trim().isEmpty ? "Hãy mô tả công việc!" : null,
          ),
          box(height: 18),
          GestureDetector(
            onTap: () => pickDate(
              controller: endDateController,
              onSelected: (d) => selectedEndDate = d,
            ),
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
          box(height: 18),
          if (isInProject)
            dropdown<UserModel>(
              value: nhanSu,
              hint: "Chọn nhân sự",
              list: widget.users ?? [],
              validator: (v) => v == null ? "Hãy chọn nhân sự!" : null,
              onChanged: (val) {
                setState(() {
                  nhanSu = val;
                });
              },
              itemBuilder: (user) => row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar(
                    imageUrl: user.photoUrl.trim().isEmpty
                        ? null
                        : user.photoUrl,
                    child: const Icon(Icons.person, color: Colors.grey),
                    backgroundColor: AppColors.primarySoft,
                    radius: 15,
                  ),
                  box(width: 10),
                  flexible(
                    child: text(
                      user.name.isEmpty ? user.email : user.name,
                      size: 16,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          box(height: isInProject ? 10 : 0),
          if (widget.tasks != null)
            toggleTile(
              title: "Phụ thuộc vào công việc khác",
              value: dependsOnTaskBool,
              onChanged: (v) {
                setState(() {
                  dependsOnTaskBool = v;
                  if (!v) dependsOnTask = [];
                });
              },
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey,
            ),
          if (dependsOnTaskBool && dependsOnTask.isEmpty)
            text(
              "Hãy chọn công việc phụ thuộc hoặc tắt tùy chọn này.",
              maxLines: 5,
              color: AppColors.danger,
              size: 12,
            ),
          if (dependsOnTaskBool)
            containerBox(
              width: double.infinity,
              height: 120,
              color: AppColors.primarySoft,
              radius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1),
              child: list(
                children: availableTasks.map((task) {
                  if (task.id == widget.task?.id) return box();

                  final canSelect = _canSelectDependency(task);
                  return checkboxTile(
                    title: task.title,
                    contentPadding: EdgeInsets.zero,
                    value: dependsOnTask.contains(task.id),
                    enalbe: canSelect,
                    activeColor: AppColors.primary,
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          dependsOnTask = {...dependsOnTask, task.id}.toList();
                        } else {
                          dependsOnTask.remove(task.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
