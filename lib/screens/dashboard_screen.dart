import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:url_launcher/url_launcher.dart';

import '../models/contact.dart';
import '../services/contact_service.dart';
import '../services/database_helper.dart';
import 'contacts_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'favorites_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final ContactService _contactService = ContactService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  Contact? _currentContact;
  bool _isLoading = false;
  int _activeContactCount = 0;
  int _totalCallsCount = 0;
  int _currentStreak = 0;
  int _remainingCalls = 0;
  CallFrequency _frequency = CallFrequency.weekly;
  bool _useWhatsApp = false;
  List<Contact> _favoriteContacts = [];
  List<Contact> _dueFavoriteContacts = [];
  
  // Frequency goal progress variables
  double _frequencyProgress = 0.0;
  int _frequencyGoal = 0;
  int _frequencyCurrentCalls = 0;
  int _frequencyRemainingCalls = 0;
  
  // FAB state
  bool _isFabExpanded = false;
  AnimationController? _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fabAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final activeCount = await _contactService.getActiveContactCount();
      final totalCalls = await _contactService.getTotalCallsCount();
      final frequencyString = await _dbHelper.getSetting('call_frequency');
      final frequency = CallFrequency.values.firstWhere(
        (f) => f.name == frequencyString,
        orElse: () => CallFrequency.weekly,
      );
      final currentStreak = await _contactService.getCurrentStreak();
      final favoriteContacts = await _contactService.getFavoriteContacts();
      final dueFavoriteContacts = await _contactService.getContactsDueForCall();
      
      // Get frequency goal progress
      final frequencyProgress = await _contactService.getFrequencyGoalProgress();
      
      setState(() {
        _activeContactCount = activeCount;
        _totalCallsCount = totalCalls;
        _currentStreak = currentStreak;
        _frequency = frequency;
        _favoriteContacts = favoriteContacts;
        _dueFavoriteContacts = dueFavoriteContacts;
        
        // Update frequency goal progress
        _frequencyProgress = frequencyProgress['progress_percentage'] as double;
        _frequencyGoal = frequencyProgress['goal'] as int;
        _frequencyCurrentCalls = frequencyProgress['current_calls'] as int;
        _frequencyRemainingCalls = frequencyProgress['remaining_calls'] as int;
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _getRandomContact() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contact = await _contactService.getRandomContact();
      setState(() {
        _currentContact = contact;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting contact: $e')),
        );
      }
    }
  }

  Future<void> _makeCall({Contact? contact, bool useWhatsApp = false}) async {
    final targetContact = contact ?? _currentContact;
    if (targetContact?.phoneNumber == null) return;

    final success = await _contactService.launchCallOptions(
      targetContact?.phoneNumber,
      useWhatsApp: useWhatsApp,
    );

    if (success) {
      await _loadData(); // Refresh data after call
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch call app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _skipContact() async {
    setState(() {
      _currentContact = null;
    });
    await _getRandomContact();
  }

  Future<void> _markFavoriteCalled(Contact contact) async {
    try {
      await _contactService.markFavoriteCallCompleted(contact.id);
      await _loadData(); // Refresh data to update the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${contact.name} as called'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.inversePrimary.withOpacity(0.1),
              Colors.white,
              Colors.green.shade50,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      // App Header with Logo (moved to top)
                      _buildAppHeader(),
                      const SizedBox(height: 24),
                      
                      // Frequency Progress Card
                      _buildFrequencyGoalCard(),
                      const SizedBox(height: 24),
                      
                      // Priority Circle Section
                      if (_dueFavoriteContacts.isNotEmpty) ...[
                        _buildDueFavoritesCard(),
                        const SizedBox(height: 32),
                      ],
                      
                      // Main Action Card
                      _buildMainActionCard(),
                      const SizedBox(height: 32),
                      
                      // Current Contact Card
                      if (_currentContact != null) _buildContactCard(),
                      
                      const SizedBox(height: 32),
                      
                      // Stats Grid (moved to bottom)
                      _buildStatsGrid(),
                      
                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: _buildExpandableFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.phone_in_talk,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to stay connected?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App Logo (smaller)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade200,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if image fails to load
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // App Name (smaller)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DashDial',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              'Stay Connected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                label: 'Active Contacts',
                value: _activeContactCount.toString(),
                color: Colors.blue.shade600,
                bgColor: Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.phone,
                label: 'Total Calls',
                value: _totalCallsCount.toString(),
                color: Colors.green.shade600,
                bgColor: Colors.green.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.local_fire_department,
                label: 'Current Streak',
                value: _currentStreak.toString(),
                color: Colors.orange.shade600,
                bgColor: Colors.orange.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.star,
                label: 'Favorites',
                value: _favoriteContacts.length.toString(),
                color: Colors.amber.shade600,
                bgColor: Colors.amber.shade50,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyGoalCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_frequency.displayName} Goal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Keep up the great work!',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_frequencyProgress.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _frequencyProgress / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_frequencyCurrentCalls / $_frequencyGoal calls',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_frequencyRemainingCalls to go!',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.people,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_activeContactCount',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Active Contacts',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.phone,
                    size: 32,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_totalCallsCount',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Total Calls',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 32,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_currentStreak',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Day Streak',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueFavoritesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.priority_high,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Favorites Due for Call',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Time to reconnect!',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._dueFavoriteContacts.take(3).map((contact) {
            final contactObj = contact as Contact;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.red.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contactObj.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      contactObj.favoriteFrequency?.displayName ?? 'Weekly',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _makeCall(contact: contactObj),
                          icon: Icon(
                            Icons.phone,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                          tooltip: 'Call',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _markFavoriteCalled(contactObj),
                          icon: Icon(
                            Icons.check_circle,
                            color: Colors.blue.shade600,
                            size: 18,
                          ),
                          tooltip: 'Mark Called',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_dueFavoriteContacts.length > 3) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showDueFavoritesDialog(),
              icon: const Icon(Icons.list),
              label: Text('View all ${_dueFavoriteContacts.length} due favorites'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFavoritesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'My Favorites',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._favoriteContacts.take(3).map((contact) {
              final contactObj = contact as Contact;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contactObj.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (contactObj.favoriteFrequency != null)
                      Text(
                        contactObj.favoriteFrequency!.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              );
            }),
            if (_favoriteContacts.length > 3)
              TextButton(
                onPressed: () => _showFavoritesDialog(),
                child: Text('View all ${_favoriteContacts.length} favorites'),
              ),
          ],
        ),
      ),
    );
  }

  void _showDueFavoritesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorites Due for Call'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _dueFavoriteContacts.length,
            itemBuilder: (context, index) {
              final contact = _dueFavoriteContacts[index] as Contact;
              return ListTile(
                leading: const Icon(Icons.star, color: Colors.orange),
                title: Text(contact.name),
                subtitle: Text(contact.favoriteFrequency?.displayName ?? 'Weekly'),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _callFavoriteContact(contact);
                  },
                  child: const Text('Call'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFavoritesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Favorites'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _favoriteContacts.length,
            itemBuilder: (context, index) {
              final contact = _favoriteContacts[index] as Contact;
              return ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(contact.name),
                subtitle: contact.favoriteFrequency != null 
                    ? Text(contact.favoriteFrequency!.displayName)
                    : null,
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _callFavoriteContact(contact);
                  },
                  child: const Text('Call'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _callFavoriteContact(Contact contact) async {
    final success = await _contactService.launchCallOptions(
      contact.phoneNumber,
      useWhatsApp: _useWhatsApp,
    );

    if (success) {
      await _contactService.markFavoriteCallCompleted(contact.id);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Called ${contact.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch call app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMainActionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Ready to connect?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s find someone to call today',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _activeContactCount > 0 ? _getRandomContact : null,
            icon: const Icon(Icons.shuffle),
            label: const Text('Get Random Contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.person,
              size: 48,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              _currentContact!.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            if (_currentContact!.phoneNumber != null) ...[
              const SizedBox(height: 8),
              Text(
                _currentContact!.phoneNumber!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            if (_currentContact!.email != null) ...[
              const SizedBox(height: 4),
              Text(
                _currentContact!.email!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            if (_currentContact!.lastCalled != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last called: ${_formatDate(_currentContact!.lastCalled!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _makeCall(useWhatsApp: false),
                        icon: const Icon(Icons.phone),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _makeCall(useWhatsApp: true),
                        icon: const Icon(Icons.message),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _skipContact,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip Contact'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Contacts option
        if (_isFabExpanded) _buildFabOption(
          icon: Icons.contacts,
          label: 'Contacts',
          color: Theme.of(context).primaryColor,
          onPressed: () {
            _fabAnimationController?.reverse();
            setState(() {
              _isFabExpanded = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ContactsScreen()),
            );
          },
        ),
        
        // Priority Circle option
        if (_isFabExpanded) _buildFabOption(
          icon: Icons.star,
          label: 'Priority Circle',
          color: Colors.orange.shade600,
          onPressed: () {
            _fabAnimationController?.reverse();
            setState(() {
              _isFabExpanded = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesScreen()),
            );
          },
        ),
        
        // Progress option
        if (_isFabExpanded) _buildFabOption(
          icon: Icons.trending_up,
          label: 'Progress',
          color: Colors.green.shade600,
          onPressed: () {
            _fabAnimationController?.reverse();
            setState(() {
              _isFabExpanded = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProgressScreen()),
            );
          },
        ),
        
        // Settings option
        if (_isFabExpanded) _buildFabOption(
          icon: Icons.settings,
          label: 'Settings',
          color: Colors.grey.shade600,
          onPressed: () {
            _fabAnimationController?.reverse();
            setState(() {
              _isFabExpanded = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        
        // Main FAB
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () {
            setState(() {
              _isFabExpanded = !_isFabExpanded;
              if (_isFabExpanded) {
                _fabAnimationController?.forward();
              } else {
                _fabAnimationController?.reverse();
              }
            });
          },
          backgroundColor: Colors.orange.shade600,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _fabAnimationController ?? AlwaysStoppedAnimation(0.0),
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Button
          FloatingActionButton(
            mini: true,
            onPressed: onPressed,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
