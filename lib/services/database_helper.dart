import 'dart:async';
import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/contact.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dashdial.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, filePath);
    
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL DEFAULT 1';

    await db.execute('''
      CREATE TABLE contacts (
        id $idType,
        name $textType,
        phone_number $textNullableType,
        email $textNullableType,
        last_called $textNullableType,
        call_count $integerType DEFAULT 0,
        is_active $boolType,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        favorite_frequency $textNullableType
      )
    ''');

    await db.execute('''
      CREATE TABLE call_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id $textType,
        call_date $textNullableType,
        frequency $textNullableType,
        FOREIGN KEY (contact_id) REFERENCES contacts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE yearly_goals (
        year INTEGER PRIMARY KEY,
        target_calls INTEGER NOT NULL DEFAULT 260,
        created_at $textNullableType
      )
    ''');

    await db.execute('''
      CREATE TABLE achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        achievement_type $textType,
        title $textType,
        description $textNullableType,
        unlocked_at $textNullableType,
        is_unlocked $boolType DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE call_streaks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date $textNullableType,
        end_date $textNullableType,
        length_days INTEGER NOT NULL,
        is_active $boolType DEFAULT 0
      )
    ''');

    // Insert default settings
    await db.insert('settings', {
      'key': 'call_frequency',
      'value': 'weekly',
    });

    // Insert current year goal
    final currentYear = DateTime.now().year;
    await db.insert('yearly_goals', {
      'year': currentYear,
      'target_calls': 260, // 5 calls per week
      'created_at': DateTime.now().toIso8601String(),
    });

    // Insert default achievements
    await db.insert('achievements', {
      'achievement_type': 'first_call',
      'title': 'First Connection',
      'description': 'Made your first call through Dash Dial',
      'is_unlocked': 0,
    });

    await db.insert('achievements', {
      'achievement_type': 'weekly_warrior',
      'title': 'Weekly Warrior',
      'description': 'Made 5 calls in one week',
      'is_unlocked': 0,
    });

    await db.insert('achievements', {
      'achievement_type': 'monthly_champion',
      'title': 'Monthly Champion',
      'description': 'Made 20 calls in one month',
      'is_unlocked': 0,
    });

    await db.insert('achievements', {
      'achievement_type': 'streak_master',
      'title': 'Streak Master',
      'description': 'Maintained a 7-day calling streak',
      'is_unlocked': 0,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE call_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contact_id $textType,
          call_date $textNullableType,
          frequency $textNullableType,
          FOREIGN KEY (contact_id) REFERENCES contacts (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value $textType
        )
      ''');

      await db.insert('settings', {
        'key': 'call_frequency',
        'value': 'weekly',
      });
    }

    if (oldVersion < 3) {
      // Add favorite fields to existing contacts table
      await db.execute('ALTER TABLE contacts ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE contacts ADD COLUMN favorite_frequency $textNullableType');
    }
  }

  Future<Contact> createContact(Contact contact) async {
    final db = await instance.database;
    await db.insert('contacts', contact.toMap());
    return contact;
  }

  Future<Contact?> readContact(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Contact.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Contact>> readAllContacts() async {
    final db = await instance.database;
    final result = await db.query('contacts', orderBy: 'name ASC');
    return result.map((json) => Contact.fromMap(json)).toList();
  }

  Future<List<Contact>> readActiveContacts() async {
    final db = await instance.database;
    final result = await db.query(
      'contacts',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return result.map((json) => Contact.fromMap(json)).toList();
  }

  Future<int> updateContact(Contact contact) async {
    final db = await instance.database;
    return db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<int> deleteContact(String id) async {
    final db = await instance.database;
    return await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addCallToHistory(String contactId, CallFrequency frequency) async {
    final db = await instance.database;
    await db.insert('call_history', {
      'contact_id': contactId,
      'call_date': DateTime.now().toIso8601String(),
      'frequency': frequency.name,
    });

    // Update contact's last called and call count
    await db.rawUpdate('''
      UPDATE contacts 
      SET last_called = ?, call_count = call_count + 1
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), contactId]);

    // Check and unlock achievements
    await _checkAndUnlockAchievements();
    
    // Update call streak
    await _updateCallStreak();
  }

  Future<void> _checkAndUnlockAchievements() async {
    final db = await instance.database;
    final totalCalls = await getTotalCallsForYear(DateTime.now().year);
    
    // Check first call achievement
    if (totalCalls == 1) {
      await _unlockAchievement('first_call');
    }

    // Check weekly warrior (5 calls in one week)
    final weeklyCalls = await getCallsInPeriod(
      DateTime.now().subtract(const Duration(days: 7)),
      DateTime.now(),
    );
    if (weeklyCalls >= 5) {
      await _unlockAchievement('weekly_warrior');
    }

    // Check monthly champion (20 calls in one month)
    final monthlyCalls = await getCallsInPeriod(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );
    if (monthlyCalls >= 20) {
      await _unlockAchievement('monthly_champion');
    }

    // Check streak master (7-day streak)
    final currentStreak = await getCurrentStreak();
    if (currentStreak >= 7) {
      await _unlockAchievement('streak_master');
    }
  }

  Future<void> _unlockAchievement(String achievementType) async {
    final db = await instance.database;
    await db.update(
      'achievements',
      {
        'is_unlocked': 1,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      where: 'achievement_type = ? AND is_unlocked = 0',
      whereArgs: [achievementType],
    );
  }

  Future<void> _updateCallStreak() async {
    final db = await instance.database;
    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day).toIso8601String();
    
    // Check if there's already a call today
    final todayCalls = await getCallsInPeriod(
      DateTime(today.year, today.month, today.day),
      DateTime(today.year, today.month, today.day, 23, 59, 59),
    );

    if (todayCalls > 0) {
      // Get current active streak
      final activeStreaks = await db.query(
        'call_streaks',
        where: 'is_active = 1',
        orderBy: 'end_date DESC',
        limit: 1,
      );

      if (activeStreaks.isNotEmpty) {
        final streak = activeStreaks.first;
        final endDate = DateTime.parse(streak['end_date'] as String);
        final streakEndDate = DateTime(endDate.year, endDate.month, endDate.day);
        final todayDate = DateTime(today.year, today.month, today.day);
        
        if (streakEndDate.difference(todayDate).inDays == 0) {
          // Same day, no change needed
          return;
        } else if (streakEndDate.difference(todayDate).inDays == -1) {
          // Consecutive day, extend streak
          await db.update(
            'call_streaks',
            {
              'end_date': todayStr,
              'length_days': (streak['length_days'] as int) + 1,
            },
            where: 'id = ?',
            whereArgs: [streak['id']],
          );
        } else {
          // Streak broken, start new one
          await _startNewStreak();
        }
      } else {
        // No active streak, start new one
        await _startNewStreak();
      }
    }
  }

  Future<void> _startNewStreak() async {
    final db = await instance.database;
    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day).toIso8601String();
    
    // Deactivate all existing streaks
    await db.update('call_streaks', {'is_active': 0});
    
    // Start new streak
    await db.insert('call_streaks', {
      'start_date': todayStr,
      'end_date': todayStr,
      'length_days': 1,
      'is_active': 1,
    });
  }

  Future<int> getTotalCallsForYear(int year) async {
    final db = await instance.database;
    final startDate = DateTime(year, 1, 1).toIso8601String();
    final endDate = DateTime(year, 12, 31, 23, 59, 59).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM call_history
      WHERE call_date >= ? AND call_date <= ?
    ''', [startDate, endDate]);
    
    return result.first['count'] as int;
  }

  Future<int> getCallsInPeriod(DateTime startDate, DateTime endDate) async {
    final db = await instance.database;
    final startStr = startDate.toIso8601String();
    final endStr = endDate.toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM call_history
      WHERE call_date >= ? AND call_date <= ?
    ''', [startStr, endStr]);
    
    return result.first['count'] as int;
  }

  Future<int> getCurrentStreak() async {
    final db = await instance.database;
    final activeStreaks = await db.query(
      'call_streaks',
      where: 'is_active = 1',
      orderBy: 'end_date DESC',
      limit: 1,
    );
    
    if (activeStreaks.isNotEmpty) {
      return activeStreaks.first['length_days'] as int;
    }
    
    return 0;
  }

  Future<Map<String, dynamic>> getYearlyProgress(int year) async {
    final db = await instance.database;
    final goalResult = await db.query(
      'yearly_goals',
      where: 'year = ?',
      whereArgs: [year],
    );
    
    final targetCalls = goalResult.isNotEmpty 
        ? goalResult.first['target_calls'] as int
        : 260;
    
    final actualCalls = await getTotalCallsForYear(year);
    final progress = targetCalls > 0 ? (actualCalls / targetCalls * 100).clamp(0.0, 100.0) : 0.0;
    
    return {
      'year': year,
      'target_calls': targetCalls,
      'actual_calls': actualCalls,
      'progress_percentage': progress,
      'remaining_calls': (targetCalls - actualCalls).clamp(0, targetCalls),
    };
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final db = await instance.database;
    return await db.query(
      'achievements',
      orderBy: 'is_unlocked DESC, id ASC',
    );
  }

  Future<void> updateYearlyGoal(int year, int targetCalls) async {
    final db = await instance.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO yearly_goals (year, target_calls, created_at) VALUES (?, ?, ?)',
      [year, targetCalls, DateTime.now().toIso8601String()],
    );
  }

  // Favorite management methods
  Future<void> toggleFavorite(String contactId, bool isFavorite) async {
    final db = await instance.database;
    await db.update(
      'contacts',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  Future<void> updateFavoriteFrequency(String contactId, CallFrequency? frequency) async {
    final db = await instance.database;
    await db.update(
      'contacts',
      {'favorite_frequency': frequency?.name},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  Future<List<Contact>> getFavoriteContacts() async {
    final db = await instance.database;
    final result = await db.query(
      'contacts',
      where: 'is_favorite = 1 AND is_active = 1',
      orderBy: 'name ASC',
    );
    return result.map((json) => Contact.fromMap(json)).toList();
  }

  Future<List<Contact>> getFavoriteContactsByFrequency(CallFrequency frequency) async {
    final db = await instance.database;
    final result = await db.query(
      'contacts',
      where: 'is_favorite = 1 AND is_active = 1 AND favorite_frequency = ?',
      whereArgs: [frequency.name],
      orderBy: 'name ASC',
    );
    return result.map((json) => Contact.fromMap(json)).toList();
  }

  Future<List<Contact>> getContactsDueForCall() async {
    final db = await instance.database;
    final now = DateTime.now();
    final result = await db.query('contacts');
    
    List<Contact> dueContacts = [];
    
    for (final map in result) {
      final contact = Contact.fromMap(map);
      
      if (!contact.isActive) continue;
      
      // Check if favorite and due based on frequency
      if (contact.isFavorite && contact.favoriteFrequency != null) {
        if (_isContactDueForCall(contact, now)) {
          dueContacts.add(contact);
        }
      }
    }
    
    return dueContacts;
  }

  bool _isContactDueForCall(Contact contact, DateTime now) {
    if (contact.lastCalled == null) return true;
    
    final frequency = contact.favoriteFrequency!;
    final daysSinceLastCall = now.difference(contact.lastCalled!).inDays;
    
    switch (frequency) {
      case CallFrequency.daily:
        return daysSinceLastCall >= 1;
      case CallFrequency.weekly:
        return daysSinceLastCall >= 7;
      case CallFrequency.monthly:
        return daysSinceLastCall >= 30;
    }
  }

  Future<List<Map<String, dynamic>>> getCallHistory(String contactId) async {
    final db = await instance.database;
    return await db.query(
      'call_history',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'call_date DESC',
    );
  }

  Future<String> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return 'weekly'; // default
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await instance.database;
    print('Updating setting: $key = $value');
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      [key, value],
    );
    print('Setting updated successfully');
  }

  Future<List<Contact>> getRandomContacts(int count) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT * FROM contacts 
      WHERE is_active = 1 
      ORDER BY RANDOM() 
      LIMIT ?
    ''', [count]);
    
    return result.map((json) => Contact.fromMap(json)).toList();
  }

  Future<Contact> getRandomContact() async {
    final contacts = await getRandomContacts(1);
    return contacts.isNotEmpty ? contacts.first : throw Exception('No active contacts found');
  }

  // Priority-based random selection
  Future<Contact> getRandomContactWithPriority() async {
    final db = await instance.database;
    final now = DateTime.now();
    final nowString = now.toIso8601String();
    
    // Get all active contacts with their priority scores
    final result = await db.rawQuery('''
      SELECT 
        c.*,
        CASE 
          WHEN c.is_favorite = 1 AND c.favorite_frequency IS NOT NULL THEN
            CASE 
              WHEN c.last_called IS NULL THEN 100
              ELSE 
                CASE c.favorite_frequency
                  WHEN 'daily' THEN 
                    CASE 
                      WHEN (julianday('$nowString') - julianday(c.last_called)) * 20 > 100 THEN 0
                      ELSE 100 - (julianday('$nowString') - julianday(c.last_called)) * 20
                    END
                  WHEN 'weekly' THEN 
                    CASE 
                      WHEN (julianday('$nowString') - julianday(c.last_called)) * 10 > 100 THEN 0
                      ELSE 100 - (julianday('$nowString') - julianday(c.last_called)) * 10
                    END
                  WHEN 'monthly' THEN 
                    CASE 
                      WHEN (julianday('$nowString') - julianday(c.last_called)) * 5 > 100 THEN 0
                      ELSE 100 - (julianday('$nowString') - julianday(c.last_called)) * 5
                    END
                  ELSE 50
                END
            END
          WHEN c.is_favorite = 1 THEN 75
          WHEN c.last_called IS NULL THEN 60
          ELSE 
            CASE 
              WHEN (julianday('$nowString') - julianday(c.last_called)) * 2 > 50 THEN 0
              ELSE 50 - (julianday('$nowString') - julianday(c.last_called)) * 2
            END
        END as priority_score
      FROM contacts c
      WHERE c.is_active = 1
      ORDER BY RANDOM()
    ''');
    
    if (result.isEmpty) {
      throw Exception('No active contacts found');
    }
    
    // Weighted random selection based on priority scores
    final contactsWithScores = result.map((row) {
      final contact = Contact.fromMap(row);
      final score = (row['priority_score'] as num).toDouble();
      return MapEntry(contact, score);
    }).toList();
    
    // Calculate total score
    final totalScore = contactsWithScores.fold<double>(0, (sum, entry) => sum + entry.value);
    
    // Generate random number between 0 and totalScore
    final random = Random().nextDouble() * totalScore;
    
    // Select contact based on weighted random
    double currentScore = 0;
    for (final entry in contactsWithScores) {
      currentScore += entry.value;
      if (random <= currentScore) {
        return entry.key;
      }
    }
    
    // Fallback to first contact
    return contactsWithScores.first.key;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
