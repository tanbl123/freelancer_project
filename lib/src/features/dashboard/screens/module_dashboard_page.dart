import 'package:flutter/material.dart';
import 'package:freelancer_project/src/widgets/module_menu_card.dart';
import '../../../routing/app_router.dart';

class ModuleDashboardPage extends StatelessWidget {
  const ModuleDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Module Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tap a module to preview the UI flow.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            const Text(
              'Core Modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            ModuleMenuCard(
              title: 'Marketplace',
              subtitle: 'Browse jobs/services and create post screens',
              icon: Icons.storefront,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.marketplace,
              ),
            ),
            ModuleMenuCard(
              title: 'Applications',
              subtitle: 'Freelancer proposals and client applicant list',
              icon: Icons.description,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.applications,
              ),
            ),
            ModuleMenuCard(
              title: 'Transactions',
              subtitle: 'Project milestones and progress tracking',
              icon: Icons.assignment_turned_in,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.transactions,
              ),
            ),
            ModuleMenuCard(
              title: 'Review and Ratings',
              subtitle: 'Review form and rating summary',
              icon: Icons.star,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.ratings,
              ),
            ),
            ModuleMenuCard(
              title: 'User Profile',
              subtitle: 'View and edit account information',
              icon: Icons.person,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.profile,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Additional UI Screens',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            ModuleMenuCard(
              title: 'Chat List',
              subtitle: 'Message inbox and active conversations',
              icon: Icons.chat_bubble_outline,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.chatList,
              ),
            ),
            ModuleMenuCard(
              title: 'Chat Detail',
              subtitle: 'Project chat, file sharing, and call placeholders',
              icon: Icons.forum_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.chatDetail,
              ),
            ),
            ModuleMenuCard(
              title: 'Application Form',
              subtitle: 'Submit proposal, budget, timeline, and resume',
              icon: Icons.send_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.applicationForm,
              ),
            ),
            ModuleMenuCard(
              title: 'My Posts',
              subtitle: 'Manage your job requests and service offerings',
              icon: Icons.folder_open_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.myPosts,
              ),
            ),
            ModuleMenuCard(
              title: 'Edit Post',
              subtitle: 'Update title, description, budget, and deadline',
              icon: Icons.edit_note_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.editPost,
              ),
            ),
            ModuleMenuCard(
              title: 'Milestone Detail',
              subtitle: 'View deliverables and approval status',
              icon: Icons.task_alt_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.milestoneDetail,
              ),
            ),
            ModuleMenuCard(
              title: 'Deliverable Submission',
              subtitle: 'Submit milestone files and notes',
              icon: Icons.upload_file_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.deliverableSubmission,
              ),
            ),
            ModuleMenuCard(
              title: 'Signature Approval',
              subtitle: 'Client signature pad placeholder screen',
              icon: Icons.draw_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.signatureApproval,
              ),
            ),
            ModuleMenuCard(
              title: 'Payment Simulation',
              subtitle: 'Stripe sandbox payment mock screen',
              icon: Icons.payment_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.paymentSimulation,
              ),
            ),
            ModuleMenuCard(
              title: 'Review List',
              subtitle: 'View all reviews and ratings',
              icon: Icons.reviews_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.reviewList,
              ),
            ),
            ModuleMenuCard(
              title: 'Edit Review',
              subtitle: 'Update rating and feedback',
              icon: Icons.rate_review_outlined,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.editReview,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}