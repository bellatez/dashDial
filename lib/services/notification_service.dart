import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/contact.dart';
import 'database_helper.dart';
import 'contact_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ContactService _contactService = ContactService();
  
  static const String _dueCallChannelId = 'due_call_channel';
  static const String _reminderChannelId = 'reminder_channel';

  Future<void> initialize() async {
    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel dueCallChannel = AndroidNotificationChannel(
      _dueCallChannelId,
      'Due Call Notifications',
      description: 'Notifications for contacts due for a call',
      importance: Importance.high,
    );

    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      _reminderChannelId,
      'Call Reminders',
      description: 'Frequency-based call reminders',
      importance: Importance.max,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(dueCallChannel);
        
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);
  }

  Future<void> scheduleDueCallNotifications() async {
    try {
      // Cancel existing due call notifications
      await _notifications.cancelAll();

      // Get contacts due for call
      final dueContacts = await _contactService.getContactsDueForCall();
      
      if (dueContacts.isEmpty) {
        return;
      }
      
      // Limit to 5 notifications to avoid overwhelming the user
      final limitedContacts = dueContacts.take(5).toList();
      
      // Schedule notifications with small delays to prevent blocking
      for (int i = 0; i < limitedContacts.length; i++) {
        final contact = limitedContacts[i];
        if (contact.name.isNotEmpty && contact.phoneNumber?.isNotEmpty == true) {
          await _scheduleDueCallNotification(contact);
          // Add small delay between notifications to prevent overwhelming
          if (i < limitedContacts.length - 1) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }
    } catch (e) {
      print('Error scheduling due call notifications: $e');
    }
  }

Future<void> _scheduleDueCallNotification(Contact contact) async {
    final id = contact.id.hashCode;
    
    // Schedule for evening (6-8 PM) today or tomorrow if past that time
    final now = DateTime.now();
    final today6PM = DateTime(now.year, now.month, now.day, 18, 0, 0);
    final today8PM = DateTime(now.year, now.month, now.day, 20, 0, 0);
    
    // Calculate next notification time
    DateTime nextNotificationTime;
    if (now.isBefore(today6PM)) {
      // Before 6 PM, schedule for today between 6-8 PM
      final randomMinutes = Random().nextInt(121); // 0-120 minutes
      nextNotificationTime = today6PM.add(Duration(minutes: randomMinutes));
    } else if (now.isBefore(today8PM)) {
      // Between 6-8 PM, schedule for today within the window
      final remainingMinutes = today8PM.difference(now).inMinutes;
      final randomMinutes = Random().nextInt(remainingMinutes + 1);
      nextNotificationTime = now.add(Duration(minutes: randomMinutes));
    } else {
      // After 8 PM, schedule for tomorrow between 6-8 PM
      final tomorrow6PM = today6PM.add(const Duration(days: 1));
      final randomMinutes = Random().nextInt(121); // 0-120 minutes
      nextNotificationTime = tomorrow6PM.add(Duration(minutes: randomMinutes));
    }
    
    // For now, just show immediate notification (scheduling will be added later)
    await _notifications.show(
      id,
      'Time to reconnect!',
      'Call ${contact.name} - they\'re due for a call',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _dueCallChannelId,
          'Due Call Notifications',
          channelDescription: 'Notifications for contacts due for a call',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> scheduleFrequencyReminders() async {
    try {
      // Cancel existing reminder notifications
      await _notifications.cancelAll();

      final frequencyString = await _dbHelper.getSetting('call_frequency');
      final frequency = CallFrequency.values.firstWhere(
        (f) => f.name == frequencyString,
        orElse: () => CallFrequency.weekly,
      );

      // Get all active contacts
      final allContacts = await _dbHelper.readAllContacts();
      final activeContacts = allContacts.where((c) => c.isActive).toList();

      if (activeContacts.isEmpty) {
        return;
      }

      // Limit to 3 notifications to avoid overwhelming the user
      final limitedContacts = activeContacts.take(3).toList();

      // Schedule notifications with small delays to prevent blocking
      for (int i = 0; i < limitedContacts.length; i++) {
        final contact = limitedContacts[i];
        if (contact.name.isNotEmpty && contact.phoneNumber?.isNotEmpty == true) {
          if (contact.isFavorite) {
            await _scheduleFrequencyReminder(contact, frequency);
          } else {
            await _scheduleDefaultReminder(contact, frequency);
          }
          // Add small delay between notifications to prevent overwhelming
          if (i < limitedContacts.length - 1) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }
    } catch (e) {
      print('Error scheduling frequency reminders: $e');
    }
  }

  Future<void> _scheduleFrequencyReminder(Contact contact, CallFrequency frequency) async {
    final id = 'reminder_${contact.id}'.hashCode;
    
    // For now, just show immediate notification (scheduling will be added later)
    await _notifications.show(
      id,
      'Call Reminder',
      'Time to call ${contact.name} - ${frequency.displayName} reminder',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Call Reminders',
          channelDescription: 'Frequency-based call reminders',
          importance: Importance.max,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          // Add call action buttons
          actions: [
            AndroidNotificationAction(
              'call_${contact.id}',
              'Call Now',
              icon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'snooze_${contact.id}',
              'Snooze',
              icon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
              showsUserInterface: false,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // Add iOS actions
          categoryIdentifier: 'CALL_REMINDER_CATEGORY',
        ),
      ),
      payload: 'reminder_${contact.id}',
    );
  }

  Future<void> _scheduleDefaultReminder(Contact contact, CallFrequency frequency) async {
    final id = 'reminder_${contact.id}'.hashCode;
    
    // For now, just show immediate notification (scheduling will be added later)
    await _notifications.show(
      id,
      'Call Reminder',
      'Time to call ${contact.name} - ${frequency.displayName} reminder',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Call Reminders',
          channelDescription: 'Frequency-based call reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _onNotificationTapped(NotificationResponse notificationResponse) async {
    final actionId = notificationResponse.actionId;
    final payload = notificationResponse.payload;
    
    // Always dismiss the notification when tapped
    await _notifications.cancel(notificationResponse.id!);
    
    // Handle call action from favorite notifications
    if (actionId != null && actionId.startsWith('call_')) {
      // Extract contact ID from action ID
      final contactId = actionId.replaceFirst('call_', '');
      
      try {
        // Get contact details
        final contacts = await _dbHelper.readAllContacts();
        final contact = contacts.firstWhere((c) => c.id == contactId);
        
        if (contact != null) {
          // Make the call directly
          await _contactService.launchCallOptions(
            contact.phoneNumber,
            useWhatsApp: false,
          );
          
          // Mark the call as completed for favorites
          if (contact.isFavorite) {
            await _contactService.markFavoriteCallCompleted(contactId);
          }
        }
      } catch (e) {
        // Silent error handling for production
      }
    }
    // Handle snooze action
    else if (actionId != null && actionId.startsWith('snooze_')) {
      final contactId = actionId.replaceFirst('snooze_', '');
      // TODO: Implement snooze functionality - reschedule notification for later
    }
    // Handle test notification action
    else if (actionId == 'call_test') {
      // For test notification, just show that the action works
      // We can't launch a call without a phone number, so we'll just log it
    }
    // Handle due call notifications (existing functionality)
    else if (payload != null && payload.startsWith('due_call_')) {
      // Extract contact ID from payload
      final contactId = payload.replaceFirst('due_call_', '');
      
      try {
        // Get contact details
        final contacts = await _dbHelper.readAllContacts();
        final contact = contacts.firstWhere((c) => c.id == contactId);
        
        if (contact != null) {
          // Make the call directly
          await _contactService.launchCallOptions(
            contact.phoneNumber,
            useWhatsApp: false,
          );
          
          // Add call to history
          await _dbHelper.addCallToHistory(contactId, CallFrequency.weekly);
        }
      } catch (e) {
        // Silent error handling for production
      }
    }
    // Handle reminder notifications - just dismiss (already done above)
    else if (payload != null && payload.startsWith('reminder_')) {
      // Just dismiss the reminder notification (already done above)
    }
    // Handle any other notification tap - just dismiss (already done above)
    else {
      // Notification body tapped - just dismiss and open app
    }
  }

  Future<void> requestNotificationPermission() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Request notification permission
      await androidPlugin.requestNotificationsPermission();
      
      // Request exact alarm permission for precise reminders
      await _requestExactAlarmPermission();
      return;
    }
    
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return;
    }
  }
  
  Future<bool> _requestExactAlarmPermission() async {
    try {
      // Check if we have exact alarm permission
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // For Android 12+, we need to check and request exact alarm permission
        // This is a simplified approach - in production, you'd want to guide users to settings
        return true; // Placeholder - actual implementation would check permission status
      }
    } catch (e) {
      // Silent error handling for production
    }
    return false;
  }

  Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      return granted ?? false;
    }
    
    // For iOS, assume notifications are enabled (will be checked at runtime)
    return true;
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
