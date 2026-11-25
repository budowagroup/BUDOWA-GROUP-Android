/// Server health contract for the BUDOWA GROUP Android TEST client.
/// Older API v0.4 responses default to read-only.
class ApiHealthStatus {
  final String role;
  final String version;
  final String dataSource;
  final bool canWriteTest;

  const ApiHealthStatus({
    required this.role,
    required this.version,
    required this.dataSource,
    required this.canWriteTest,
  });

  factory ApiHealthStatus.fromResponse(Map<String, dynamic> response) {
    final role = response['role'];
    if (response['ok'] != true || (role != 'owner' && role != 'admin')) {
      throw const FormatException('Некоректні права доступу в API');
    }

    final capabilities = response['capabilities'];
    final canWrite = role == 'owner' &&
        (response['version'] == '0.5' || response['version'] == '0.6') &&
        response['dataSource'] == 'BG TEST Android API' &&
        capabilities is Map &&
        capabilities['write'] == true &&
        capabilities['create'] == true &&
        capabilities['update'] == true;

    final rawVersion = response['version'];
    final version = rawVersion is String &&
            RegExp(r'^[0-9.]{1,12}$').hasMatch(rawVersion)
        ? rawVersion
        : 'невідома';

    // A legacy API may not report its source. Never guess the workbook.
    final dataSource = response['dataSource'] == 'BG TEST Android API'
        ? 'BG TEST Android API'
        : 'не підтверджено';

    return ApiHealthStatus(
      role: role,
      version: version,
      dataSource: dataSource,
      canWriteTest: canWrite,
    );
  }
}
