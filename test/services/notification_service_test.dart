import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:konkur_planner/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service_test.mocks.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
void main() {
  group('NotificationService', () {
    late NotificationService notificationService;
    late MockFlutterLocalNotificationsPlugin mockFlutterLocalNotificationsPlugin;

    setUp(() {
      mockFlutterLocalNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
      notificationService = NotificationService(
        flutterLocalNotificationsPlugin: mockFlutterLocalNotificationsPlugin,
      );
      // tz.initializeTimeZones(); // Removed as it's handled by NotificationService.init()
    });

    test('init initializes the plugin', () async {
      when(mockFlutterLocalNotificationsPlugin.initialize(
        any,
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      await notificationService.init();

      verify(mockFlutterLocalNotificationsPlugin.initialize(
        any,
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).called(1);
    });

    test('scheduleNotification schedules a notification', () async {
      when(mockFlutterLocalNotificationsPlugin.zonedSchedule(
        any, any, any, any, any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async => {});

      final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

      await notificationService.scheduleNotification(
        id: 1,
        title: 'Test Title',
        body: 'Test Body',
        scheduledDate: scheduledDate,
        payload: 'test_payload',
      );

      verify(mockFlutterLocalNotificationsPlugin.zonedSchedule(
        1,
        'Test Title',
        'Test Body',
        tz.TZDateTime.from(scheduledDate, tz.local),
        any,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'test_payload',
      )).called(1);
    });

    test('cancelNotification cancels a specific notification', () async {
      when(mockFlutterLocalNotificationsPlugin.cancel(any)).thenAnswer((_) async => {});

      await notificationService.cancelNotification(1);

      verify(mockFlutterLocalNotificationsPlugin.cancel(1)).called(1);
    });

    test('cancelAllNotifications cancels all notifications', () async {
      when(mockFlutterLocalNotificationsPlugin.cancelAll()).thenAnswer((_) async => {});

      await notificationService.cancelAllNotifications();

      verify(mockFlutterLocalNotificationsPlugin.cancelAll()).called(1);
    });
  });
}