import '../../../backend/projects/projects_repository.dart';
import '../models/milestone_item.dart';

class TransactionsController {
  TransactionsController({ProjectsRepository? repository}) : _repository = repository ?? ProjectsRepository();

  final ProjectsRepository _repository;

  Stream<List<MilestoneItem>> streamMilestones(String projectId) => _repository.streamMilestones(projectId);

  Future<String> createMilestone(MilestoneItem milestone) => _repository.createMilestone(milestone);

  Future<void> updateMilestone(MilestoneItem milestone) => _repository.updateMilestone(milestone);

  Future<void> deleteMilestone(MilestoneItem milestone) => _repository.deleteMilestone(milestone);

  Future<void> approveMilestone({
    required String milestoneId,
    required String signatureUrl,
    required String paymentToken,
  }) =>
      _repository.approveMilestone(
        milestoneId: milestoneId,
        signatureUrl: signatureUrl,
        paymentToken: paymentToken,
      );
}
