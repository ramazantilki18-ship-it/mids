import 'dart:io' show Platform;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'firebase_options.dart';
import 'providers/audit_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/feedback_provider.dart';
import 'providers/nonconformity_provider.dart';
import 'providers/system_provider.dart';
import 'services/field_tracking_service.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Flutter UI Hata Yakalayıcı
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('GLOBAL FLUTTER ERROR: ${details.exceptionAsString()}');
  };

  // Asenkron ve Arka Plan Hatalarının Uygulamayı Çökertmesini (Crash) Engelleyen Global Yakalayıcı
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('GLOBAL ASYNC ERROR CAUGHT (App Crash Prevented): $error\n$stack');
    return true; // Crash'i önler
  };

  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    debugPrint('DateFormatting init error: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: !kIsWeb,
      cacheSizeBytes: kIsWeb ? 104857600 : Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  if (!kIsWeb && Platform.isWindows) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint('Sqflite FFI init error: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SystemProvider()),
        ChangeNotifierProvider(create: (_) => NonconformityProvider()),
        ChangeNotifierProvider(create: (_) => AuditProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => FieldTrackingService()),
      ],
      child: Consumer<SystemProvider>(
        builder: (context, system, child) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Metro Istanbul Denetim Uygulamasi',
            theme: system.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
