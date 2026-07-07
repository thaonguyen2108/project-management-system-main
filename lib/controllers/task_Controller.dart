import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/models/task.dart';
import 'package:todo/services/notificationService.dart';
import 'package:todo/services/taskService.dart';

class TaskController {
  final TaskService _taskService = TaskService();
  final NotificationService _notificationService = NotificationService();

  Future<String?> createTask({required TaskModel task}) async {
    try {
      await _taskService.createTask(task);
      await _ignoreNotificationFailure(() {
        return _notificationService.createTaskAssignedNotification(
          task: task,
          actorId: _actorId(fallback: task.ownerId),
        );
      });

      return null; // success
    } on Exception catch (e) {
      return "Create task failed: $e";
    } catch (e) {
      return "Unknown error: $e";
    }
  }

  Stream<List<TaskModel>> getTasksByProject(String projectId) {
    try {
      return _taskService.getTasksByProject(projectId);
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<TaskModel>> getTasksByUser(String uid) {
    try {
      return _taskService.getTasksByUser(uid);
    } catch (e) {
      rethrow;
    }
  }

  Future<TaskModel?> getTaskById(String taskId) {
    return _taskService.getTaskById(taskId);
  }

  Future<String?> updateTask(TaskModel task) async {
    try {
      await _taskService.updateTask(task);
      await _ignoreNotificationFailure(() {
        return _notificationService.createTaskUpdatedNotification(
          task: task,
          actorId: _actorId(fallback: task.ownerId),
        );
      });

      return null;
    } on Exception catch (e) {
      return "Update task failed: $e";
    } catch (e) {
      return "Unknown error: $e";
    }
  }

  Future<String?> markDone(TaskModel task) async {
    try {
      await _taskService.markDone(task.id);
      await _ignoreNotificationFailure(() {
        return _notificationService.createTaskDoneNotification(
          task: task,
          actorId: _actorId(fallback: task.assigneeId),
        );
      });

      return null;
    } catch (e) {
      return "Mark done failed: $e";
    }
  }

  Future<String?> archiveTask(TaskModel task, String archivedBy) async {
    try {
      await _taskService.updateTaskArchive(
        taskId: task.id,
        isArchived: true,
        archivedBy: archivedBy,
      );

      return null;
    } catch (e) {
      return "Archive task failed: $e";
    }
  }

  Future<String?> unarchiveTask(TaskModel task) async {
    try {
      await _taskService.updateTaskArchive(taskId: task.id, isArchived: false);

      return null;
    } catch (e) {
      return "Unarchive task failed: $e";
    }
  }

  Future<String?> deleteTask(String taskId) async {
    try {
      await _taskService.deleteTask(taskId);
      return null;
    } catch (e) {
      return "Delete task failed: $e";
    }
  }

  Future<List<TaskModel>> getTasksFromIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      // Tạo futures
      final futures = ids.map((id) async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('tasks')
              .doc(id)
              .get();

          if (!doc.exists || doc.data() == null) return null;

          final data = doc.data()!;
          data['id'] = doc.id;

          return doc.exists ? TaskModel.fromJson(data) : null;
        } catch (e) {
          // Log lỗi riêng cho từng ID
          print("⚠️ Lỗi khi lấy task $id: $e");
          return null;
        }
      }).toList();

      // Chạy song song
      final results = await Future.wait(futures);

      // Lọc null
      final tasks = results.nonNulls.toList();

      print("✅ Lấy được ${tasks.length}/${ids.length} tasks");
      return tasks;
    } catch (e, stackTrace) {
      print("❌ Lỗi hệ thống: $e");
      print("Stack: $stackTrace");
      return [];
    }
  }

  String _actorId({required String fallback}) {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid != null && uid.isNotEmpty) return uid;
    return fallback.trim();
  }

  Future<void> _ignoreNotificationFailure(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      // Notification creation must not roll back the primary task action.
    }
  }
}
