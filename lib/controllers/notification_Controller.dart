import 'package:todo/models/notification.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';
import 'package:todo/services/notificationService.dart';

class NotificationController {
  final NotificationService _notificationService = NotificationService();

  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _notificationService.streamNotifications(uid);
  }

  Stream<int> streamUnreadCount(String uid) {
    return _notificationService.streamUnreadCount(uid);
  }

  Future<String?> createNotification(NotificationModel notification) async {
    try {
      await _notificationService.createNotification(notification);
      return null;
    } catch (e) {
      return "Create notification failed: $e";
    }
  }

  Future<String?> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      return null;
    } catch (e) {
      return "Mark notification read failed: $e";
    }
  }

  Future<String?> markAllAsRead(String uid) async {
    try {
      await _notificationService.markAllAsRead(uid);
      return null;
    } catch (e) {
      return "Mark all notifications read failed: $e";
    }
  }

  Future<String?> softDelete(String notificationId) async {
    try {
      await _notificationService.softDelete(notificationId);
      return null;
    } catch (e) {
      return "Delete notification failed: $e";
    }
  }

  Future<void> createTaskAssignedNotification({
    required TaskModel task,
    required String actorId,
  }) {
    return _notificationService.createTaskAssignedNotification(
      task: task,
      actorId: actorId,
    );
  }

  Future<void> createTaskUpdatedNotification({
    required TaskModel task,
    required String actorId,
  }) {
    return _notificationService.createTaskUpdatedNotification(
      task: task,
      actorId: actorId,
    );
  }

  Future<void> createTaskDoneNotification({
    required TaskModel task,
    required String actorId,
  }) {
    return _notificationService.createTaskDoneNotification(
      task: task,
      actorId: actorId,
    );
  }

  Future<void> createProjectArchivedNotifications({
    required ProjectModel project,
    required String actorId,
  }) {
    return _notificationService.createProjectArchivedNotifications(
      project: project,
      actorId: actorId,
    );
  }

  Future<void> createProjectUnarchivedNotifications({
    required ProjectModel project,
    required String actorId,
  }) {
    return _notificationService.createProjectUnarchivedNotifications(
      project: project,
      actorId: actorId,
    );
  }

  Future<void> createFriendRequestNotification({
    required String requestId,
    required String senderId,
    required String receiverId,
    required String senderName,
  }) {
    return _notificationService.createFriendRequestNotification(
      requestId: requestId,
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName,
    );
  }

  Future<void> createFriendRequestAcceptedNotification({
    required String receiverId,
    required String actorId,
    required String actorName,
  }) {
    return _notificationService.createFriendRequestAcceptedNotification(
      receiverId: receiverId,
      actorId: actorId,
      actorName: actorName,
    );
  }
}
