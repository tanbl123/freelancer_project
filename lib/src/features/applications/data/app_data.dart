import '../models/models.dart';

class AppData {
  static final List<JobPost> jobs = [
    JobPost(
      title: 'Need Mobile App UI Designer',
      budget: 800,
      deadline: '20 Mar 2026',
      skills: ['Flutter', 'Figma', 'UI/UX'],
      owner: 'Aina Studio',
      description: 'Design 8 modern screens for a freelancer marketplace app.',
    ),
    JobPost(
      title: 'Build Landing Page for Portfolio',
      budget: 450,
      deadline: '18 Mar 2026',
      skills: ['Web Design', 'HTML', 'CSS'],
      owner: 'Pixel Lab',
      description: 'Need a responsive portfolio website for a creative freelancer.',
    ),
    JobPost(
      title: 'Social Media Video Editor',
      budget: 600,
      deadline: '25 Mar 2026',
      skills: ['CapCut', 'Premiere Pro'],
      owner: 'Nova Media',
      description: 'Edit short-form reels for brand awareness campaign.',
    ),
  ];

  static final List<ServicePost> services = [
    ServicePost(
      title: 'Flutter Mobile App UI Design',
      price: 500,
      owner: 'Nur Aisyah',
      rating: 4.9,
      description: 'Clean and modern Android and iOS app interface design.',
    ),
    ServicePost(
      title: 'Logo & Brand Identity Package',
      price: 350,
      owner: 'Ken Creative',
      rating: 4.8,
      description: 'Professional logo, colour palette and branding guide.',
    ),
    ServicePost(
      title: 'Voice Over for Product Videos',
      price: 280,
      owner: 'Dhiya Audio',
      rating: 4.7,
      description: 'Clear bilingual voice over for commercial and social videos.',
    ),
  ];

  static final List<Milestone> milestones = [
    Milestone(
      title: 'Draft 1 UI Screens',
      amount: 200,
      deadline: '12 Mar 2026',
      status: 'In Progress',
      description: 'Submit first draft of home, details and profile screens.',
    ),
    Milestone(
      title: 'Final Revisions',
      amount: 300,
      deadline: '18 Mar 2026',
      status: 'Pending Review',
      description: 'Apply client feedback and prepare final design files.',
    ),
  ];
}
