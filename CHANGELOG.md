## 1.0.0

### Breaking changes
* `logStreamController` is no longer public. Use `logStream` getter instead.
* `log` is now an `UnmodifiableListView`; mutate via `info` / `warning` / `error` / `clearLog`.
* `logStream` now emits unmodifiable snapshots, not the live internal list.
* `listeningToFunctions` no longer drops messages whose caller is an anonymous closure or has no recognizable name; the filter only narrows when the caller is a named function.

### Fixes
* `error(...)` now tags the message as `MessageType.error` (previously `MessageType.warning`).

### Added
* Customization hooks on the constructor: `prefixBuilder`, `formatter`, `sink`, `maxLogEntries`.
* `Future<void> dispose()` to close the broadcast stream controller.
* Dartdoc on the library, `MessageType`, `Message`, and every public field and method of `Logger`.

### Changed
* Internal log methods deduplicated behind a private helper — no change to the `info` / `warning` / `error` call sites.
* `Chain.current()` is only captured when `includeStackTrace` or `listeningToFunctions` is in use.
* Default sink is `debugPrint` (replaces direct `print`).
