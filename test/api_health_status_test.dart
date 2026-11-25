import 'package:flutter_test/flutter_test.dart';
import 'package:budowa_group/api_health_status.dart';

void main() {
  test('v0.4 health has no write permission or confirmed source', () {
    final health = ApiHealthStatus.fromResponse({
      'ok': true, 'role': 'owner', 'version': '0.4',
    });
    expect(health.canWriteTest, isFalse);
    expect(health.dataSource, 'не підтверджено');
    expect(health.version, '0.4');
  });

  test('v0.5 owner requires all explicit write capabilities', () {
    final health = ApiHealthStatus.fromResponse({
      'ok': true, 'role': 'owner', 'version': '0.5',
      'dataSource': 'BG TEST Android API',
      'capabilities': {'write': true, 'create': true, 'update': true},
    });
    expect(health.canWriteTest, isTrue);
    expect(health.dataSource, 'BG TEST Android API');
  });

  test('v0.6 owner recognizes TEST-only explicit write capabilities', () {
    final health = ApiHealthStatus.fromResponse({
      'ok': true, 'role': 'owner', 'version': '0.6',
      'dataSource': 'BG TEST Android API',
      'capabilities': {'write': true, 'create': true, 'update': true},
    });
    expect(health.canWriteTest, isTrue);
  });

  test('admin is always read-only despite server write flags', () {
    final health = ApiHealthStatus.fromResponse({
      'ok': true, 'role': 'admin', 'version': '0.5',
      'dataSource': 'BG TEST Android API',
      'capabilities': {'write': true, 'create': true, 'update': true},
    });
    expect(health.canWriteTest, isFalse);
  });

  test('partial flags fail closed', () {
    for (final flags in [
      {'write': true, 'create': true},
      {'write': true, 'update': true},
      {'write': true, 'create': true, 'update': false},
      <String, bool>{},
    ]) {
      final health = ApiHealthStatus.fromResponse({
        'ok': true, 'role': 'owner', 'version': '0.5',
        'dataSource': 'BG TEST Android API', 'capabilities': flags,
      });
      expect(health.canWriteTest, isFalse);
    }
  });

  test('owner cannot write through an unrecognized TEST server source', () {
    final response = {
      'ok': true,
      'role': 'owner',
      'version': '0.5',
      'dataSource': 'UNKNOWN',
      'capabilities': {'write': true, 'create': true, 'update': true},
    };
    expect(ApiHealthStatus.fromResponse(response).canWriteTest, isFalse);
    response['dataSource'] = 'BG TEST Android API';
    response['version'] = '0.4';
    expect(ApiHealthStatus.fromResponse(response).canWriteTest, isFalse);
  });

  test('unrecognized roles or failed health cannot authorize access', () {
    for (final role in ['viewer', 'none', null]) {
      expect(
        () => ApiHealthStatus.fromResponse({'ok': true, 'role': role}),
        throwsFormatException,
      );
    }
    expect(
      () => ApiHealthStatus.fromResponse({'ok': false, 'role': 'owner'}),
      throwsFormatException,
    );
  });

  test('unknown version or source are labeled unverified', () {
    final health = ApiHealthStatus.fromResponse({
      'ok': true, 'role': 'owner',
      'version': '0.5<bad>', 'dataSource': 'LIVE',
    });
    expect(health.version, 'невідома');
    expect(health.dataSource, 'не підтверджено');
  });
}
