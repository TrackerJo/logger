/// A lightweight, filterable logger for Flutter packages.
///
/// [Logger] is parameterized over a feature enum `T` so callers can tag each
/// message with one or more feature values and then filter the in-memory log
/// and live stream by feature, id, message type, or caller function name.
///
/// The default constructor produces a logger that stays silent in production
/// (both [Logger.isDebugMode] and [Logger.isDeveloper] default to `false`).
/// Opt in explicitly to receive messages.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:stack_trace/stack_trace.dart';

/// Severity level of a logged [Message].
enum MessageType {
  /// Informational — normal application flow.
  info,

  /// Warning — recoverable or suspicious condition.
  warning,

  /// Error — failure the caller wants surfaced.
  error,
}

/// A single entry produced by [Logger].
///
/// [content] is the formatted line that was written to the sink. [type] is the
/// severity. [features] is the (optional) list of feature tags the call site
/// supplied; it is preserved verbatim so consumers can re-filter downstream.
class Message<T> {
  /// Pre-formatted line including prefix, features, id, and body.
  final String content;

  /// Severity of this message.
  final MessageType type;

  /// Feature tags associated with this call, if any.
  final List<T>? features;

  /// Creates a message. Usually constructed by [Logger]; expose-able so
  /// consumers of [Logger.logStream] can pattern-match the fields.
  Message({required this.content, required this.type, this.features});

  @override
  String toString() => content;
}

/// Signature for customizing the bracketed prefix of each line.
typedef PrefixBuilder = String Function(MessageType type);

/// Signature for fully overriding the formatted [Message.content].
///
/// Receives the raw inputs and must return the string stored on the message
/// and passed to the sink.
typedef MessageFormatter<T> =
    String Function({
      required MessageType type,
      required String message,
      String? id,
      List<T>? features,
      String? stackTrace,
    });

/// Signature for where formatted messages are written (console, file, etc.).
typedef LogSink<T> = void Function(Message<T> message);

/// A filterable logger.
///
/// Construct once per scope (typically app-wide) and call [info], [warning],
/// or [error]. Messages that survive the filter stack are appended to [log]
/// and emitted on [logStream].
///
/// ### Filter semantics
///
/// * `listeningTo*` fields are positive filters: `null` lets everything
///   through, a non-null list narrows to matching values only.
/// * [ignoringFeatures] is a blocklist and overrides all `listeningTo*`
///   filters — if a message has any ignored feature it is dropped.
/// * [listeningToFunctions] only narrows when the caller's function name can
///   be recognized in the stack trace. Calls from anonymous closures or
///   top-level functions (where the name is empty or `<fn>`) bypass this
///   filter rather than being dropped.
/// * [isDebugMode] and [isDeveloper] together form a master gate: if both are
///   false, nothing is logged. Defaults are false so a bare `Logger()` is
///   silent in production until explicitly enabled.
///
/// ### Customization
///
/// All of [prefixBuilder], [formatter], [sink], and [maxLogEntries] are
/// optional. Omitting them reproduces the built-in behavior.
class Logger<T> {
  /// If set, only messages whose `id` matches one of these are kept.
  final List<String>? listeningToIds;

  /// If set, only messages whose `features` intersect this list are kept.
  final List<T>? listeningToFeatures;

  /// If set, only messages of a listed [MessageType] are kept.
  final List<MessageType>? listeningToMessageTypes;

  /// If set, only messages whose *recognized* caller function name is listed
  /// are kept. Closures and unnamed callers bypass this filter.
  final List<String>? listeningToFunctions;

  /// Features that cause a message to be dropped even if it would otherwise
  /// match the positive filters.
  final List<T>? ignoringFeatures;

  /// Whether to append a `\n  at file:line:col (member)` suffix to each line.
  final bool includeStackTrace;

  /// Developer gate — when `true`, messages are logged even outside of
  /// [isDebugMode]. Pair with runtime flags (e.g. a hidden in-app toggle).
  final bool isDeveloper;

  /// Debug gate — typically wired to [kDebugMode]. When `true`, messages are
  /// also printed via [debugPrint].
  final bool isDebugMode;

  /// Optional override for the `[INFO]` / `[WARNING]` / `[ERROR]` prefix.
  final PrefixBuilder? prefixBuilder;

  /// Optional full replacement for the built-in line formatter.
  final MessageFormatter<T>? formatter;

  /// Optional override for where messages are written. Defaults to
  /// [debugPrint] when [isDebugMode] is true.
  final LogSink<T>? sink;

  /// If set, caps the in-memory [log]; oldest entries are dropped first.
  final int? maxLogEntries;

  final List<Message<T>> _entries = [];
  final StreamController<List<Message<T>>> _controller =
      StreamController<List<Message<T>>>.broadcast();

  /// An unmodifiable view of retained messages. Mutate via [info] / [warning]
  /// / [error] / [clearLog] only.
  List<Message<T>> get log => UnmodifiableListView(_entries);

  /// Broadcast stream that emits a snapshot of [log] after every accepted
  /// message. Safe to subscribe to from multiple listeners.
  Stream<List<Message<T>>> get logStream => _controller.stream;

  /// Creates a logger. All arguments are optional; see the class-level
  /// documentation for filter and customization semantics.
  Logger({
    this.listeningToIds,
    this.listeningToFeatures,
    this.listeningToMessageTypes,
    this.listeningToFunctions,
    this.ignoringFeatures,
    this.includeStackTrace = false,
    this.isDeveloper = false,
    this.isDebugMode = false,
    this.prefixBuilder,
    this.formatter,
    this.sink,
    this.maxLogEntries,
  });

  /// Logs an informational message.
  void info(String message, {String? id, List<T>? features}) =>
      _log(MessageType.info, message, id: id, features: features);

  /// Logs a warning.
  void warning(String message, {String? id, List<T>? features}) =>
      _log(MessageType.warning, message, id: id, features: features);

  /// Logs an error.
  void error(String message, {String? id, List<T>? features}) =>
      _log(MessageType.error, message, id: id, features: features);

  /// Clears the retained [log] and notifies stream subscribers.
  void clearLog() {
    _entries.clear();
    _emit();
  }

  /// Releases the broadcast stream controller. Call when the logger's owner
  /// is disposed.
  Future<void> dispose() => _controller.close();

  void _log(
    MessageType type,
    String message, {
    String? id,
    List<T>? features,
  }) {
    if (!isDebugMode && !isDeveloper) return;

    if (listeningToIds != null && id != null && !listeningToIds!.contains(id)) {
      return;
    }
    if (listeningToFeatures != null &&
        features != null &&
        !features.any(listeningToFeatures!.contains)) {
      return;
    }
    if (ignoringFeatures != null &&
        features != null &&
        features.any(ignoringFeatures!.contains)) {
      return;
    }
    if (listeningToMessageTypes != null &&
        !listeningToMessageTypes!.contains(type)) {
      return;
    }

    final needsFrame = includeStackTrace || listeningToFunctions != null;
    final frame = needsFrame ? _callerFrame() : null;
    final functionName = _functionNameOf(frame);

    if (listeningToFunctions != null &&
        functionName != null &&
        !listeningToFunctions!.contains(functionName)) {
      return;
    }

    final stackTraceStr = (includeStackTrace && frame != null)
        ? '\n  at ${frame.uri}:${frame.line}:${frame.column} (${frame.member})'
        : '';

    final String content;
    if (formatter != null) {
      content = formatter!(
        type: type,
        message: message,
        id: id,
        features: features,
        stackTrace: stackTraceStr.isEmpty ? null : stackTraceStr,
      );
    } else {
      content = _defaultFormat(type, message, id, features, stackTraceStr);
    }

    final entry = Message<T>(content: content, type: type, features: features);

    final effectiveSink = sink ?? (isDebugMode ? _debugSink : null);
    effectiveSink?.call(entry);

    _entries.add(entry);
    if (maxLogEntries != null && _entries.length > maxLogEntries!) {
      _entries.removeRange(0, _entries.length - maxLogEntries!);
    }
    _emit();
  }

  String _defaultFormat(
    MessageType type,
    String message,
    String? id,
    List<T>? features,
    String stackTraceStr,
  ) {
    final prefix = prefixBuilder?.call(type) ?? _defaultPrefix(type);
    final featureStr = (features != null && features.isNotEmpty)
        ? ' [${features.map((f) => f.toString().split('.').last).join(', ')}]'
        : '';
    final idStr = id != null ? ' [ID: $id]' : '';
    return '$prefix$featureStr$idStr$stackTraceStr $message';
  }

  static String _defaultPrefix(MessageType type) {
    switch (type) {
      case MessageType.info:
        return '[INFO]';
      case MessageType.warning:
        return '[WARNING]';
      case MessageType.error:
        return '[ERROR]';
    }
  }

  void _debugSink(Message<T> message) => debugPrint(message.content);

  void _emit() => _controller.add(List<Message<T>>.unmodifiable(_entries));

  /// Returns the first stack frame outside this file, i.e. the real caller.
  Frame? _callerFrame() {
    final frames = Chain.current().toTrace().frames;
    for (final f in frames) {
      final uri = f.uri.toString();
      if (!uri.endsWith('/lib/logger.dart') &&
          !uri.endsWith('logger/logger.dart')) {
        return f;
      }
    }
    return frames.length > 1 ? frames[1] : null;
  }

  /// Extracts a usable function name from a frame, or null if the caller is
  /// anonymous/unnamed (e.g. `<fn>`, `<closure>`, empty).
  static String? _functionNameOf(Frame? frame) {
    final member = frame?.member;
    if (member == null || member.isEmpty) return null;
    final parts = member.split('.');
    final name = parts.length > 1 ? parts[1] : parts[0];
    if (name.isEmpty || name.startsWith('<')) return null;
    return name;
  }
}
