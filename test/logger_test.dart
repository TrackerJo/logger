import 'package:flutter_test/flutter_test.dart';

import 'package:simple_logger/logger.dart';

enum TestFeature { featureA, featureB, featureC }

void main() {
  group('Logger', () {
    late Logger<TestFeature> logger;

    setUp(() {
      logger = Logger<TestFeature>(
        listeningToIds: ['testId'],
        listeningToFeatures: [TestFeature.featureA],
        listeningToMessageTypes: [MessageType.info, MessageType.warning],

        ignoringFeatures: [TestFeature.featureC],
        includeStackTrace: true,
        isDeveloper: true,
        isDebugMode: true,
      );
    });

    test('logs info messages correctly', () {
      logger.info(
        'This is an info message',
        id: 'testId',
        features: [TestFeature.featureA],
      );
      expect(logger.log.length, 1);
      expect(
        logger.log.first.content.contains('This is an info message'),
        true,
      );
      expect(logger.log.first.type, MessageType.info);
    });

    test('does not log messages with non-listened IDs', () {
      logger.info(
        'This message should not be logged',
        id: 'nonExistentId',
        features: [TestFeature.featureA],
      );
      expect(logger.log.isEmpty, true);
    });

    test('does not log messages with non-listened features', () {
      logger.info(
        'This message should not be logged',
        id: 'testId',
        features: [TestFeature.featureB],
      );
      expect(logger.log.isEmpty, true);
    });

    test('does not log messages with ignored features', () {
      logger.info(
        'This message should not be logged',
        id: 'testId',
        features: [TestFeature.featureC],
      );
      expect(logger.log.isEmpty, true);
    });

    test('routes accepted messages to a custom sink', () {
      final captured = <Message<TestFeature>>[];
      final sinkLogger = Logger<TestFeature>(
        isDebugMode: true,
        sink: captured.add,
      );
      sinkLogger.info('hello', features: [TestFeature.featureA]);
      sinkLogger.error('boom', features: [TestFeature.featureB]);

      expect(captured.length, 2);
      expect(captured.first.type, MessageType.info);
      expect(captured.last.type, MessageType.error);
      expect(captured.last.content.contains('boom'), true);
    });
  });
}
