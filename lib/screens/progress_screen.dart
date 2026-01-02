import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/contact_service.dart';
import '../services/database_helper.dart';
import '../models/contact.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ContactService _contactService = ContactService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  bool _isLoading = false;
  Map<String, dynamic> _yearlyProgress = {};
  int _currentStreak = 0;
  List<Map<String, dynamic>> _achievements = [];
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final yearlyProgress = await _contactService.getYearlyProgress(_selectedYear);
      final currentStreak = await _contactService.getCurrentStreak();
      final achievements = await _contactService.getAchievements();
      
      // Calculate yearly goal from frequency for current year
      int calculatedYearlyGoal;
      if (_selectedYear == DateTime.now().year) {
        calculatedYearlyGoal = await _contactService.calculateYearlyGoalFromFrequency();
      } else {
        // For past years, use the stored target or default
        calculatedYearlyGoal = yearlyProgress['target_calls'] as int? ?? 260;
      }

      setState(() {
        _yearlyProgress = yearlyProgress;
        _currentStreak = currentStreak;
        _achievements = achievements;
        
        // Update the target to use calculated goal for current year
        if (_selectedYear == DateTime.now().year) {
          _yearlyProgress['target_calls'] = calculatedYearlyGoal;
          _yearlyProgress['remaining_calls'] = calculatedYearlyGoal - (yearlyProgress['actual_calls'] as int? ?? 0);
          _yearlyProgress['progress_percentage'] = calculatedYearlyGoal > 0 
              ? ((yearlyProgress['actual_calls'] as int? ?? 0) / calculatedYearlyGoal * 100)
              : 0.0;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading progress data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & Achievements'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildYearSelector(),
                      const SizedBox(height: 16),
                      _buildYearlyGoalCard(),
                      const SizedBox(height: 16),
                      _buildStreakCard(),
                      const SizedBox(height: 24),
                      _buildAchievementsSection(),
                      const SizedBox(height: 24),
                      _buildDetailedStats(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _selectedYear > 2026 
                  ? () {
                      setState(() {
                        _selectedYear--;
                      });
                      _loadData();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '$_selectedYear',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              onPressed: _selectedYear < DateTime.now().year 
                  ? () {
                      setState(() {
                        _selectedYear++;
                      });
                      _loadData();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyGoalCard() {
    final progress = _yearlyProgress['progress_percentage'] as double? ?? 0.0;
    final actual = _yearlyProgress['actual_calls'] as int? ?? 0;
    final target = _yearlyProgress['target_calls'] as int? ?? 260;
    final remaining = _yearlyProgress['remaining_calls'] as int? ?? target;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_selectedYear Goal',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${progress.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$actual / $target calls',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '$remaining to go!',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.local_fire_department,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Current Streak',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '$_currentStreak days',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_currentStreak > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Keep it going! 🔥',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Start your streak today!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final unlockedAchievements = _achievements.where((a) => a['is_unlocked'] == 1).toList();
    final lockedAchievements = _achievements.where((a) => a['is_unlocked'] == 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (unlockedAchievements.isNotEmpty) ...[
          Text(
            'Unlocked (${unlockedAchievements.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...unlockedAchievements.map((achievement) => _buildAchievementTile(achievement, true)),
          const SizedBox(height: 16),
        ],
        if (lockedAchievements.isNotEmpty) ...[
          Text(
            'Locked (${lockedAchievements.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...lockedAchievements.map((achievement) => _buildAchievementTile(achievement, false)),
        ],
      ],
    );
  }

  Widget _buildAchievementTile(Map<String, dynamic> achievement, bool isUnlocked) {
    return Card(
      color: isUnlocked 
          ? Colors.green.withOpacity(0.1)
          : Colors.grey.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUnlocked ? Colors.green : Colors.grey,
          child: Icon(
            isUnlocked ? Icons.emoji_events : Icons.lock,
            color: Colors.white,
          ),
        ),
        title: Text(
          achievement['title'] as String,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isUnlocked ? Colors.green : Colors.grey,
          ),
        ),
        subtitle: Text(achievement['description'] as String),
        trailing: isUnlocked && achievement['unlocked_at'] != null
            ? Text(
                _formatDate(DateTime.parse(achievement['unlocked_at'] as String)),
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Contact>>(
              future: _contactService.getMostCalled(5),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No calls made yet');
                } else {
                  final contacts = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most Called Contacts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...contacts.map((contact) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(contact.name)),
                            Text(
                              '${contact.callCount} calls',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
