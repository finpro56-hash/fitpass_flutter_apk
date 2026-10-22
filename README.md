# FitProgress Gym Manager — Flutter + Supabase

A mobile-first Flutter app scaffold connected to the Supabase project configured for FitProgress. Includes email/password authentication, gym creation (first signed-in creator becomes admin), role-aware navigation, member listing for admins, attendance recording, workout and diet plan creation, and payment recording for admins. Database access is enforced with Postgres row-level security (RLS).

## Stack
- Flutter / Dart
- `supabase_flutter` for Supabase Auth and Postgres API
- PostgreSQL with RLS; India timezone (`Asia/Kolkata`) and INR defaults

## Run locally
1. Install Flutter stable and Android Studio/Android SDK.
2. In this directory, run:
   ```bash
   flutter pub get
   flutter run --dart-define=SUPABASE_URL=https://obzlhgbpfiagkgzrckab.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
   ```
3. Do not put a Supabase `service_role` key in the app. The publishable key is designed for client apps; RLS is the security boundary.
4. In Supabase Auth settings, configure email/password sign-in and the email confirmation policy appropriate for your rollout. Test signup and login with real accounts.

## Initial gym setup
1. Create an account and sign in.
2. Enter the gym name and tap **Create gym as admin**. No setup secret is required.
3. Add user accounts through Supabase Auth (or implement your chosen invite flow), then have the gym admin assign each account a role. The database provides admin-only RPCs `fp_admin_add_member` and `fp_assign_trainer` for that operation; these require the target user UUID and must only be invoked by an authenticated admin.

## Current roles and boundaries
- **Admin:** gym overview, member list, attendance, workout plans, read-only diet plan view, payments and payment recording.
- **Trainer:** assigned-client attendance and workout/diet plan management; access is limited by assignment.
- **Client:** own attendance, workout/diet plans, and own payment records; clients cannot list other clients.
- Diet plans: client can create their own; trainer can create for an assigned client; admin has read-only access.
- Time: UI shows India local time for attendance display; database defaults use `Asia/Kolkata`.

## Important implementation notes
- This is a working starter/MVP, not yet a fully launch-certified production release.
- Admin member listing exists, but a polished in-app invitation/role assignment screen is not yet implemented. Use Supabase Auth to create the account and admin-only RPCs to attach the account to a gym and assign a trainer.
- Workout exercise detail entry and per-set workout session logging are represented in the schema but not yet exposed as complete UI flows.
- Payment records are manual records only; no payment gateway is integrated.
- Before production, test each role with separate real test accounts, add account recovery and invite flows, review all RLS policies, add automated integration tests, and build/sign the Android release.

## Supabase schema
The connected Supabase project has these tables with RLS enabled: `profiles`, `gyms`, `gym_memberships`, `trainer_client_assignments`, `attendance`, `workout_plans`, `workout_exercises`, `workout_sessions`, `workout_set_logs`, `diet_plans`, `diet_meals`, and `payments`.

Database RPCs:
- `fp_create_gym(p_name text)` — create gym and grant creator admin membership.
- `fp_admin_add_member(p_gym_id uuid, p_user_id uuid, p_role gym_role)` — admin adds/updates a trainer/client membership.
- `fp_assign_trainer(p_gym_id uuid, p_trainer uuid, p_client uuid)` — admin assigns a trainer to a client.

## Build APK
After installing Flutter and Android SDK:
```bash
flutter build apk --release --dart-define=SUPABASE_URL=https://obzlhgbpfiagkgzrckab.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```
APK output: `build/app/outputs/flutter-apk/app-release.apk`.

## Repository contents
- `lib/main.dart` — application and role-aware screens
- `supabase/migrations/` — schema migration source

## Build an installable APK using GitHub Actions
1. Push this folder to a GitHub repository with `fitprogress_flutter/` at the repository root, or adjust the workflow's `working-directory` if you move its contents to the root.
2. In repository **Settings → Secrets and variables → Actions**, add secret `SUPABASE_PUBLISHABLE_KEY` containing the Supabase publishable/anon key. Optionally add variable `SUPABASE_URL`; the workflow defaults to this project's URL.
3. Open **Actions → Build installable Android APK → Run workflow** (or push to `main`/`master`). The workflow runs `flutter analyze` before compiling.
4. When the workflow succeeds, open its run, scroll to **Artifacts**, and download `FitProgress-Android-APK`. Extract the ZIP; `app-release.apk` is the installable Android package.
5. On Android, open the APK and allow installation from that source if prompted. This is an unsigned-by-your-own-key test/release APK; for public distribution, configure a private Android signing key and sign the release build.

Never use a Supabase service-role key in the app. The APK contains the publishable key, so database RLS policies remain essential.
