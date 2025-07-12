import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:konkur_planner/database/database_helper.dart';
import 'package:konkur_planner/providers/app_data_provider.dart';
import 'package:konkur_planner/routing/app_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    // Initialize for web
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await DatabaseHelper()
      .database; // Initialize the database and insert initial data
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppDataProvider(),
      child: MaterialApp.router(
        title: 'Konkur AI Study Planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
          ),
          fontFamily: 'IRANSans',
          textTheme: const TextTheme(
            titleLarge: TextStyle(fontFamily: 'IRANSans'),
            titleMedium: TextStyle(fontFamily: 'IRANSans'),
            titleSmall: TextStyle(fontFamily: 'IRANSans'),
            bodyLarge: TextStyle(fontFamily: 'IRANSans'),
            bodyMedium: TextStyle(fontFamily: 'IRANSans'),
            bodySmall: TextStyle(fontFamily: 'IRANSans'),
            displayLarge: TextStyle(fontFamily: 'IRANSans'),
            displayMedium: TextStyle(fontFamily: 'IRANSans'),
            displaySmall: TextStyle(fontFamily: 'IRANSans'),
            headlineLarge: TextStyle(fontFamily: 'IRANSans'),
            headlineMedium: TextStyle(fontFamily: 'IRANSans'),
            headlineSmall: TextStyle(fontFamily: 'IRANSans'),
            labelLarge: TextStyle(fontFamily: 'IRANSans'),
            labelMedium: TextStyle(fontFamily: 'IRANSans'),
            labelSmall: TextStyle(fontFamily: 'IRANSans'),
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}
