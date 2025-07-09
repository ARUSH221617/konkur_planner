import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:konkur_planner/screens/ai_agent_screen.dart';
import 'package:konkur_planner/screens/my_plan_screen.dart';
import 'package:konkur_planner/screens/my_subjects_screen.dart';
import 'package:konkur_planner/screens/syllabus_breakdown_screen.dart';

// Private navigators
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'aiAgent',
          builder: (context, state) => const AIAgentScreen(),
        ),
        GoRoute(
          path: '/syllabus',
          name: 'syllabus',
          builder: (context, state) => const SyllabusBreakdownScreen(),
        ),
        GoRoute(
          path: '/my-subjects',
          name: 'mySubjects',
          builder: (context, state) => const MySubjectsScreen(),
        ),
        GoRoute(
          path: '/my-plan',
          name: 'myPlan',
          builder: (context, state) => const MyPlanScreen(),
        ),
      ],
    ),
  ],
);

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
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
        currentIndex: _calculateSelectedIndex(context),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location == '/') {
      return 0;
    }
    if (location == '/syllabus') {
      return 1;
    }
    if (location == '/my-subjects') {
      return 2;
    }
    if (location == '/my-plan') {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/');
        break;
      case 1:
        GoRouter.of(context).go('/syllabus');
        break;
      case 2:
        GoRouter.of(context).go('/my-subjects');
        break;
      case 3:
        GoRouter.of(context).go('/my-plan');
        break;
    }
  }
}
