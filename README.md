# Custom Logger

A lightweight, filterable logger for Flutter packages. Tag each message with
one or more values from your own feature enum, then narrow what you see at
runtime by feature, id, message type, caller function, or a custom sink.

## Features

- Generic over a feature enum `T` so tagging stays type-safe.
- Positive filters (`listeningToIds`, `listeningToFeatures`,
  `listeningToMessageTypes`, `listeningToFunctions`) and a blocklist
  (`ignoringFeatures`).
- Retained in-memory `log` and a broadcast `logStream` for UI consumers.
- Optional stack-trace suffix per line.
- Pluggable `prefixBuilder`, `formatter`, and `sink` — override only what you
  need without losing the default ergonomics.
- Optional `maxLogEntries` ring buffer for long-running apps.
- `isDebugMode` / `isDeveloper` gates; silent by default in production.

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  logger:
    path: ../logger
```

Then import:

```dart
import 'package:logger/logger.dart';
```

## Usage

Minimal example:

```dart
enum AppFeature { auth, network, ui }

final logger = Logger<AppFeature>(
  isDebugMode: true,
);

logger.info('User signed in', id: 'user-42', features: [AppFeature.auth]);
logger.warning('Retrying request', features: [AppFeature.network]);
logger.error('Render failed', features: [AppFeature.ui]);

// Inspect retained entries.
for (final entry in logger.log) {
  print(entry);
}

// Or subscribe to live updates.
logger.logStream.listen((snapshot) => debugPrint('have ${snapshot.length} entries'));
```

Narrow what reaches the log:

```dart
final logger = Logger<AppFeature>(
  isDebugMode: true,
  listeningToFeatures: [AppFeature.auth, AppFeature.network],
  ignoringFeatures: [AppFeature.ui],
  listeningToMessageTypes: [MessageType.warning, MessageType.error],
);
```

Route messages somewhere besides the console:

```dart
final logger = Logger<AppFeature>(
  isDebugMode: true,
  sink: (message) => remoteTelemetry.report(
    level: message.type.name,
    body: message.content,
  ),
);
```

Replace the line format entirely:

```dart
final logger = Logger<AppFeature>(
  isDebugMode: true,
  formatter: ({required type, required message, id, features, stackTrace}) {
    return '${DateTime.now().toIso8601String()} ${type.name.toUpperCase()} $message';
  },
);
```

Remember to dispose the broadcast stream when the owner goes away:

```dart
await logger.dispose();
```

## Additional information

Defaults are chosen so that a bare `Logger()` logs nothing — both
`isDebugMode` and `isDeveloper` must be opted in. Wire `isDebugMode` to
`kDebugMode` to get console output only in debug builds.
