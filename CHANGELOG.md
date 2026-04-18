## 0.0.1

* Initial release.
* `Logger<T>` generic over a feature enum, with `info` / `warning` / `error` entry points.
* Positive filters: `listeningToIds`, `listeningToFeatures`, `listeningToMessageTypes`, `listeningToFunctions`. Blocklist: `ignoringFeatures`.
* Retained `log` and broadcast `logStream` with unmodifiable snapshots.
* Optional stack-trace suffix (`includeStackTrace`).
* Customization hooks: `prefixBuilder`, `formatter`, `sink`, `maxLogEntries`.
* `isDebugMode` / `isDeveloper` master gate; silent by default.
* `dispose()` closes the broadcast stream controller.
