# Cross-monitor DPI refresh implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Implement and review each owned component independently.

**Goal:** Resolve click-to-recover text scaling with evidence, and capture reusable engineering interfaces.

**Architecture:** Native and Flutter observations feed an opt-in numerical trace. A framework-independent consistency model keeps observation separate from rendering policy. The correction is selected after reproduction.

**Tech Stack:** Win32 C++17, Flutter/Dart, Markdown, local Git.

**Spec:** ../specs/2026-10-14-dpi-refresh-design.md

## Global constraints

- Do not manipulate the real desktop without new explicit permission.
- Use temporary data for tests; retain existing portable settings.
- Keep numerical diagnostics opt-in and bounded; no user text, names, paths or API content.
- Do not claim the rendering symptom fixed from geometry tests alone.
- No dependency changes or platform-wide DPI overrides.

## Review focus

- Pending raster work may ignore an immediate ForceRedraw request.
- DPI changes with unchanged physical dimensions still require correct framework metrics.
- Nested DPI events must not overwrite a stable logical size with a temporary physical size.
- Diagnostic frame callbacks must neither loop indefinitely nor survive disposal.
- Frame timing and viewport consistency do not prove final desktop composition.

## Tasks

- [x] Native trace: add an opt-in sink and parent/child event observations, validate event allowlists and bounded logs with hidden fixtures.
- [x] Flutter trace: report didChangeMetrics, post-frame state and frame timing with a finite payload; cover lifecycle and disabled tracing.
- [x] Create an isolated diagnostic build and request approval for concrete live reproduction.
- [ ] Choose and implement a minimal fix from observed evidence; add a failing regression before the correction.
- [x] Create and verify reusable observation interfaces plus case documentation in EngineeringPlaybook.
- [ ] Review, build, audit public files, and deliver the corrected application and local repository with precise verification limits.
