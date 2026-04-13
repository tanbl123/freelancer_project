import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/transactions/models/milestone_item.dart';
import '../shared/domain_types.dart';
import '../shared/firestore_paths.dart';

class ProjectsRepository {
  ProjectsRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _milestones =>
      _firestore.collection(FirestorePaths.milestones);

  Stream<List<MilestoneItem>> streamMilestones(String projectId) {
    return _milestones
        .where('projectId', isEqualTo: projectId)
        .orderBy('deadline')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MilestoneItem.fromFirestore).toList());
  }

  Future<String> createMilestone(MilestoneItem milestone) async {
    final ref = await _milestones.add(milestone.toFirestore());
    return ref.id;
  }

  Future<void> updateMilestone(MilestoneItem milestone) async {
    if (milestone.isLocked) {
      throw StateError('Approved milestones are locked.');
    }
    await _milestones.doc(milestone.id).update(milestone.toFirestore());
  }

  Future<void> deleteMilestone(MilestoneItem milestone) async {
    if (milestone.isLocked) {
      throw StateError('Approved milestones are locked and cannot be deleted.');
    }

    await _milestones.doc(milestone.id).delete();
  }

  Future<void> approveMilestone({
    required String milestoneId,
    required String signatureUrl,
    required String paymentToken,
  }) async {
    await _milestones.doc(milestoneId).update({
      'status': MilestoneStatus.locked.name,
      'clientSignatureUrl': signatureUrl,
      'paymentToken': paymentToken,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
