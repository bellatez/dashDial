import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  CallFrequency _frequency = CallFrequency.weekly;
  bool _isLoading = false;
  final Map<CallFrequency, TextEditingController> _goalControllers = {};
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSettings();
  }
  
  @override
  void dispose() {
    for (final controller in _goalControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _initializeControllers() {
    for (final frequency in CallFrequency.values) {
      _goalControllers[frequency] = TextEditingController();
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final frequencyString = await _dbHelper.getSetting('call_frequency');
      final frequency = CallFrequency.values.firstWhere(
        (f) => f.name == frequencyString,
        orElse: () => CallFrequency.weekly,
      );

      // Load goals for each frequency
      for (final freq in CallFrequency.values) {
        final goalKey = '${freq.name}_goal';
        final goalValue = await _dbHelper.getSetting(goalKey);
        final goalNumber = int.tryParse(goalValue);
        if (goalNumber != null && goalNumber > 0) {
          _goalControllers[freq]?.text = goalValue;
        }
      }

      setState(() {
        _frequency = frequency;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFrequency(CallFrequency frequency) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _dbHelper.updateSetting('call_frequency', frequency.name);
      setState(() {
        _frequency = frequency;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Frequency updated to ${frequency.displayName}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating frequency: $e')),
        );
      }
    }
  }

  Future<void> _updateFrequencyGoal(CallFrequency frequency, String goal) async {
    if (goal.isEmpty) return;
    
    final goalValue = int.tryParse(goal);
    if (goalValue == null || goalValue <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid positive number'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final goalKey = '${frequency.name}_goal';
      await _dbHelper.updateSetting(goalKey, goal);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Goal updated: $goal ${frequency.displayName.toLowerCase()} calls')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating goal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFrequencySection(),
                  const SizedBox(height: 24),
                  _buildAboutSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildFrequencySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Call Frequency & Goals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Set your preferred call frequency and goals for each period',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...CallFrequency.values.map((frequency) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<CallFrequency>(
                    title: Text(frequency.displayName),
                    subtitle: Text('Every ${frequency.days} day${frequency.days == 1 ? '' : 's'}'),
                    value: frequency,
                    groupValue: _frequency,
                    onChanged: (value) {
                      if (value != null) {
                        _updateFrequency(value);
                      }
                    },
                  ),
                  if (_frequency == frequency) ...[
                    Container(
                      margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set your ${frequency.displayName.toLowerCase()} goal',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _goalControllers[frequency],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Number of calls',
                                      hintText: 'Enter your goal',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _updateFrequencyGoal(
                                      frequency, 
                                      _goalControllers[frequency]?.text ?? ''
                                    );
                                  },
                                  icon: const Icon(Icons.save, size: 18),
                                  label: const Text('Save'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Dash Dial',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('Version'),
              subtitle: Text('1.0.0'),
            ),
            const ListTile(
              leading: Icon(Icons.description),
              title: Text('Purpose'),
              subtitle: Text('Helps you maintain relationships by randomly selecting contacts to call'),
            ),
            const ListTile(
              leading: Icon(Icons.storage),
              title: Text('Data Storage'),
              subtitle: Text('All data is stored locally on your device'),
            ),
            const ListTile(
              leading: Icon(Icons.phone),
              title: Text('How it works'),
              subtitle: Text('1. Import contacts from your device\n2. Set your preferred call frequency\n3. Get random contact suggestions\n4. Track your call history'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pro tip: Consistency is key to building strong relationships. Start with a frequency you can maintain!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
