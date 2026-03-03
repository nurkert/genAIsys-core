# Vision (Short)

This file is the minimal, agent-facing summary. For the full, authoritative vision and details, read:
`../docs/vision/README.md` (follow the listed reading order).

## Mission
Genaisys is a desktop orchestrator for AI-assisted software delivery that combines planning,
implementation, review, and git delivery into a safe, auditable workflow for ambitious solo developers first.
Details: `../docs/vision/vision.md` (Mission, Produktversprechen, Zielgruppe),
`../docs/vision/features/11_target_audience.md` (Zielgruppe)

## Goals (High-Level)
- Reliable desktop-first orchestration with a strict core/UI split.
  Details: `../docs/vision/principles_and_scope.md` (Leitprinzipien, Scope v1),
  `../docs/vision/architecture_and_storage.md` (Schichtenmodell, Prozessmodell),
  `../docs/vision/ui_ux.md` (Grundprinzipien),
  `../docs/vision/features/12_desktop_ui.md` (Desktop-UI)
- `.genaisys` as the project-local single source of truth for vision, backlog, state, and logs.
  Details: `../docs/vision/architecture_and_storage.md` (Datenvertraege, .genaisys Struktur),
  `../docs/vision/features/01_project_structure.md` (Projektstruktur und .genaisys)
- Mandatory independent review gate before any task is considered done.
  Details: `../docs/vision/review_policy.md` (Regeln),
  `../docs/vision/features/05_review_gate.md` (Ablauf),
  `../docs/vision/agents_and_policies.md` (Review-Policy)
- Autonomous, incremental execution of roadmap tasks in small, controlled steps.
  Details: `../docs/vision/roadmap.md` (Phase 0-2),
  `../docs/vision/agents_and_policies.md` (Autonomie-Governance),
  `../docs/vision/workflows.md` (Umsetzung mit Agenten)
- Supervised autopilot mode: self-healing supervisor monitors the autopilot, fixes deadlocks/crashes,
  improves autopilot code to prevent recurrence. Productivity reflection service analyzes metrics
  and creates optimization tasks. Configurable agent pipeline with hook points for specialist agents.
  Details: `../docs/vision/supervised_autopilot.md`,
  `../docs/vision/features/14_supervised_autopilot.md`,
  `../docs/vision/roadmap.md` (Phase 2c)
- Robust git workflow: branch-per-task, review-gated commit/push/merge, conflict recovery.
  Details: `../docs/vision/features/06_git_workflow.md` (Git-Workflow),
  `../docs/vision/roadmap.md` (Git Service Minimal),
  `../docs/vision/agents_and_policies.md` (Parallelitaet)
- Ops reliability: health checks, watchdog behavior, and resilient recovery paths.
  Details: `../docs/vision/capability_gaps.md` (Autopilot-Betrieb und Ops),
  `../docs/vision/roadmap.md` (Phase 2: Robustheit)
- Hardened agent runtime: timeouts, budgets, strict policies, and deterministic safeguards.
  Details: `../docs/vision/agents_and_policies.md` (Safety-Policies),
  `../docs/vision/security_model.md` (Bedrohungen und Gegenmassnahmen),
  `../docs/vision/features/10_safety_policies.md` (Safety-Policies)
- Build/test automation with logged outputs and review evidence.
  Details: `../docs/vision/features/13_quality_controls.md` (Tests),
  `../docs/vision/workflows.md` (Umsetzung mit Agenten, Review-Gate),
  `../docs/vision/config_schema.md` (policies, timeouts)
- Planning, auditing, and maintenance routines to keep backlog quality high.
  Details: `../docs/vision/features.md` (Logs und Audit),
  `../docs/vision/capability_gaps.md` (Maintenance- und Audit-Tasks),
  `../docs/vision/architecture_and_storage.md` (RUN_LOG.jsonl)
- Support existing repositories by deep-scanning code, deriving an initial vision/backlog automatically, and refining with the user.
  Details: `../docs/vision/vision.md` (Einbindung bestehender Projekte / Deep-Scan Init),
  `../docs/vision/workflows.md` (Bestehendes Projekt einbinden),
  `../docs/vision/features/15_deep_scan_init.md` (Deep-Scan Init)
- LLM-model-agnostic: deliver outstanding software even with weaker/cheaper models through strict processes,
  validation gates, and LLM-friendly documentation that guides the model step by step.
  Details: `../docs/vision/vision.md` (LLM-Modell-Agnostik und Schwaechere-Modelle-Strategie)
- Two-persona model: absolute beginners use Genaisys purely via chat (specialized setup agents handle
  architecture, language, and config decisions); senior developers retain full CLI control and fine-tune
  every policy, test strategy, and quality gate to their exact requirements.
  Details: `../docs/vision/vision.md` (Zwei-Persona-Modell: Noob bis Senior),
  `../docs/vision/features/16_interactive_self_configuration.md` (Interactive Self-Configuration)
- Interactive self-configuration: Genaisys understands project context from user dialogue and proposes
  appropriate config (loose for a Minecraft plugin, strict for commercial SaaS, balanced for open-source libraries).
  Details: `../docs/vision/vision.md` (Interaktive Selbstkonfiguration),
  `../docs/vision/features/16_interactive_self_configuration.md`
- Security audit mode: static code analysis discovers vulnerabilities and creates prioritized backlog tasks.
  Details: `../docs/vision/vision.md` (Security-Audit-Modus),
  `../docs/vision/features/17_security_audit_mode.md` (Security-Audit-Modus)
- Rewrite mode (long-term vision): rewrite an existing project feature-by-feature into a new architecture or
  language, with automated parity verification against the original.
  Details: `../docs/vision/vision.md` (Rewrite-Modus),
  `../docs/vision/features/19_rewrite_mode.md` (Rewrite-Modus)
- Rich task model: tasks carry short description, detailed description, acceptance criteria, and structured
  metadata — moving beyond flat markdown lines toward machine-readable task specs.
  Details: `../docs/vision/features/18_rich_task_model.md` (Rich Task Model)
- Open-Core monetization: Core/CLI under BSL 1.1 (converts to MIT after 3 years), proprietary Desktop GUI
  with tiered pricing (Community free, Personal one-time, Pro monthly, Enterprise per-user).
  Details: `../docs/vision/vision.md` (Business Model: Open-Core),
  `../docs/vision/features/20_business_model.md` (Business Model)
- Usable MVP GUI with project setup, dashboard, tasks, review, and essential controls.
  Details: `../docs/vision/ui_ux.md` (Kernbereiche),
  `../docs/vision/features/12_desktop_ui.md` (Kernbereiche),
  `../docs/vision/roadmap.md` (Phase 1)
- Internal artifacts and agent outputs remain in English for consistency.
  Details: `../docs/vision/language_policy.md` (Regeln),
  `../docs/vision/principles_and_scope.md` (Leitprinzipien)

## Constraints / Invariants
- No task completion without review approval.
  Details: `../docs/vision/vision.md` (Nicht verhandelbare Invarianten),
  `../docs/vision/review_policy.md` (Regeln)
- Commit, push, and merge only after review approval.
  Details: `../docs/vision/review_policy.md` (Entscheidung),
  `../docs/vision/features/06_git_workflow.md` (Automatisierung)
- Safe-write boundaries and shell allowlist remain enforced in autopilot flows.
  Details: `../docs/vision/vision.md` (Nicht verhandelbare Invarianten),
  `../docs/vision/security_model.md` (Kernprinzipien),
  `../docs/vision/features/10_safety_policies.md` (Safe-Write, Shell-Allowlist)
- Core logic remains UI-agnostic; UI is a controller/observer.
  Details: `../docs/vision/principles_and_scope.md` (Leitprinzipien),
  `../docs/vision/architecture_and_storage.md` (Prozessmodell)
- Work remains reproducible and traceable through state, logs, and diffs.
  Details: `../docs/vision/architecture_and_storage.md` (Datenvertraege),
  `../docs/vision/security_model.md` (Logging und Audit),
  `../docs/vision/features.md` (Logs und Audit)
- Current execution mode prioritizes Core/CLI stabilization and refactoring; non-critical GUI expansion is intentionally deferred until stabilization exit criteria are met.
  Details: `../docs/vision/roadmap.md` (Phase 2: Robustheit),
  `../docs/vision/capability_gaps.md` (Autopilot-Betrieb und Ops)
- Interaction-facing capabilities remain dual-path by definition: CLI control is mandatory first, and GUI control must exist before the capability area is considered complete.
  Details: `../docs/vision/principles_and_scope.md` (Definition of Done),
  `../docs/gui_min_roadmap.md` (GUI-zu-UseCase Mapping)
- Automated self-configuration from chat dialogue must remain fully overridable by manual config.
  Details: `../docs/vision/vision.md` (Interaktive Selbstkonfiguration)
- Open-Core model: Core + CLI remain fully functional under BSL without GUI; GUI license check never restricts Core/CLI features.
  Details: `../docs/vision/vision.md` (Business Model: Open-Core),
  `../docs/vision/features/20_business_model.md` (Invarianten)
- No vendor lock-in: `.genaisys/` stays portable; users who skip the GUI lose no data or features.
  Details: `../docs/vision/features/20_business_model.md` (Wichtige Invarianten)
- Supervisor self-modification goes through the same review gate as all other changes.
  Details: `../docs/vision/supervised_autopilot.md` (Sicherheitsinvarianten)
- Hot-restart must not corrupt any in-flight task.
  Details: `../docs/vision/supervised_autopilot.md` (Hot-Restart-Strategie)
- The review step cannot be removed from any pipeline configuration.
  Details: `../docs/vision/supervised_autopilot.md` (Invarianten)

## Success Criteria
- End-to-end task cycle works: plan/spec/subtasks -> coding -> tests -> review -> done -> git delivery.
  Details: `../docs/vision/vision.md` (Erfolgskriterien),
  `../docs/vision/workflows.md` (Umsetzung mit Agenten, Review-Gate, Abschluss)
- The system can keep progressing roadmap tasks in iterative loops with minimal supervision.
  Details: `../docs/vision/roadmap.md` (Phase 0-1),
  `../docs/vision/principles_and_scope.md` (Autonomie-Governance)
- GUI MVP can drive core CLI flows through stable boundaries.
  Details: `../docs/vision/ui_ux.md` (Kernbereiche),
  `../docs/vision/roadmap.md` (Phase 1)
- Every applied change is auditable (state, logs, review outcome, task status).
  Details: `../docs/vision/vision.md` (Erfolgskriterien),
  `../docs/vision/architecture_and_storage.md` (RUN_LOG.jsonl)
- Genaisys can bootstrap and improve itself using its own workflow.
  Details: `../docs/vision/roadmap.md` (Phase 0-1)
- Genaisys delivers outstanding software quality even with weaker LLM models through process rigor.
  Details: `../docs/vision/vision.md` (LLM-Modell-Agnostik)
- An absolute beginner can use Genaisys purely in chat mode and get a working project.
  Details: `../docs/vision/vision.md` (Zwei-Persona-Modell)
- Deep-Scan Init generates vision, backlog, and config automatically for existing projects.
  Details: `../docs/vision/features/15_deep_scan_init.md`
- The supervised autopilot can detect and resolve deadlocks, crashes, and hangs autonomously.
  Details: `../docs/vision/supervised_autopilot.md` (Schicht 2: Supervisor)
- Supervisor self-healing produces targeted autopilot improvements that pass review.
  Details: `../docs/vision/supervised_autopilot.md` (Selbstheilung)
- Productivity reflection produces measurable improvements in cycle time and token efficiency.
  Details: `../docs/vision/supervised_autopilot.md` (Schicht 3: Reflexion)
- Open-Core business model with BSL-licensed Core/CLI and proprietary GUI with tiered pricing.
  Details: `../docs/vision/vision.md` (Business Model: Open-Core),
  `../docs/vision/features/20_business_model.md` (Business Model)

## Quality Bar
- Strict quality gates and review discipline.
  Details: `../docs/vision/review_policy.md` (Regeln),
  `../docs/vision/features/13_quality_controls.md` (Review ist Pflicht)
- Small, scoped, maintainable changes with explicit diff controls.
  Details: `../docs/vision/features/13_quality_controls.md` (Diff-Checks),
  `../docs/vision/features/10_safety_policies.md` (Diff-Budgets)
- Reliability features (retry state, block rules, resume behavior) are first-class.
  Details: `../docs/vision/capability_gaps.md` (Autopilot-Betrieb und Ops),
  `../docs/vision/roadmap.md` (Phase 2: Robustheit)
- English-only internal artifacts for consistent agent quality.
  Details: `../docs/vision/language_policy.md` (Regeln)

## Assumptions
- Genaisys runs locally as a desktop app and uses CLI providers.
  Details: `../docs/vision/vision.md` (Annahmen),
  `../docs/vision/features/08_provider_support.md` (Provider-Support)
