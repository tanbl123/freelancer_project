# Freelancer Service Marketplace Application

This Flutter project now includes a **backend foundation** for Firebase + SQLite,
so your existing UI can be connected module by module.

## Implemented in this update

- Firebase bootstrap entry point (`FirebaseBootstrap`) wired in `main.dart`.
- Domain enums for roles, post types, application/milestone/order statuses.
- Expanded data models for:
  - Marketplace posts
  - Applications
  - Milestones
  - Reviews
  - Auth user profile
- Repository layer with business rules:
  - Marketplace CRUD + offline latest-20 job cache in SQLite
  - Applications CRUD + anti-duplicate apply + closed-job guard + accept-and-lock flow
  - Milestones CRUD + lock-on-approval behavior
  - Reviews CRUD + completed-project verification + rating aggregation
  - Auth register/login/logout with Firebase Auth + Firestore profile document
- Controller layer now delegates to repositories and is ready for UI integration.

## Firebase collections (proposed)

- `users`
- `jobs`
- `services`
- `applications`
- `projects`
- `milestones`
- `reviews`

## Important setup still required

1. Run `flutterfire configure` and wire `firebase_options.dart`.
2. Set `FirebaseBootstrap.isEnabled` to `true` after configuration.
3. Create Firestore composite indexes for queries that combine `where` + `orderBy`.
4. Add Firestore Security Rules for ownership + role checks.
5. Connect UI form screens to controllers/repositories.

## Suggested next implementation order

1. Authentication + user profile
2. Marketplace posting + feed + cache fallback
3. Job applications (realtime stream)
4. Acceptance → project order + milestones
5. Milestone approval (signature + Stripe sandbox token)
6. Ratings + analytics + profile share

