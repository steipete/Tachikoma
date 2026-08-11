# AGENTS.MD

READ ~/Projects/agent-scripts/{AGENTS.MD,TOOLS.MD} BEFORE ANYTHING (skip if files missing).

Tachikoma notes:
- Keep this repo in sync with Peekaboo; bump the submodule there after changes.
- Batch git network ops with Peekaboo: commit related changes first, then push/pull repos together so the submodule pointer never races the source repo.
- Default workflow: `swiftformat --lint .`, `swiftlint lint --config .swiftlint.yml --strict`, then `TACHIKOMA_TEST_MODE=mock TACHIKOMA_DISABLE_API_TESTS=true swift test --parallel` before publishing.
- Provider adapters live under `Sources/Tachikoma/Providers`; keep new providers consistent with existing patterns.
