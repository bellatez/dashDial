import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactService _contactService = ContactService();
  List<Contact> _contacts = [];
  bool _isLoading = false;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = _showActiveOnly 
          ? await _contactService.getActiveContacts()
          : await _contactService.getLocalContacts();
      
      setState(() {
        _contacts = contacts;
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

  Future<void> _importContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final importedContacts = await _contactService.importDeviceContacts();
      await _loadContacts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${importedContacts.length} contacts')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing contacts: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleContactActive(Contact contact) async {
    await _contactService.toggleContactActive(contact.id, !contact.isActive);
    await _loadContacts();
  }

  Future<void> _deleteContact(Contact contact) async {
    final confirmed = await _showDeleteConfirmation(contact);
    if (confirmed == true) {
      await _contactService.deleteContact(contact.id);
      await _loadContacts();
    }
  }

  Future<void> _toggleFavorite(Contact contact) async {
    await _contactService.toggleFavorite(contact.id, !contact.isFavorite);
    await _loadContacts();
  }

  Future<void> _showFrequencyDialog(Contact contact) async {
    CallFrequency? selectedFrequency = contact.favoriteFrequency;
    
    final result = await showDialog<CallFrequency>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Frequency for ${contact.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CallFrequency.values.map((frequency) => RadioListTile<CallFrequency>(
            title: Text(frequency.displayName),
            subtitle: Text('Every ${frequency.days} day${frequency.days == 1 ? '' : 's'}'),
            value: frequency,
            groupValue: selectedFrequency,
            onChanged: (value) {
              selectedFrequency = value;
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(selectedFrequency),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result != contact.favoriteFrequency) {
      await _contactService.updateFavoriteFrequency(contact.id, result);
      await _loadContacts();
    }
  }

  Future<bool?> _showDeleteConfirmation(Contact contact) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _importContacts,
            icon: const Icon(Icons.import_contacts),
            tooltip: 'Import from device',
          ),
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _showActiveOnly = value;
              });
              _loadContacts();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: true,
                child: Text('Active only'),
              ),
              const PopupMenuItem(
                value: false,
                child: Text('All contacts'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return _buildContactTile(contact);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Import contacts from your device to get started',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _importContacts,
            icon: const Icon(Icons.import_contacts),
            label: const Text('Import Contacts'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    return Slidable(
      key: Key(contact.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _toggleFavorite(contact),
            backgroundColor: contact.isFavorite ? Colors.grey : Colors.amber,
            foregroundColor: Colors.white,
            icon: contact.isFavorite ? Icons.star_border : Icons.star,
            label: contact.isFavorite ? 'Unfavorite' : 'Favorite',
          ),
          SlidableAction(
            onPressed: (_) => _toggleContactActive(contact),
            backgroundColor: contact.isActive ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
            icon: contact.isActive ? Icons.person_off : Icons.person,
            label: contact.isActive ? 'Deactivate' : 'Activate',
          ),
          SlidableAction(
            onPressed: (_) => _deleteContact(contact),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: contact.isActive 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
          child: Stack(
            children: [
              Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (contact.isFavorite)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          contact.name,
          style: TextStyle(
            fontWeight: contact.isActive ? FontWeight.normal : FontWeight.w300,
            decoration: contact.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.phoneNumber != null)
              Text(contact.phoneNumber!),
            if (contact.email != null)
              Text(contact.email!),
            if (contact.lastCalled != null)
              Text(
                'Last called: ${_formatDate(contact.lastCalled!)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (contact.isFavorite && contact.favoriteFrequency != null)
              Text(
                'Favorite: ${contact.favoriteFrequency!.displayName}',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${contact.callCount}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'calls',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (contact.isFavorite)
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: () => _showFrequencyDialog(contact),
                tooltip: 'Edit frequency',
              ),
          ],
        ),
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
