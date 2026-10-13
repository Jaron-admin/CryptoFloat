# MetricPerch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Deliver renamed MetricPerch with independently configured floating and embedded taskbar displays, including Windows system telemetry.
**Architecture:** Shared data services, independent display profiles, background native telemetry, isolated native taskbar renderer. Preserve legacy floating configuration through additive schema migration.
**Tech Stack:** Flutter Material 3/Dart, C++17 Win32/PDH/DXGI, existing Windows method channel.
**Spec:** ../specs/2026-10-13-metricperch-design.md

## Global Constraints

- Version 1.3.0; default BOTH floating market panel and taskbar system monitoring enabled.
- Windows primary taskbar only; no computer-use or operations on the user's existing desktop during tests.
- User authorized automatic documentation, implementation and local tests; no further document approval gates.
- Preserve portable user_data, legacy single-instance identifiers, credentials, custom text and themes. Do not read private user configuration for fixtures.
- Native APIs stay behind platform adapters; no dependency on third-party GPL/non-MIT taskbar code.
- Missing metrics are not zero; UI remains bilingual and compact.

## Review Focus

1. Template-only references and disabled-profile references: dependency and deletion tests in Task 1/4.
2. Source/adapter changes while samples/requests are in flight: generation and reset tests in Task 1/2.
3. Saving failed schema migration or cancelling preview: Task 1/4 preservation tests.
4. Too-small taskbar, unknown layout and disconnected IPC: Task 3 pure layout/protocol tests.
5. Independent conversion and refresh states across profiles: Task 4 formatter/status tests.

## Tasks and file ownership

### Task 1: Display profiles, migration and dependency union

Files: lib/domain/models.dart; new lib/domain/display_profile.dart, lib/domain/display_dependencies.dart; lib/data/config_store.dart, lib/data/legacy_importer.dart, lib/data/market_data_service.dart; tests for profiles/migration/dependencies.

Interfaces: enum DisplayTarget { floating, taskbar }; AppConfig.displayFor(DisplayTarget) -> AppConfig view; AppConfig.withDisplay(DisplayTarget, AppConfig view) -> root AppConfig. New root fields selectedMetricIds, selectedCustomFieldIds (explicit custom:source|field identifiers), systemMonitor, taskbar. TaskbarConfig has enabled=true, width=360, lineCount=2, profile; SystemMonitorSettings intervalSeconds=1, networkAdapterId='auto', gpuAdapterId='auto', diskId='all'. Taskbar display defaults ['cpu.usage','memory.usage','network.upload','network.download']; floating metrics initially empty. AppConfig.acquisitionAssets, activeCustomSourceIds, needsExchangeRates serve polling. DisplayDependencies computes asset/source/metric IDs from all displayed items including templates. Preserve existing AppConfig floating-facing API to limit churn.

- [x] Add tests: editing taskbar leaves floating unchanged, roundtrip and schema1 migration retain custom fields/templates/title; defaults enable taskbar; template-only market reference is acquired once.
- [x] Run new tests and record intended failures.
- [x] Implement typed profiles and schema2 migration; preserve original pre-migration backup; refuse saves of unknown future schema.
- [x] Adapt polling to union dependencies; per-source generations; pure display sorting does not invalidate good quotes; exchange rates shared.
- [x] Run tests and report interfaces plus evidence. Root commits after scoped review.

### Task 2: Native system metrics sampler

Files: windows/runner/system_metrics.h/.cpp, optional metrics_math.h/.cpp, native isolated test driver and tool/test_system_metrics.ps1. Do not edit platform_channel or CMake (root integrates).

Interfaces: SystemMetricsOptions { bool enabled=true; int interval_ms=1000; std::string network_adapter_id="auto", gpu_adapter_id="auto", disk_id="all"; }; MetricDevice { std::string id,name; }; SystemMetricValue { double value=0; std::string state="unavailable", unit; }; SystemMetricsSnapshot { std::map<std::string,SystemMetricValue> values; std::vector<MetricDevice> network_adapters,gpu_adapters,disks; double sampled_at_ms=0; std::string network_name,gpu_name,disk_name; }; class SystemMetrics { Configure(const SystemMetricsOptions&); Snapshot() -> SystemMetricsSnapshot; destructor stops worker; }.

Metric IDs: cpu.usage, memory.usage, memory.used, memory.total, network.upload, network.download, gpu.usage, gpu.memory.used, gpu.memory.total, gpu.shared.used, gpu.shared.total, disk.read, disk.write. Units %, B, B/s. State valid/warmingUp/unavailable. Millisecond timestamp epoch UTC. Thread-safe cached snapshot; no blocking PDH collection in Flutter UI thread.

- [x] Add isolated behavior tests for delta-rate resets, GPU grouping/max engine, invalid counter status and unavailable metrics. Observe intended red failures.
- [x] Implement PDH/Win32/DXGI collector and device selection per spec; English counters and two-sample rates; background lifecycle safe.
- [x] Compile and run isolated tests without user windows/config; report needed link libraries and tested vs unverified native behavior.

### Task 3: Embedded native taskbar host

Files: windows/runner/taskbar_host.h/.cpp; taskbar_protocol.h/.cpp; taskbar_layout.h/.cpp; taskbar_main.cpp; taskbar.cmake; isolated native tests and tool/test_taskbar_host.ps1. Do not edit shared CMake/platform_channel.

Interfaces: TaskbarCell { std::wstring text; uint32_t color; }; TaskbarFrame { bool enabled=true, chinese=true; int width=360,line_count=2; double font_size=11; std::wstring font_family=L"Segoe UI"; uint32_t background=0xFF202020, foreground=0xFFF3F3F3; std::vector<TaskbarCell> cells; }; class TaskbarHost { explicit TaskbarHost(HWND owner); std::string Update(const TaskbarFrame&); std::string TakeAction(); ~TaskbarHost(); }. Update returns latest disabled/displaying/waiting/noSpace/unsupported/error. TakeAction returns empty or show/settings/refresh/disable/exit. Optional tooltip in frame/cell may be added with backward-compatible defaults; report it.

- [x] Add red tests for IPC bounds/roundtrip, finite frame validation, free-region fitting and no-room/unknown layout refusal.
- [x] Implement independent metricperch_taskbar.exe with safe bounded binary pipe protocol, no API credentials, parent disconnect/exit teardown, hidden launch.
- [x] Discover primary native taskbar, validate usable region conservatively, attach own HWND; no Explorer injection or moving shell controls. DPI/auto-hide/Explorer restart handled with rediscovery and fail-closed state.
- [x] Native text renderer, single/double row, fonts/colors, localized right-click actions, full-text tooltip where truncated. No desktop runtime testing without separate permission.
- [x] Compile isolated tests, document CMake integration via taskbar.cmake and behavior not verified against real desktop.

### Task 4: Flutter integration and settings

Files: new lib/platform/system_metrics_host.dart, taskbar_host.dart; lib/data/system_metrics_service.dart; lib/domain/metric_catalog.dart, display_snapshot.dart; app_controller, panel, settings files; platform_channel.h/.cpp; windows runner CMake integration.

- [x] Add tests with fake platform boundary for metric formatting, profile-specific status and no duplicate refresh; add UI tests selecting taskbar and changing fields while floating remains unchanged.
- [x] Map native snapshots to immutable Dart values, sampled timer interval 1–60 seconds; no fake zeros. Wire cached native sampler and taskbar lifecycle.
- [x] Reuse profile projections in settings target selector; always save root draft. Shared source definitions and telemetry settings remain shared; previews target only chosen display. Preserve save failure/cancel/secret cleanup behavior.
- [x] Add system metric selection and device selectors, independent taskbar layout controls. Reuse existing market/custom row editors and sort controls for either profile. Custom field selection explicit.
- [x] Render local metrics in floating panel and taskbar with same units/formatting; native method bridge sends text and colors only. Correct per-profile freshness.
- [x] Run all Flutter tests and analyze, fix regressions and review scoped diffs.

### Task 5: Branding, release and privacy

Files: pubspec/platform resources, README.md/README.en.md, build scripts, release notes and dependency notices.

- [x] Rename visible default brand and executable/release names; keep stored custom title and old private compatibility identifiers.
- [x] Version 1.3.0, bilingual usage for independent displays, telemetry and taskbar compatibility.
- [x] Full reviewer checks whole branch against spec; resolve important findings.
- [x] Build Windows release through neutral drive mapping, inspect package allowlist and personal-data audit, exclude user_data and diagnostics.
- [ ] Rename public repo to MetricPerch preserving history/releases; update origin/readme URLs; publish verified source and Windows archive with SHA256 after tests/build succeed.
- [x] Back up and update local shortcut without launching/stopping user application; report exact results and unverified live-taskbar limits.

## Execution rulings

- Work in current clean checkout on codex/metricperch-taskbar; no extra worktree needed. Root owns integration files and commits.
- Independent native sampler/taskbar/profile tasks may run concurrently with strict file ownership under active developer multi-agent instruction; this overrides skill's generic serial-worker preference.
- The user's final default-on instruction is authoritative for both fresh installs and migration. Saved explicit taskbar off remains off thereafter.
