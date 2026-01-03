import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../services/database_helper.dart';
import '../models/contact.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PageController _pageController = PageController();
  final TextEditingController _goalController = TextEditingController(text: '1');
  
  int _currentStep = 0;
  CallFrequency? _selectedFrequency;
  int _frequencyGoal = 1;
  bool _isLoading = false;
  bool _permissionGranted = false;
  bool _isImportingContacts = false;
  int _importedContactsCount = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  _buildAboutStep(),
                  _buildRhythmStep(),
                  _buildPermissionStep(),
                ],
              ),
            ),
            
            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8.0 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep 
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAboutStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // App icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_in_talk,
              size: 50,
              color: Theme.of(context).primaryColor,
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Welcome to dashDial',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Your gentle reminder to stay connected with the people who matter most.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.blue.shade600, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Smart Contact Selection',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'We help you choose who to call based on your relationships and timing.',
                  style: TextStyle(color: Colors.blue.shade600),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.green.shade600, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Relationship-Focused',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Build meaningful connections with family, friends, and your community.',
                  style: TextStyle(color: Colors.green.shade600),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40), // Extra padding at bottom
        ],
      ),
    );
  }

  Widget _buildRhythmStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'Set Your Call Rhythm',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'How often would you like to connect?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 40),
          
          // Frequency options
          Column(
            children: [
              _buildFrequencyOption(CallFrequency.daily, 'Daily'),
              const SizedBox(height: 16),
              _buildFrequencyOption(CallFrequency.weekly, 'Weekly'),
              const SizedBox(height: 16),
              _buildFrequencyOption(CallFrequency.monthly, 'Monthly'),
              const SizedBox(height: 24),
              
              // Goal setting section
              if (_selectedFrequency != null) ...[
                Text(
                  'Set your goal for ${_selectedFrequency!.name} calls:',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          controller: _goalController,
                          decoration: InputDecoration(
                            labelText: 'Goal per ${_selectedFrequency!.name}',
                            hintText: 'Enter your goal',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _frequencyGoal = int.tryParse(value) ?? 1;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 40), // Extra padding at bottom
        ],
      ),
    );
  }

  Widget _buildFrequencyOption(CallFrequency frequency, String title) {
    final isSelected = _selectedFrequency == frequency;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFrequency = frequency;
          // Reset goal when frequency changes
          _frequencyGoal = 1;
          _goalController.text = '1';
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey.shade50,
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isSelected 
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // Permission icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.contacts,
              size: 40,
              color: Colors.blue.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Contact Access',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'dashDial needs access to your contacts to help you stay connected with people who matter most.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Permission request card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _permissionGranted ? Icons.check_circle : Icons.contact_page,
                      size: 48,
                      color: _permissionGranted ? Colors.green.shade600 : Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _permissionGranted ? 'Permission Granted' : 'Request Permission',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _permissionGranted ? Colors.green.shade700 : Theme.of(context).primaryColor,
                            ),
                          ),
                          Text(
                            _permissionGranted 
                                ? 'You can now access your contacts'
                                : 'Tap below to grant contact access',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_permissionGranted) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isImportingContacts ? null : _requestContactPermission,
                    icon: _isImportingContacts 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.security),
                    label: Text(_isImportingContacts ? 'Importing...' : 'Grant Contact Access'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
                if (_permissionGranted && _importedContactsCount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.import_contacts, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$_importedContactsCount contacts imported',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Safety message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite,
                  size: 32,
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: 12),
                Text(
                  'dashDial will never shame you for missing a call.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40), // Extra padding at bottom
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Back'),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),
          
          Expanded(
            child: ElevatedButton(
              onPressed: _canProceed() ? _proceed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(_currentStep == 2 ? 'Get Started' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return true; // About step doesn't require selection
      case 1:
        return _selectedFrequency != null && _frequencyGoal > 0;
      case 2:
        return true; // Allow proceeding, permission will be requested in _proceed()
      default:
        return false;
    }
  }

  void _proceed() async {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentStep == 2) {
      // Check if permission is granted, if not, request it
      if (!_permissionGranted) {
        await _requestContactPermission(completeOnboardingAfter: true);
      } else {
        // Permission already granted, complete onboarding
        await _completeOnboarding();
      }
    }
  }

  Future<void> _requestContactPermission({bool completeOnboardingAfter = false}) async {
    final status = await Permission.contacts.request();
    
    if (mounted) {
      setState(() {
        _permissionGranted = status.isGranted;
      });
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'dashDial needs contact access to help you stay connected. Please enable it in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Settings'),
              ),
            ],
          ),
        );
      }
    } else if (status.isGranted) {
      // Automatically import contacts after permission is granted
      await _importContacts();
      
      // If this was triggered by continue button, complete onboarding
      if (completeOnboardingAfter) {
        await _completeOnboarding();
      }
    } else if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact permission is required to use dashDial')),
        );
      }
    }
  }

  Future<void> _importContacts() async {
    if (!await fc.FlutterContacts.requestPermission(readonly: true)) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isImportingContacts = true;
    });

    try {
      // Get all contacts from phone
      final contacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      int importedCount = 0;
      
      for (final fcContact in contacts) {
        if (fcContact.phones.isNotEmpty) {
          // Create app contact from flutter contact
          final appContact = Contact(
            id: fcContact.id,
            name: fcContact.displayName ?? 'Unknown',
            phoneNumber: fcContact.phones.first.number,
            email: fcContact.emails.isNotEmpty ? fcContact.emails.first.address : null,
            favoriteFrequency: null,
            lastCalled: null,
            callCount: 0,
            isFavorite: false,
          );

          // Save to database
          await _dbHelper.createContact(appContact);
          importedCount++;
        }
      }

      if (mounted) {
        setState(() {
          _isImportingContacts = false;
          _importedContactsCount = importedCount;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $importedCount contacts'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImportingContacts = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Save frequency and goal
      if (_selectedFrequency != null && _frequencyGoal > 0) {
        await _dbHelper.updateSetting('call_frequency', _selectedFrequency!.name);
        
        // Save the user-defined goal
        final goalKey = '${_selectedFrequency!.name}_goal';
        await _dbHelper.updateSetting(goalKey, _frequencyGoal.toString());
        
        // Wait a bit to ensure database transaction is committed
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify the settings were saved
        final savedFrequency = await _dbHelper.getSetting('call_frequency');
        final savedGoal = await _dbHelper.getSetting(goalKey);
      } else {
        // Set defaults if not properly set
        if (_selectedFrequency == null) {
          await _dbHelper.updateSetting('call_frequency', 'weekly');
        }
        if (_frequencyGoal <= 0) {
          await _dbHelper.updateSetting('weekly_goal', '1');
        }
      }
      
      // Mark onboarding as complete
      await _dbHelper.updateSetting('onboarding_complete', 'true');
      
      // Wait a bit more to ensure all settings are committed
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing onboarding: $e')),
        );
      }
    }
  }
}
