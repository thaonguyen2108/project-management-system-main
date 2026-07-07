import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/models/notification.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';

class NotificationService {
  final _notificationRef = FirebaseFirestore.instance.collection(
    "notifications",
  );

  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _notificationRef
        .where("receiverId", isEqualTo: uid)
        .where("isDeleted", isEqualTo: false)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    NotificationModel.fromJson({...doc.data(), "id": doc.id}),
              )
              .toList(),
        );
  }

  Stream<int> streamUnreadCount(String uid) {
    return _notificationRef
        .where("receiverId", isEqualTo: uid)
        .where("isRead", isEqualTo: false)
        .where("isDeleted", isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<void> createNotification(NotificationModel notification) async {
    final docRef = notification.id.trim().isEmpty
        ? _notificationRef.doc()
        : _notificationRef.doc(notification.id.trim());
    final data = notification.copyWith(id: docRef.id);

    await docRef.set(data.toJson(useServerCreatedAt: data.createdAt == null));
  }

  Future<void> markAsRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;

    await _notificationRef.doc(id).update({
      "isRead": true,
      "readAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead(String uid) async {
    final snapshot = await _notificationRef
        .where("receiverId", isEqualTo: uid)
        .where("isRead", isEqualTo: false)
        .where("isDeleted", isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        "isRead": true,
        "readAt": FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> softDelete(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;

    await _notificationRef.doc(id).update({
      "isDeleted": true,
      "deletedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> createTaskAssignedNotification({
    required TaskModel task,
    required String actorId,
  }) {
    final receiverId = task.assigneeId.trim();
    final normalizedActorId = actorId.trim();
    if (receiverId.isEmpty || receiverId == normalizedActorId) {
      return Future.value();
    }

    return createNotification(
      NotificationModel(
        id: "",
        receiverId: receiverId,
        type: "task_assigned",
        title: "Bạn được giao công việc mới",
        body: "Công việc: ${_safeTaskTitle(task)}",
        targetType: "task",
        targetId: task.id,
        taskId: task.id,
        projectId: task.projectId,
        actorId: normalizedActorId.isEmpty ? null : normalizedActorId,
      ),
    );
  }

  Future<void> createTaskUpdatedNotification({
    required TaskModel task,
    required String actorId,
  }) {
    final receiverId = task.assigneeId.trim();
    final normalizedActorId = actorId.trim();
    if (receiverId.isEmpty || receiverId == normalizedActorId) {
      return Future.value();
    }

    return createNotification(
      NotificationModel(
        id: "",
        receiverId: receiverId,
        type: "task_updated",
        title: "Công việc đã được cập nhật",
        body: "Công việc: ${_safeTaskTitle(task)}",
        targetType: "task",
        targetId: task.id,
        taskId: task.id,
        projectId: task.projectId,
        actorId: normalizedActorId.isEmpty ? null : normalizedActorId,
      ),
    );
  }

  Future<void> createTaskDoneNotification({
    required TaskModel task,
    required String actorId,
  }) {
    final receiverId = task.ownerId.trim();
    final normalizedActorId = actorId.trim();
    if (receiverId.isEmpty || receiverId == normalizedActorId) {
      return Future.value();
    }

    return createNotification(
      NotificationModel(
        id: "",
        receiverId: receiverId,
        type: "task_done",
        title: "Công việc đã hoàn thành",
        body: "${_safeTaskTitle(task)} đã được đánh dấu hoàn thành.",
        targetType: "task",
        targetId: task.id,
        taskId: task.id,
        projectId: task.projectId,
        actorId: normalizedActorId.isEmpty ? null : normalizedActorId,
      ),
    );
  }

  Future<void> createProjectArchivedNotifications({
    required ProjectModel project,
    required String actorId,
  }) {
    return _createProjectNotifications(
      project: project,
      actorId: actorId,
      type: "project_archived",
      title: "Dự án đã được lưu trữ",
    );
  }

  Future<void> createProjectUnarchivedNotifications({
    required ProjectModel project,
    required String actorId,
  }) {
    return _createProjectNotifications(
      project: project,
      actorId: actorId,
      type: "project_unarchived",
      title: "Dự án đã được khôi phục",
    );
  }

  Future<void> createFriendRequestNotification({
    required String requestId,
    required String senderId,
    required String receiverId,
    required String senderName,
  }) {
    final normalizedReceiverId = receiverId.trim();
    final normalizedSenderId = senderId.trim();
    if (normalizedReceiverId.isEmpty ||
        normalizedSenderId.isEmpty ||
        normalizedReceiverId == normalizedSenderId) {
      return Future.value();
    }

    final safeName = senderName.trim().isEmpty ? "Một người dùng" : senderName;

    return createNotification(
      NotificationModel(
        id: "",
        receiverId: normalizedReceiverId,
        type: "friend_request",
        title: "Bạn có lời mời kết bạn mới",
        body: "$safeName đã gửi lời mời kết bạn cho bạn.",
        targetType: "friend_request",
        targetId: requestId,
        actorId: normalizedSenderId,
      ),
    );
  }

  Future<void> createFriendRequestAcceptedNotification({
    required String receiverId,
    required String actorId,
    required String actorName,
  }) {
    final normalizedReceiverId = receiverId.trim();
    final normalizedActorId = actorId.trim();
    if (normalizedReceiverId.isEmpty ||
        normalizedActorId.isEmpty ||
        normalizedReceiverId == normalizedActorId) {
      return Future.value();
    }

    final safeName = actorName.trim().isEmpty ? "Người dùng" : actorName;

    return createNotification(
      NotificationModel(
        id: "",
        receiverId: normalizedReceiverId,
        type: "friend_request_accepted",
        title: "Lời mời kết bạn đã được chấp nhận",
        body: "$safeName đã chấp nhận lời mời kết bạn của bạn.",
        targetType: "user",
        targetId: normalizedActorId,
        actorId: normalizedActorId,
      ),
    );
  }

  Future<void> createChatMessageNotification({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
  }) {
    final normalizedConversationId = conversationId.trim();
    final normalizedSenderId = senderId.trim();
    final normalizedReceiverId = receiverId.trim();
    if (normalizedConversationId.isEmpty ||
        normalizedSenderId.isEmpty ||
        normalizedReceiverId.isEmpty ||
        normalizedSenderId == normalizedReceiverId) {
      return Future.value();
    }

    final body = _shortText(text);

    return createNotification(
      NotificationModel(
        id: "",
        receiverId: normalizedReceiverId,
        type: "chat_message",
        title: "Tin nhắn mới",
        body: body.isEmpty ? "Bạn có một tin nhắn mới." : body,
        targetType: "conversation",
        targetId: normalizedConversationId,
        actorId: normalizedSenderId,
      ),
    );
  }

  Future<void> _createProjectNotifications({
    required ProjectModel project,
    required String actorId,
    required String type,
    required String title,
  }) async {
    final normalizedActorId = actorId.trim();
    final receivers = <String>{...?project.members}
      ..removeWhere(
        (uid) => uid.trim().isEmpty || uid.trim() == normalizedActorId,
      );

    if (receivers.isEmpty) return;

    await Future.wait(
      receivers.map((receiverId) {
        return createNotification(
          NotificationModel(
            id: "",
            receiverId: receiverId.trim(),
            type: type,
            title: title,
            body: "Dự án: ${_safeProjectName(project)}",
            targetType: "project",
            targetId: project.id,
            projectId: project.id,
            actorId: normalizedActorId.isEmpty ? null : normalizedActorId,
          ),
        );
      }),
    );
  }

  String _safeTaskTitle(TaskModel task) {
    final title = task.title.trim();
    return title.isEmpty ? "Công việc chưa đặt tên" : title;
  }

  String _safeProjectName(ProjectModel project) {
    final name = project.name.trim();
    return name.isEmpty ? "Dự án chưa đặt tên" : name;
  }

  String _shortText(String text) {
    final normalized = text.trim().replaceAll(RegExp(r"\s+"), " ");
    if (normalized.length <= 80) return normalized;
    return "${normalized.substring(0, 77)}...";
  }
}
