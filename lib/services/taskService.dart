import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/models/task.dart';

class TaskService {
  final _taskRef = FirebaseFirestore.instance.collection("tasks");

  Future<void> createTask(TaskModel task) async {
    await _taskRef.doc(task.id).set(task.toJson());
  }

  Future<TaskModel?> getTaskById(String taskId) async {
    final id = taskId.trim();
    if (id.isEmpty) return null;

    final doc = await _taskRef.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;

    return TaskModel.fromJson({...data, "id": doc.id});
  }

  Stream<List<TaskModel>> getTasksByProject(String projectId) {
    return _taskRef
        .where("projectId", isEqualTo: projectId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromJson({...doc.data(), "id": doc.id}))
              .toList(),
        );
  }

  // Dùng batch để lưu nhiều task cùng lúc
  Future<void> createMultipleTasks(List<TaskModel> tasks) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var task in tasks) {
      var ref = _taskRef.doc(task.id);
      batch.set(ref, task.toJson());
    }

    await batch.commit();
  }

  Stream<List<TaskModel>> getTasksByUser(String userUId) {
    return _taskRef
        .where("assigneeId", isEqualTo: userUId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromJson({...doc.data(), "id": doc.id}))
              .toList(),
        );
  }

  Future<void> updateTask(TaskModel task) async {
    final data = task.toJson();
    if (task.createdAt == null) {
      data.remove("createdAt");
    }

    await _taskRef.doc(task.id).update(data);
  }

  Future<void> markDone(String taskId) async {
    await _taskRef.doc(taskId).update({
      "status": "done",
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTaskArchive({
    required String taskId,
    required bool isArchived,
    String? archivedBy,
  }) async {
    await _taskRef.doc(taskId).update({
      "isArchived": isArchived,
      "archivedAt": isArchived ? FieldValue.serverTimestamp() : null,
      "archivedBy": isArchived ? archivedBy : null,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(String id) async {
    await _taskRef.doc(id).delete();
  }
}
