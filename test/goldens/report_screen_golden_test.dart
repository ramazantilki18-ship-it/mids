import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:denetim_app/screens/report_screen.dart';
import 'package:denetim_app/providers/audit_provider.dart';
import 'package:denetim_app/providers/nonconformity_provider.dart';
import 'package:denetim_app/providers/system_provider.dart';
import 'package:denetim_app/providers/auth_provider.dart';
import 'package:denetim_app/data/mock_data.dart';
void main() {
  testWidgets('ReportScreen golden', (WidgetTester tester) async {
    // create real providers and pre-login a user so ReportScreen shows content
    final authProvider = AuthProvider();
    await authProvider.login(MockData.users.first.username, '12345', rememberMe: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        builder: (context, child) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<AuditProvider>(create: (_) => AuditProvider()),
              ChangeNotifierProvider<NonconformityProvider>(create: (_) => NonconformityProvider()),
              ChangeNotifierProvider<SystemProvider>(create: (_) => SystemProvider()),
            ],
            child: const MaterialApp(home: Scaffold(body: ReportScreen())),
          );
        },
      ),
    );

    // Allow providers to initialize
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await expectLater(find.byType(ReportScreen), matchesGoldenFile('goldens/report_screen.png'));
  }, semanticsEnabled: false);
}
