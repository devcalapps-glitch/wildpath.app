# WildPath — AI Agent System

Agent definitions live in `.claude/agents/` and are available project-wide via Claude Code.

---

## Orchestrator

| Agent | Role | Model |
|-------|------|-------|
| **orchestrator** | Decomposes high-level requests into plans, delegates to workers, evaluates output, retries on failure | Opus |

**Usage:**
```
@"orchestrator (agent)" Redesign the gear screen to match the meals screen layout
```

**Workflow:**
1. Analyze the request and read relevant files
2. Break into concrete, assignable tasks (sequential or parallel)
3. Delegate each task to the right worker with full context
4. Evaluate output — run `flutter analyze`, check consistency
5. Retry with revised instructions if a worker fails
6. Report what changed and any follow-up recommendations

---

## Worker Agents

| Agent | Specialization | Model |
|-------|---------------|-------|
| **flutter-developer** | Implements Flutter/Dart code — screens, widgets, state, navigation | Sonnet |
| **ui-architect** | Generates responsive Dart UI strictly following `flutter_lints` | Sonnet |
| **ux-reviewer** | Reviews layouts, flows, tap targets, and mobile responsiveness | Sonnet |
| **code-reviewer** | Audits correctness, lifecycle, performance, and codebase consistency | Sonnet |
| **critic** | Opinionated deep reviewer — challenges design decisions, finds bugs and perf bottlenecks | Opus |
| **debugger** | Traces root causes of crashes, state bugs, and layout issues | Sonnet |
| **qa-specialist** | Functional tests, UX/UI readiness, mobile edge cases; writes `flutter_test` + `integration_test` scripts | Opus |
| **l10n** | Manages `.arb` files and `intl` wiring for multi-language support | Sonnet |
| **aso** | Optimizes App Store / Google Play titles, keywords, and descriptions | Sonnet |
| **compliance** | Drafts Privacy Policy, Apple App Privacy Nutrition Label, Google Play Data Safety form | Sonnet |
| **release-manager** | Version bumps, CHANGELOG, release build checklist, store submission readiness | Sonnet |
| **copywriter** | Writes and audits all user-facing text: onboarding, empty states, errors, CTAs, labels | Sonnet |
| **performance-auditor** | Profiles widget rebuilds, expensive build() calls, memory leaks, and jank sources | Sonnet |
| **security-auditor** | Checks API key exposure, insecure storage, input validation, and git hygiene | Opus |
| **devops** | Writes GitHub Actions workflows for lint, test, build, and release pipelines | Sonnet |

---

## QA Specialist — Three Testing Pillars

**Pillar 1: Functional Testing**
- State management, persistence round-trips, navigation, API integrations
- Form validation, budget calculations, data accuracy
- Generates `flutter_test` unit tests and `integration_test` flow scripts

**Pillar 2: UX/UI Testing**
- Color/typography system compliance (`WildPathColors`, `WildPathTypography`)
- Touch target verification (min 44×44px)
- App Store readiness: empty states, loading indicators, error states
- Returns a scored readiness report (n/10)

**Pillar 3: Mobile Edge Cases**
- Connectivity loss, slow network, app backgrounding, kill/restart
- Screen form factors: Galaxy S8 (360dp) → standard phone (390dp) → Galaxy Fold unfolded (673dp)
- Notch / Dynamic Island safe area handling
- Accessibility: TalkBack labels, large system font, high contrast mode

---

## Invoking Workers Directly

```
@"flutter-developer (agent)" Add a note field to the gear screen
@"critic (agent)" Review the budget section in more_screen.dart
@"qa-specialist (agent)" Run UX/UI pillar on the emergency info screen
@"aso (agent)" Generate App Store metadata for both stores
@"compliance (agent)" Draft the Apple App Privacy Nutrition Label
@"release-manager (agent)" Prepare a minor release with the latest changes
@"copywriter (agent)" Audit empty states across all screens
@"performance-auditor (agent)" Audit more_screen.dart for rebuild waste
@"security-auditor (agent)" Run a full security audit on the codebase
@"devops (agent)" Create a full CI/CD pipeline for Android
```
