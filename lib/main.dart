import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:konkur_planner/database/database_helper.dart';
import 'package:konkur_planner/providers/app_data_provider.dart';
import 'package:konkur_planner/screens/ai_agent_screen.dart';
import 'package:konkur_planner/screens/my_plan_screen.dart';
import 'package:konkur_planner/screens/my_subjects_screen.dart';
import 'package:konkur_planner/screens/syllabus_breakdown_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      child: MaterialApp(
        title: 'Konkur AI Study Planner',
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
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    AIAgentScreen(),
    SyllabusBreakdownScreen(),
    MySubjectsScreen(),
    MyPlanScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'هوش مصنوعی',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'بودجه بندی',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist),
            label: 'درس های من',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'برنامه من',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
