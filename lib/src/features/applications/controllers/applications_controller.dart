import '../../../backend/applications/applications_repository.dart';
import '../models/application_item.dart';

class ApplicationsController {
  ApplicationsController({ApplicationsRepository? repository}) : _repository = repository ?? ApplicationsRepository();

  final ApplicationsRepository _repository;

  Future<String> submitApplication(ApplicationItem application) => _repository.submitApplication(application);

  Stream<List<ApplicationItem>> streamApplicationsForJob(String jobId) => _repository.streamApplicationsForJob(jobId);

  Future<void> updateApplication(ApplicationItem application) => _repository.updateApplication(application);

  Future<void> withdrawApplication(String applicationId) => _repository.withdrawApplication(applicationId);

  Future<void> acceptApplication({
    required String applicationId,
    required String jobId,
    required String clientId,
  }) =>
      _repository.acceptApplication(applicationId: applicationId, jobId: jobId, clientId: clientId);
}
