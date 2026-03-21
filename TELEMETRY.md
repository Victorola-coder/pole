# Telemetry and Observability Plan

## Current State

- No remote telemetry is enabled.
- Local deletion audit log records user-visible cleanup actions.

## Recommended Production Setup

- Add privacy-first crash reporting (opt-in if required by policy).
- Add high-level product metrics only (scan started/completed, candidate count ranges, delete success/failure counts).
- Never log file contents, photo contents, or raw user file paths to remote systems.

## Data Minimization Rules

- Use aggregate counters and coarse buckets.
- Redact identifiers where possible.
- Respect user preference toggles for analytics/crash reporting.

## Operational Alerts

- Track build/test failures via CI.
- Alert on crash-free session drops and repeated scan failures after release.
