import 'package:flutter_contacts/flutter_contacts.dart' as flutter_contacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact.dart';
import 'database_helper.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<bool> requestPermissions() async {
    final contactsPermission = await Permission.contacts.request();
    return contactsPermission.isGranted;
  }

  Future<bool> hasPermissions() async {
    return await Permission.contacts.isGranted;
  }

  Future<List<Contact>> importDeviceContacts() async {
    if (!await hasPermissions()) {
      if (!await requestPermissions()) {
        throw Exception('Contacts permission denied');
      }
    }

    if (!await flutter_contacts.FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission denied');
    }

    final deviceContacts = await flutter_contacts.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    List<Contact> importedContacts = [];

    for (var deviceContact in deviceContacts) {
      if (deviceContact.phones.isNotEmpty) {
        String phoneNumber = deviceContact.phones.first.number;
        String name = deviceContact.displayName;
        String? email = deviceContact.emails.isNotEmpty 
            ? deviceContact.emails.first.address 
            : null;

        String contactId = deviceContact.id ?? 
            '${name}_${phoneNumber}_${DateTime.now().millisecondsSinceEpoch}';

        Contact newContact = Contact(
          id: contactId,
          name: name,
          phoneNumber: phoneNumber,
          email: email,
        );

        // Check if contact already exists
        Contact? existingContact = await _dbHelper.readContact(contactId);
        if (existingContact == null) {
          await _dbHelper.createContact(newContact);
          importedContacts.add(newContact);
        }
      }
    }

    return importedContacts;
  }

  Future<List<Contact>> getLocalContacts() async {
    return await _dbHelper.readAllContacts();
  }

  Future<List<Contact>> getActiveContacts() async {
    return await _dbHelper.readActiveContacts();
  }

  Future<Contact> getRandomContact() async {
    return await _dbHelper.getRandomContactWithPriority();
  }

  Future<void> updateContact(Contact contact) async {
    await _dbHelper.updateContact(contact);
  }

  Future<void> toggleContactActive(String contactId, bool isActive) async {
    Contact? contact = await _dbHelper.readContact(contactId);
    if (contact != null) {
      Contact updatedContact = contact.copyWith(isActive: isActive);
      await _dbHelper.updateContact(updatedContact);
    }
  }

  Future<void> deleteContact(String contactId) async {
    await _dbHelper.deleteContact(contactId);
  }

  Future<void> markCallCompleted(String contactId, CallFrequency frequency) async {
    await _dbHelper.addCallToHistory(contactId, frequency);
  }

  Future<List<Map<String, dynamic>>> getCallHistory(String contactId) async {
    return await _dbHelper.getCallHistory(contactId);
  }

  Future<int> getActiveContactCount() async {
    final contacts = await getActiveContacts();
    return contacts.length;
  }

  Future<int> getTotalCallsCount() async {
    final List<Contact> contacts = await getLocalContacts();
    int total = 0;
    for (final contact in contacts) {
      total += contact.callCount;
    }
    return total;
  }

  Future<List<Contact>> getRecentlyCalled(int days) async {
    final List<Contact> contacts = await getLocalContacts();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    return contacts.where((Contact contact) {
      return contact.lastCalled != null && 
             contact.lastCalled!.isAfter(cutoffDate);
    }).toList();
  }

  Future<List<Contact>> getMostCalled(int limit) async {
    final List<Contact> contacts = await getLocalContacts();
    contacts.sort((Contact a, Contact b) => b.callCount.compareTo(a.callCount));
    return contacts.take(limit).toList();
  }

  // New methods for gamification
  Future<Map<String, dynamic>> getYearlyProgress(int year) async {
    return await _dbHelper.getYearlyProgress(year);
  }

  Future<int> getCurrentStreak() async {
    return await _dbHelper.getCurrentStreak();
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    return await _dbHelper.getAchievements();
  }

  Future<void> updateYearlyGoal(int year, int targetCalls) async {
    await _dbHelper.updateYearlyGoal(year, targetCalls);
  }

  // Calling methods with WhatsApp support
  Future<bool> makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      print('Error: Phone number is null or empty');
      return false;
    }
    
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Try multiple phone URI formats
    final List<Uri> phoneUris = [
      Uri.parse('tel:$cleanPhone'),
      Uri.parse('callto:$cleanPhone'),
    ];
    
    for (final uri in phoneUris) {
      print('Attempting to launch phone call with URI: $uri');
      
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri);
          print('Phone call launch result for $uri: $launched');
          if (launched) return true;
        } else {
          print('Cannot launch phone call URI: $uri');
        }
      } catch (e) {
        print('Error launching phone call with $uri: $e');
      }
    }
    
    print('All phone call launch methods failed');
    return false;
  }

  Future<bool> makeWhatsAppCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      print('Error: Phone number is null or empty');
      return false;
    }
    
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Try multiple WhatsApp URI formats
    final List<Uri> whatsappUris = [
      Uri.parse('https://wa.me/$cleanPhone'),
      Uri.parse('whatsapp://send?phone=$cleanPhone'),
      Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone'),
    ];
    
    for (final uri in whatsappUris) {
      print('Attempting to launch WhatsApp with URI: $uri');
      
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri);
          print('WhatsApp launch result for $uri: $launched');
          if (launched) return true;
        } else {
          print('Cannot launch WhatsApp URI: $uri');
        }
      } catch (e) {
        print('Error launching WhatsApp with $uri: $e');
      }
    }
    
    // If all WhatsApp methods fail, try opening WhatsApp directly
    try {
      final whatsappUri = Uri.parse('whatsapp://');
      if (await canLaunchUrl(whatsappUri)) {
        print('Opening WhatsApp app directly');
        return await launchUrl(whatsappUri);
      }
    } catch (e) {
      print('Error opening WhatsApp app: $e');
    }
    
    print('All WhatsApp launch methods failed');
    return false;
  }

  Future<bool> launchCallOptions(String? phoneNumber, {bool useWhatsApp = false}) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return false;
    
    if (useWhatsApp) {
      return await makeWhatsAppCall(phoneNumber);
    } else {
      return await makePhoneCall(phoneNumber);
    }
  }

  // Favorite management methods
  Future<void> toggleFavorite(String contactId, bool isFavorite) async {
    await _dbHelper.toggleFavorite(contactId, isFavorite);
  }

  Future<void> updateFavoriteFrequency(String contactId, CallFrequency? frequency) async {
    await _dbHelper.updateFavoriteFrequency(contactId, frequency);
  }

  Future<List<Contact>> getFavoriteContacts() async {
    return await _dbHelper.getFavoriteContacts();
  }

  Future<List<Contact>> getFavoriteContactsByFrequency(CallFrequency frequency) async {
    return await _dbHelper.getFavoriteContactsByFrequency(frequency);
  }

  Future<List<Contact>> getContactsDueForCall() async {
    return await _dbHelper.getContactsDueForCall();
  }

  Future<void> markFavoriteCallCompleted(String contactId) async {
    final contact = await _dbHelper.readContact(contactId);
    if (contact != null && contact.favoriteFrequency != null) {
      await _dbHelper.addCallToHistory(contactId, contact.favoriteFrequency!);
    }
  }

  // Frequency goal progress methods
  Future<Map<String, dynamic>> getFrequencyGoalProgress() async {
    final frequencyString = await _dbHelper.getSetting('call_frequency');
    final frequency = CallFrequency.values.firstWhere(
      (f) => f.name == frequencyString,
      orElse: () => CallFrequency.weekly,
    );

    final goalKey = '${frequency.name}_goal';
    final goalValue = await _dbHelper.getSetting(goalKey);
    final goal = int.tryParse(goalValue) ?? 1;

    // Calculate current period calls
    final now = DateTime.now();
    DateTime periodStart;
    
    switch (frequency) {
      case CallFrequency.daily:
        periodStart = DateTime(now.year, now.month, now.day);
        break;
      case CallFrequency.weekly:
        periodStart = now.subtract(Duration(days: now.weekday - 1));
        periodStart = DateTime(periodStart.year, periodStart.month, periodStart.day);
        break;
      case CallFrequency.monthly:
        periodStart = DateTime(now.year, now.month, 1);
        break;
    }

    final currentCalls = await _dbHelper.getCallsInPeriod(periodStart, now);
    final progress = goal > 0 ? (currentCalls / goal) * 100 : 0.0;
    final remaining = goal - currentCalls;

    return {
      'frequency': frequency,
      'goal': goal,
      'current_calls': currentCalls,
      'progress_percentage': progress,
      'remaining_calls': remaining,
      'period_start': periodStart,
    };
  }

  Future<int> calculateYearlyGoalFromFrequency() async {
    final frequencyString = await _dbHelper.getSetting('call_frequency');
    final frequency = CallFrequency.values.firstWhere(
      (f) => f.name == frequencyString,
      orElse: () => CallFrequency.weekly,
    );

    final goalKey = '${frequency.name}_goal';
    final goalValue = await _dbHelper.getSetting(goalKey);
    final goalPerPeriod = int.tryParse(goalValue) ?? 1;

    // Calculate yearly goal based on frequency
    switch (frequency) {
      case CallFrequency.daily:
        return goalPerPeriod * 365;
      case CallFrequency.weekly:
        return goalPerPeriod * 52;
      case CallFrequency.monthly:
        return goalPerPeriod * 12;
    }
  }
}
