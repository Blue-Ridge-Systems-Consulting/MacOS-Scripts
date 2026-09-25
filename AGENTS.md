# Repository instructions

<!-- BEGIN BLUE RIDGE CODEX ENGINEERING LAYER -->
## Blue Ridge Codex engineering rules

Repository classification: **STANDARD** — macOS maintenance scripts.

This repository is **STANDARD**. Only allowlisted, deterministic, validated low-risk repairs may be considered for automatic merge.

### Engineering principles

- Prefer the smallest safe change and understand the repository before modifying it.
- Preserve the existing architecture and deployment model unless the task explicitly requires a change.
- Reuse existing dependencies and tooling where practical.
- Do not introduce new services, containers, databases, frameworks, dependencies, or orchestration without a concrete need.
- Keep solutions maintainable by a small engineering operation and do not modify unrelated files or perform opportunistic refactors.

### Security boundaries

Never expose, print, log, or commit secrets or credentials. Never weaken authentication, authorization, firewall rules, network boundaries, tests, branch protection, signing requirements, or CI security checks to make work pass.

Treat Tailscale, Cloudflare, authentication, authorization, firewall configuration, GitHub Actions permissions, repository permissions, signing, SSH, API credentials, network routes, and deployment credentials as security-sensitive. Use least privilege and require human approval for changes to those areas.

### GitHub and automation

- Use Codex only when a human explicitly invokes it through the existing ChatGPT/Codex access. Do not add metered AI API calls, API credentials, or automated AI review, diagnosis, or repair workflows as part of this engineering layer.
- Prefer pull requests. Never push an AI-generated repair directly to the default branch.
- Preserve branch protection, rulesets, required checks, and signing requirements.
- Human-invoked Codex repair branches use `codex/`. Do not start a recursive repair when a Codex-generated repair fails; leave the failed PR for human intervention.
- Never auto-merge changes to `.github/workflows/**`, `AGENTS.md`, `.agent/**`, `CODEOWNERS`, security-sensitive paths, permissions, credentials, infrastructure boundaries, authentication, authorization, signing, SSH trust, firewall policy, or production routing.
- A human-invoked Codex repair PR may use GitHub-native auto-merge only for an explicitly allowlisted low-risk change after validation and all GitHub-required checks pass. GitHub makes the final merge-readiness determination. When uncertain, stop after diagnosis or leave the PR for human review.

### Validation

Before declaring work complete:

1. Run applicable existing tests, linting, builds, and configuration/schema validation.
2. Run shell syntax validation for modified shell scripts.
3. Run `git diff --check` before staging and `git diff --cached --check` after staging so the complete proposed patch is covered.
4. Review the complete diff and verify that no secrets or credentials were introduced.
5. Report exactly what changed and which validation succeeded, failed, or was not run.

Repository validation discovered during rollout:

  - No repository-wide test command was discovered. Validate modified files with the repository's existing tooling; always run syntax/configuration checks that apply.

Never claim validation succeeded unless it actually ran successfully.

### ExecPlans

For substantial features, migrations, architecture changes, security-boundary changes, deployment-architecture changes, or multi-stage work, create and maintain a concise ExecPlan following `.agent/PLANS.md`. Small fixes, documentation edits, routine dependency bumps, and trivial configuration/UI changes do not require an ExecPlan unless they meet one of those mandatory planning criteria.
<!-- END BLUE RIDGE CODEX ENGINEERING LAYER -->
