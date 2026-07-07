import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';
import 'package:todo/services/notificationService.dart';
import 'package:todo/services/projectService.dart';

class ProjectController {
  final ProjectService _projectService = ProjectService();
  final NotificationService _notificationService = NotificationService();

  Future<void> createProject({required ProjectModel project}) async {
    try {
      await _projectService.createProject(project);
    } catch (e) {
      print("Create project error: $e");
      rethrow;
    }
  }

  Future<String> createProjectWithTasks({
    required ProjectModel project,
    required List<TaskModel> tasks,
  }) async {
    final projectId = await _projectService.createProjectWithTasks(
      project,
      tasks,
    );

    final actorId = _actorId(fallback: project.ownerId);
    await Future.wait(
      tasks.map((task) {
        return _ignoreNotificationFailure(() {
          return _notificationService.createTaskAssignedNotification(
            task: task.copyWith(projectId: projectId),
            actorId: actorId,
          );
        });
      }),
    );

    return projectId;
  }

  Future<ProjectModel?> getProjectById(String projectId) {
    return _projectService.getProjectById(projectId);
  }

  Stream<List<ProjectModel>> getMyProjects(String uid, {bool? isArchived}) {
    return _projectService.streamProjectsByOwner(uid, isArchived: isArchived);
  }

  Future<void> updateProjectInfo(ProjectModel project) async {
    try {
      await _projectService.updateProject(project);
    } catch (e) {
      print("Update project error: $e");
      rethrow;
    }
  }

  Future<void> archiveProject(ProjectModel project) async {
    try {
      final archivedProject = project.copyWith(isArchived: true);
      await _projectService.updateProject(archivedProject);
      await _ignoreNotificationFailure(() {
        return _notificationService.createProjectArchivedNotifications(
          project: archivedProject,
          actorId: _actorId(fallback: project.ownerId),
        );
      });
    } catch (e) {
      print("Archive project error: $e");
      rethrow;
    }
  }

  Future<void> unarchiveProject(ProjectModel project) async {
    try {
      final restoredProject = project.copyWith(isArchived: false);
      await _projectService.updateArchiveStatus(project.id, false);
      await _ignoreNotificationFailure(() {
        return _notificationService.createProjectUnarchivedNotifications(
          project: restoredProject,
          actorId: _actorId(fallback: project.ownerId),
        );
      });
    } catch (e) {
      print("Unarchive project error: $e");
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _projectService.deleteProject(projectId);
    } catch (e) {
      print("Delete project error: $e");
      rethrow;
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
      // Notification creation must not roll back the primary project action.
    }
  }
}
