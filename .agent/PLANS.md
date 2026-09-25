# ExecPlans

An ExecPlan is a repository-local implementation plan for substantial work. Keep it concise, update it while work proceeds, and make it useful to another engineer who did not participate in the implementation.

## When an ExecPlan is required

Use an ExecPlan when work:

- changes architecture or a security boundary;
- affects multiple major components;
- performs a migration;
- changes deployment architecture;
- requires multiple implementation stages; or
- would be difficult to understand from the final diff alone.

Do not create an ExecPlan for typo fixes, routine dependency bumps, small bug fixes, documentation edits, simple configuration changes, or trivial UI changes unless the work meets one of the required criteria above. Required criteria, especially security-boundary and deployment-architecture changes, always take precedence over these exemptions.

## Required sections

1. Objective
2. Existing behavior
3. Proposed behavior
4. Constraints
5. Security considerations
6. Implementation milestones
7. Validation
8. Rollback considerations
9. Decisions made during implementation
10. Final outcome

Store task-specific plans under `.agent/plans/` with a short descriptive filename. Record discoveries and decisions as the work evolves. Remove speculation once the final outcome is known, but preserve decisions that explain the implementation.
