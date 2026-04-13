import 'package:firebase_auth/firebase_auth.dart';

import '../../../backend/auth/auth_repository.dart';
import '../../../backend/shared/domain_types.dart';
import '../models/auth_user.dart';

class AuthController {
  AuthController({AuthRepository? repository}) : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  Stream<User?> authStateChanges() => _repository.authStateChanges();

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) =>
      _repository.register(name: name, email: email, password: password, phone: phone, role: role);

  Future<void> login({required String email, required String password}) =>
      _repository.login(email: email, password: password);

  Future<void> logout() => _repository.logout();
}
