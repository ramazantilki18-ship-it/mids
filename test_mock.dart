import 'lib/data/mock_data.dart';

void main() {
  try {
    print('Audits: ${MockData.auditHistory.length}');
  } catch (e, stacktrace) {
    print('Error: $e');
    print(stacktrace);
  }
}
