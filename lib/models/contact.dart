class Contact {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? email;
  final DateTime? lastCalled;
  final int callCount;
  final bool isActive;
  final bool isFavorite;
  final CallFrequency? favoriteFrequency;

  Contact({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.email,
    this.lastCalled,
    this.callCount = 0,
    this.isActive = true,
    this.isFavorite = false,
    this.favoriteFrequency,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'last_called': lastCalled?.toIso8601String(),
      'call_count': callCount,
      'is_active': isActive ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'favorite_frequency': favoriteFrequency?.name,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phoneNumber: map['phone_number'],
      email: map['email'],
      lastCalled: map['last_called'] != null 
          ? DateTime.parse(map['last_called']) 
          : null,
      callCount: map['call_count'] ?? 0,
      isActive: (map['is_active'] ?? 1) == 1,
      isFavorite: (map['is_favorite'] ?? 0) == 1,
      favoriteFrequency: map['favorite_frequency'] != null
          ? CallFrequency.values.firstWhere(
              (f) => f.name == map['favorite_frequency'],
              orElse: () => CallFrequency.weekly,
            )
          : null,
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    DateTime? lastCalled,
    int? callCount,
    bool? isActive,
    bool? isFavorite,
    CallFrequency? favoriteFrequency,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      lastCalled: lastCalled ?? this.lastCalled,
      callCount: callCount ?? this.callCount,
      isActive: isActive ?? this.isActive,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteFrequency: favoriteFrequency ?? this.favoriteFrequency,
    );
  }
}

enum CallFrequency {
  daily,
  weekly,
  monthly,
}

extension CallFrequencyExtension on CallFrequency {
  String get displayName {
    switch (this) {
      case CallFrequency.daily:
        return 'Daily';
      case CallFrequency.weekly:
        return 'Weekly';
      case CallFrequency.monthly:
        return 'Monthly';
    }
  }

  int get days {
    switch (this) {
      case CallFrequency.daily:
        return 1;
      case CallFrequency.weekly:
        return 7;
      case CallFrequency.monthly:
        return 30;
    }
  }
}
