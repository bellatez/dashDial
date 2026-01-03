import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../models/contact.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final NotificationService _notificationService = NotificationService();
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      
      // Filter contacts based on search query
      final allFilteredContacts = _allContacts.where((contact) {
        final name = contact.name.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query);
      }).toList();
      
      // Separate favorites and non-favorites
      final favorites = allFilteredContacts.where((c) => c.isFavorite).toList();
      final nonFavorites = allFilteredContacts.where((c) => !c.isFavorite).toList();
      
      // Combine: favorites first, then non-favorites
      _filteredContacts = [...favorites, ...nonFavorites];
    });
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await _dbHelper.readAllContacts();
      
      // Separate favorites and non-favorites
      final favorites = contacts.where((c) => c.isFavorite).toList();
      final nonFavorites = contacts.where((c) => !c.isFavorite).toList();
      
      // Combine: favorites first, then non-favorites
      final sortedContacts = [...favorites, ...nonFavorites];
      
      setState(() {
        _allContacts = contacts;
        _filteredContacts = sortedContacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Contact contact) async {
    try {
      final updatedContact = Contact(
        id: contact.id,
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        email: contact.email,
        favoriteFrequency: contact.favoriteFrequency,
        lastCalled: contact.lastCalled,
        callCount: contact.callCount,
        isActive: contact.isActive,
        isFavorite: !contact.isFavorite,
      );

      await _dbHelper.updateContact(updatedContact);
      
      // If setting as favorite, request notification permission
      if (updatedContact.isFavorite) {
        await _notificationService.requestNotificationPermission();
      }
      
      // Update local state
      setState(() {
        final index = _allContacts.indexWhere((c) => c.id == contact.id);
        if (index != -1) {
          _allContacts[index] = updatedContact;
        }
        
        // Re-filter and sort to maintain favorites-first ordering
        final allFilteredContacts = _allContacts.where((contact) {
          final name = contact.name.toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query);
        }).toList();
        
        // Sort: favorites first, then alphabetically
        allFilteredContacts.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return a.name.compareTo(b.name);
        });
        
        _filteredContacts = allFilteredContacts;
      });
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedContact.isFavorite 
                ? '${contact.name} added to favorites'
                : '${contact.name} removed from favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateFrequency(Contact contact, CallFrequency? frequency) async {
    try {
      final updatedContact = Contact(
        id: contact.id,
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        email: contact.email,
        favoriteFrequency: frequency,
        lastCalled: contact.lastCalled,
        callCount: contact.callCount,
        isActive: contact.isActive,
        isFavorite: contact.isFavorite,
      );

      await _dbHelper.updateContact(updatedContact);
      
      // Update local state
      setState(() {
        final index = _allContacts.indexWhere((c) => c.id == contact.id);
        if (index != -1) {
          _allContacts[index] = updatedContact;
        }
        
        // Re-filter and sort to maintain favorites-first ordering
        final allFilteredContacts = _allContacts.where((contact) {
          final name = contact.name.toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query);
        }).toList();
        
        final favorites = allFilteredContacts.where((c) => c.isFavorite).toList();
        final nonFavorites = allFilteredContacts.where((c) => !c.isFavorite).toList();
        _filteredContacts = [...favorites, ...nonFavorites];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating frequency: $e')),
        );
      }
    }
  }

  void _showFrequencyDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Call Frequency for ${contact.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CallFrequency.values.map((frequency) {
            return RadioListTile<CallFrequency>(
              title: Text(frequency.displayName),
              subtitle: Text('Every ${frequency.days} day${frequency.days == 1 ? '' : 's'}'),
              value: frequency,
              groupValue: contact.favoriteFrequency,
              onChanged: (value) {
                if (value != null) {
                  Navigator.of(context).pop();
                  _updateFrequency(contact, value);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateFrequency(contact, null);
            },
            child: const Text('Remove Frequency'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority Circle'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          
          // Contact list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty 
                                  ? 'No contacts found'
                                  : 'No contacts available',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return _buildContactTile(contact);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: contact.isFavorite 
              ? Colors.orange.shade100 
              : Colors.grey.shade200,
          child: Icon(
            Icons.person,
            color: contact.isFavorite 
                ? Colors.orange.shade700 
                : Colors.grey.shade600,
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.phoneNumber ?? 'No phone number',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            if (contact.favoriteFrequency != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  contact.favoriteFrequency!.displayName,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Frequency button (only for favorites)
            if (contact.isFavorite) ...[
              IconButton(
                onPressed: () => _showFrequencyDialog(contact),
                icon: Icon(
                  Icons.schedule,
                  color: Theme.of(context).primaryColor,
                ),
                tooltip: 'Set call frequency',
              ),
            ],
            
            // Favorite toggle
            IconButton(
              onPressed: () => _toggleFavorite(contact),
              icon: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite ? Colors.orange : Colors.grey.shade400,
              ),
              tooltip: contact.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
          ],
        ),
      ),
    );
  }
}
