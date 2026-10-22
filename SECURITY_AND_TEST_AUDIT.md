# FitProgress — Role Use Cases, Test Matrix & Security Audit

Audit date: 2026-10-22  
Backend: Supabase project `obzlhgbpfiagkgzrckab`  
Flutter runtime verification: **NOT RUN** (Flutter SDK/Android build tools are not installed in the current build environment).  
Test account setup: **NOT RUN** (no real admin/trainer/client credentials supplied; no demo records were inserted).

## Executive result

**Not ready to certify as correctly wired or production-safe.** The Supabase project is active, and the 12 expected public tables are present with RLS enabled. The Supabase security advisor still reports three warnings for authenticated execution of SECURITY DEFINER RPCs. These RPCs perform role checks in their bodies, but need dedicated abuse tests. The Flutter app is an MVP: some primary actions and relationships are not implemented end-to-end. The checklist below distinguishes inspected/static checks from tests actually executed.

### Checks actually completed

| Check | Result | Evidence / limitation |
|---|---|---|
| Supabase project status | PASS | API reports `ACTIVE_HEALTHY`. |
| Required tables exist | PASS | `profiles`, `gyms`, `gym_memberships`, `trainer_client_assignments`, `attendance`, `workout_plans`, `workout_exercises`, `workout_sessions`, `workout_set_logs`, `diet_plans`, `diet_meals`, `payments` listed. |
| RLS enabled on these tables | PASS | Supabase `list_tables` reports `rls_enabled=true` for all 12. This does not prove every policy is correct. |
| Anonymous execution of exposed SECURITY DEFINER RPCs | IMPROVED / RECHECK | Explicit grants to `anon` and `public` revoked for `fp_create_gym`, `fp_admin_add_member`, `fp_assign_trainer`, and trigger function. Recheck advisor after deployment; no anonymous API request test was run. |
| Authenticated SECURITY DEFINER RPC advisor | WARN | Advisor still lists 3 RPCs; authenticated execution is intended, but authorization-bypass/IDOR tests are required. |
| Flutter compile / analyzer / widget tests | NOT RUN | Flutter executable unavailable in build environment. |
| End-to-end role tests against live data | NOT RUN | Requires separately authenticated test accounts and controlled test gym. |

## Roles and use cases

### Admin

- Create a gym; creator receives admin membership.
- View active members and their roles.
- Assign existing authenticated accounts as trainer/client and assign trainers to clients (RPC exists; complete UI workflow is missing).
- Record attendance for a client in the same gym.
- View gym workout and diet plans. Diet plan changes must be denied to admin (read-only requirement).
- Record/view payment entries for gym clients.
- Must not access another gym unless separately a member/admin there.

### Trainer

- View only clients assigned to that trainer.
- Mark attendance only for assigned clients; client and admin should see that attendance.
- Create/manage workout plans and diet plans for assigned clients.
- Read workout history for assigned clients only.
- Must not view payments or client records outside assignment.
- Must not promote self, create admins, assign another trainer, or alter gym membership/role directly.

### Client

- View and update own profile.
- View own attendance, workout plans/history, diet plans, and own payment history.
- Create/manage own diet plan.
- Must not see member lists, member totals, other client names/IDs/records, or another gym's data.
- Must not create attendance on behalf of others, create plans for another client, record payments, change role, or assign a trainer.

## Functional test cases

Status meanings: **PASS** = observed by execution; **STATIC PASS** = code/config inspected only; **BLOCKED** = not run; **FAIL/GAP** = inspected implementation does not meet expected behavior.

| ID | Scenario | Expected | Status |
|---|---|---|---|
| AUTH-01 | Register with valid email/password and display name | Auth user and matching profile are created | BLOCKED — no live signup test |
| AUTH-02 | Wrong password / invalid email | Clear error; no authenticated dashboard | STATIC PASS — catch path exists; runtime blocked |
| AUTH-03 | Sign out and reopen app | Session is cleared and sign-in screen shown | BLOCKED |
| ADM-01 | Signed-in user creates a gym | One gym + admin membership, no secret needed | STATIC PASS — RPC and UI exist; live test blocked |
| ADM-02 | Blank/one-character gym name | Rejected before insert | STATIC PASS |
| ADM-03 | Admin lists members | Only current gym members and display names | **GAP** — member/profile embedded join may fail because membership user_id and profile id do not have a direct FK relationship; runtime query not tested |
| ADM-04 | Admin adds a member and assigns trainer | Complete UI workflow, validates target role and gym | **GAP** — RPCs exist but in-app role/assignment UI is not implemented |
| ADM-05 | Admin attempts diet plan create/update/delete | Denied; admin can read only | **BLOCKED** — policy intent inspected, negative API test required |
| ADM-06 | Admin records payment | Valid positive amount saved in paise; client can see own record | STATIC PASS — UI path exists; live test blocked |
| TRN-01 | Trainer opens client picker | Only active clients assigned to that trainer | **GAP** — picker embeds profiles via a relationship that may not resolve; query not tested |
| TRN-02 | Trainer records attendance for assigned client | Insert succeeds and appears for trainer/client/admin | STATIC PASS — path/policy exist; live test blocked |
| TRN-03 | Trainer records attendance for unassigned client | Denied by database policy | BLOCKED — must attempt direct API/RPC bypass |
| TRN-04 | Trainer creates workout plan for assigned client | Plan visible to assigned client | STATIC PASS — plan form/policy exist; live test blocked |
| TRN-05 | Trainer creates plan for unassigned client | Denied by RLS even if request bypasses UI | BLOCKED |
| TRN-06 | Trainer opens payments | No payment data is returned | STATIC PASS — tab omitted and RLS limits to admin/client-self; API test blocked |
| CLI-01 | Client opens overview | No other-client list/count | STATIC PASS — overview has no member count; RLS tests still required |
| CLI-02 | Client reads attendance/workout/diet/payment | Own rows only | STATIC PASS — client filters and policies inspected; API isolation test blocked |
| CLI-03 | Client creates own diet plan | Allowed | STATIC PASS — policy exists; live test blocked |
| CLI-04 | Client creates diet plan for another user | Denied | BLOCKED |
| CLI-05 | Client creates workout plan for self | Expected product behavior must be confirmed; current UI does not expose this action | GAP if client workout-plan authoring is required |
| NAV-01 | Switch between bottom tabs | Loads selected tab's data | FIXED IN SOURCE — navigation previously requested data before tab state changed; now passes selected tab explicitly. Not runtime-tested. |
| DATA-01 | Add meal/exercises and log sets/reps | Structured data is editable and history updates | **GAP** — schema exists, complete workout exercise/session/set logging UI is not implemented; diet UI currently stores optional summary as a breakfast meal |
| DATA-02 | Admin sees selected client's attendance/history | Can filter/select a client and inspect records | **GAP** — current UI lists attendance rows but has no proper client selection/filter view for admin |
| TIME-01 | Attendance displayed in India time | Use `Asia/Kolkata` consistently | PARTIAL — DB defaults use India timezone; UI converts to device local time, which may differ from India timezone when device is elsewhere |

## Security threat cases

| ID | Threat / abuse case | Required control | Current assessment |
|---|---|---|---|
| SEC-01 | Client changes URL/query filters to read another client | RLS on every table; negative direct REST tests | RLS enabled, policies exist; **not proven until tests run** |
| SEC-02 | Trainer forges client UUID in attendance insert | Insert policy checks assignment and recorder identity | Policy inspected; negative test blocked |
| SEC-03 | Trainer reads unassigned client's profile via member list | Profile policy restricts trainer to assigned clients | Profile policy narrowed; still needs API test and picker query fix |
| SEC-04 | Client calls admin membership RPC to promote self | RPC checks admin role and permits only trainer/client roles | Code includes admin check and rejects admin role; direct call tests blocked |
| SEC-05 | Unauthenticated/anon invokes privileged SECURITY DEFINER RPC | Revoke `PUBLIC`/`anon` EXECUTE; auth required | Grants revoked; advisor still warns for authenticated execution; verify actual anon call is denied |
| SEC-06 | Signed-in non-admin calls `fp_admin_add_member`/`fp_assign_trainer` | Server-side admin membership check | Function bodies include check; abuse test blocked |
| SEC-07 | Cross-gym ID substitution | Validate caller membership/assignment for every read/write | Many policies check gym/member; verify every table and RPC with cross-gym tests |
| SEC-08 | Client edits payment rows | No client insert/update/delete policy | Intended policy denies; negative test blocked |
| SEC-09 | Admin changes diet data despite read-only requirement | No admin write policy for diet tables | Plan-level policy separates admin read from write; verify meal-table write policies via API tests |
| SEC-10 | User self-edits role/profile ID | Profile updates limited to own row; membership writes admin-only | Policies inspected; negative tests blocked |
| SEC-11 | Malicious or accidental huge inputs | Length/range constraints, safe rendering, server-side validation | Some database constraints exist; plan titles/notes and UI inputs need length caps and tests |
| SEC-12 | Payment amount tampering/rounding | Parse positive amount, store integer paise, admin-only write | Basic positive parse exists; overflow/precision and duplicate payment behavior untested |
| SEC-13 | Account enumeration / weak auth settings | Auth rate limits, confirmation, recovery, safe error handling | Supabase Auth settings and recovery flow not verified; production checklist item |
| SEC-14 | Secret key embedded in app | Only publishable/anon key in client; never service role | README says publishable key; inspect release artifact/config before release |
| SEC-15 | Lost phone / persistent session | Logout, session expiry policy, secure device storage | Supabase SDK session behavior not tested on Android; app has logout action |
| SEC-16 | Sensitive data exposed in logs/errors | Avoid tokens, full PII and SQL details in user-facing errors | Current UI surfaces exception strings in some paths; **fix before production** |
| SEC-17 | Race/duplicate gym creation | Idempotency or business constraints if single gym per account is required | Not defined; current RPC can create multiple gyms for one account |
| SEC-18 | Profile/member join failure leads to missing data or incorrect fallback | Test relationship queries and fail closed | Likely issue: no direct FK from `gym_memberships.user_id` to `profiles.id`; use separate membership/profile queries or add safe FK |
| SEC-19 | RLS bypass through SECURITY DEFINER search path | Fixed empty `search_path`, schema-qualified references, least-privilege grants | RPCs use empty search_path; function-owner and grant review still required |
| SEC-20 | Incomplete migration creates irreproducible deployments | Keep full versioned SQL migration in repository | **GAP** — current bundled migration file is only a marker, not a reproducible schema migration |

## Wiring audit — highest-priority gaps

1. **P0 — Do not call the app launch-ready.** No Flutter compile, analyzer, widget test, Android install test, or live role-isolation test has been run.
2. **P0 — Reproducible migration missing from ZIP.** The current `supabase/migrations/202610220001_fitprogress_schema.sql` is a marker and cannot recreate the database. Export the complete schema/policies/functions into a real migration before another environment or CI is used.
3. **P0 — Verify security advisor and direct API authorization.** Three SECURITY DEFINER functions remain callable by authenticated users by design and are flagged by the advisor. Confirm the function bodies, grants and cross-gym negative tests. Never treat the publishable key as authorization.
4. **P1 — Member/profile join may be invalid.** The UI uses `gym_memberships(...,profiles(...))`, but there is no direct FK between those tables. Replace with separate membership and profile queries or add a valid FK to `profiles(id)` after checking existing data.
5. **P1 — Admin member and trainer assignment flow is incomplete.** Existing RPCs require target auth user UUIDs, but there is no safe in-app invitation/role/assignment UI.
6. **P1 — Structured workout logging is incomplete.** `workout_exercises`, `workout_sessions`, and `workout_set_logs` exist, but the current UI does not provide full exercise details or set-by-set logging/history.
7. **P1 — Attendance review workflow incomplete.** Admin cannot select a client and filter that client's attendance through a dedicated UI.
8. **P1 — Avoid displaying raw backend exceptions to end users.** Log sanitized diagnostic IDs in development and show friendly messages in production.
9. **P1 — Timezone consistency.** Convert timestamps explicitly to `Asia/Kolkata` for India-local business records rather than relying on the phone's local timezone.
10. **P2 — Automated tests needed.** Add unit/widget tests and live integration tests with isolated admin, trainer, client A, client B, and a second-gym account.

## Recommended execution order

1. Repair membership/profile joins and ensure navigation/empty/error states behave correctly.
2. Export a complete, repeatable Supabase migration and review all table grants and policies.
3. Create isolated test identities: Admin A, Trainer A, Client A, Client B (unassigned), Admin B/Gym B.
4. Run every test above through both the Flutter UI and direct authenticated REST calls.
5. Run `flutter analyze`, `flutter test`, `flutter build apk --release`, install on Android, and inspect logs/network failures.
6. Re-run Supabase security advisors and resolve every unexplained finding before launch.
7. Only mark cases PASS when the execution output and test identity are recorded; this document deliberately does not fabricate those results.
