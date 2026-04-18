import 'package:flutter/material.dart';

import '../../../../routing/app_router.dart';
import '../../../../shared/enums/account_status.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../state/app_state.dart';
import '../../../profile/models/profile_user.dart';

/// Admin-only screen. Lists all users filtered by account status.
class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppState.instance.isAdmin) {
      return const Center(child: Text('Access denied.'));
    }
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final users = AppState.instance.users;

        // Exclude admin accounts — admins should not be managed from this screen.
        List<ProfileUser> byStatus(AccountStatus s) => users
            .where((u) => u.accountStatus == s && u.role != UserRole.admin)
            .toList();

        return Column(
          children: [
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: [
                _StatusTab('Active',
                    byStatus(AccountStatus.active).length, Colors.green),
                _StatusTab('Restricted',
                    byStatus(AccountStatus.restricted).length, Colors.orange),
                _StatusTab('Pending',
                    byStatus(AccountStatus.pendingVerification).length,
                    Colors.blue),
                _StatusTab('Deactivated',
                    byStatus(AccountStatus.deactivated).length, Colors.red),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _UserList(users: byStatus(AccountStatus.active)),
                  _UserList(users: byStatus(AccountStatus.restricted)),
                  _UserList(users: byStatus(AccountStatus.pendingVerification)),
                  _UserList(users: byStatus(AccountStatus.deactivated)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusTab extends Tab {
  _StatusTab(String label, int count, Color color)
      : super(
          child: Row(
            children: [
              Text(label),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users});
  final List<ProfileUser> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
          child: Text('No users in this category.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final user = users[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child:
                  Text(user.displayName[0].toUpperCase()),
            ),
            title: Text(user.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user.email,
                style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoleBadge(user.role),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.adminUserDetail,
              arguments: {'userId': user.uid, 'showActions': true},
            ),
          ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.role);
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => Colors.purple,
      UserRole.freelancer => Colors.blue,
      UserRole.client => Colors.teal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(role.displayName,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
