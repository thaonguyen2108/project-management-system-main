import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/models/project.dart';
import 'package:todo/models/task.dart';

class ProjectService {
  final _projectRef = FirebaseFirestore.instance.collection("projects");
  final _taskRef = FirebaseFirestore.instance.collection("tasks");

  Future<void> createProject(ProjectModel project) async {
    final docRef = _projectRef.doc(); // Firebase tự sinh ID
    final newProject = project.copyWith(id: docRef.id);

    await docRef.set(newProject.toJson());
  }

  Future<ProjectModel?> getProjectById(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) return null;

    final doc = await _projectRef.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;

    return ProjectModel.fromJson({...data, "id": doc.id});
  }

  Future<String> createProjectWithTasks(
    ProjectModel project,
    List<TaskModel> tasks,
  ) async {
    final projectRef = _projectRef.doc();
    final projectId = projectRef.id;
    final newProject = project.copyWith(id: projectId);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(projectRef, newProject.toJson());

    for (final task in tasks) {
      final taskId = task.id.trim().isEmpty ? _taskRef.doc().id : task.id;
      final taskWithProject = task.copyWith(id: taskId, projectId: projectId);

      batch.set(_taskRef.doc(taskId), taskWithProject.toJson());
    }

    await batch.commit();
    return projectId;
  }

  Future<List<ProjectModel>> getProjectsByUser(String uid) async {
    final snapshot = await _projectRef
        .where("members", arrayContains: uid)
        .get();

    return snapshot.docs
        .map((doc) => ProjectModel.fromJson({...doc.data(), "id": doc.id}))
        .toList();
  }

  Stream<List<ProjectModel>> streamProjectsByOwner(
    String uid, {
    bool? isArchived,
  }) {
    Query<Map<String, dynamic>> query = _projectRef.where(
      "ownerId",
      isEqualTo: uid,
    );

    if (isArchived != null) {
      query = query.where("isArchived", isEqualTo: isArchived);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ProjectModel.fromJson({...doc.data(), "id": doc.id}))
          .toList(),
    );
  }

  Stream<List<ProjectModel>> streamProjectsByUser(String uid) {
    return _projectRef
        .where("members", arrayContains: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ProjectModel.fromJson({...doc.data(), "id": doc.id}),
              )
              .toList(),
        );
  }

  Future<void> updateProject(ProjectModel project) async {
    final data = project.toJson();
    if (project.createdAt == null) {
      data.remove("createdAt");
    }

    await _projectRef.doc(project.id).set(data, SetOptions(merge: true));
  }

  Future<void> updateArchiveStatus(String projectId, bool isArchived) async {
    await _projectRef.doc(projectId).update({
      "isArchived": isArchived,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProject(String id) async {
    await _projectRef.doc(id).delete();
  }
}
