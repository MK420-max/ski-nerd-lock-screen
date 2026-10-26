# Release verification — 1.0

Verified locally on an Apple silicon Mac running macOS 27, with built-in and external displays.

- The owner confirmed the accepted lock-screen layout works on the actual lock screen before release preparation. Version 1.0 retains that geometry and the decoded-bitmap playback path.
- The compact native settings window was rendered in Simplified Chinese and English. Its two row tabs and camera controls were inspected.
- A camera was replaced through the native UI with a public HTTPS image source. The new name/source/type persisted and the actual image appeared in the main preview; original sources were restored afterwards.
- An invalid non-HTTPS camera URL produced an English validation message while preserving the last saved configuration.
- Configuration round-trip, backward compatibility with missing language, language selection and invalid-save retention passed.
- All four replacement provider sources were requested after stop → settings change → resume.
- Four layout viewports passed: 1512×982, 2560×1440, 1244×810 and 3840×1080.
- Forecast interval, units, rain/showers and missing-data checks passed. Resolver tests passed.
- The packaged resolver started with a restricted PATH and no external Python/Node, then resolved an actual Cypress public stream using its bundled runtime.
- Release trees were checked for current-machine identity, absolute home paths, personal settings, QA fixtures and credential patterns. Generic screenshots were inspected separately.

Not independently established: every camera in the world, Intel compatibility, fresh-user installation on a second Mac, every macOS/resolution combination, or uninterrupted playback while the Mac sleeps. This build is ad-hoc signed and not notarized.

Cypress’s original snow-stake image was offline during verification; the explicit retry state is preserved. Weather values and pictures in documentation are examples from their capture time.

Deep frozen-code audit checked 31,225 code objects after replacing machine-specific CPython build metadata with generic paths. Native bundles extracted from the actual ZIP passed strict signature checks.
