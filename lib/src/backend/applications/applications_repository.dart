import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/applications/models/application_item.dart';
import '../shared/domain_types.dart';
import '../shared/firestore_paths.dart';

class ApplicationsRepository {
  ApplicationsRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _applications =>
      _firestore.collection(FirestorePaths.applications);

  Future<String> submitApplication(ApplicationItem application) async {
    final duplicate = await _applications
        .where('jobId', isEqualTo: application.jobId)
        .where('freelancerId', isEqualTo: application.freelancerId)
        .limit(1)
        .get();

    if (duplicate.docs.isNotEmpty) {
      throw StateError('Freelancer already applied to this job.');
    }

    final jobDoc = await _firestore.collection(FirestorePaths.jobs).doc(application.jobId).get();
    if (!jobDoc.exists) {
      throw StateError('Job does not exist.');
    }
    final job = jobDoc.data()!;
    final isAccepted = job['isAccepted'] as bool? ?? false;
    final deadline = (job['deadline'] as Timestamp?)?.toDate();
    final isExpired = deadline != null && deadline.isBefore(DateTime.now());

    if (isAccepted || isExpired) {
      throw StateError('Applications cannot be submitted to closed jobs.');
    }

    final ref = await _applications.add(application.toFirestore());
    return ref.id;
  }

  Stream<List<ApplicationItem>> streamApplicationsForJob(String jobId) {
    return _applications
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ApplicationItem.fromFirestore).toList());
  }

  Future<void> updateApplication(ApplicationItem application) async {
    if (application.status != ApplicationStatus.pending) {
      throw StateError('Only pending applications can be edited.');
    }
    await _applications.doc(application.id).update(application.toFirestore());
  }

  Future<void> withdrawApplication(String applicationId) async {
    await _applications.doc(applicationId).update({'status': ApplicationStatus.withdrawn.name});
  }

  Future<void> acceptApplication({
    required String applicationId,
    required String jobId,
    required String clientId,
  }) async {
    final acceptedRef = _applications.doc(applicationId);
    final allForJob = await _applications.where('jobId', isEqualTo: jobId).get();

    final batch = _firestore.batch();

    for (final doc in allForJob.docs) {
      batch.update(doc.reference, {
        'status': doc.id == applicationId ? ApplicationStatus.accepted.name : ApplicationStatus.rejected.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(_firestore.collection(FirestorePaths.jobs).doc(jobId), {
      'isAccepted': true,
      'acceptedApplicationId': applicationId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final orderRef = _firestore.collection(FirestorePaths.projects).doc();
    final acceptedData = (await acceptedRef.get()).data()!;
    batch.set(orderRef, {
      'jobId': jobId,
      'clientId': clientId,
      'freelancerId': acceptedData['freelancerId'],
      'applicationId': applicationId,
      'status': OrderStatus.inProgress.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
