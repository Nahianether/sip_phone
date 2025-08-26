import 'package:flutter/foundation.dart';
import '../utils/phone_utils.dart';

class ContactModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String? avatar;

  ContactModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.avatar,
  });

  String get formattedPhone => PhoneUtils.formatPhoneNumber(phoneNumber);
  String get sanitizedPhone => PhoneUtils.sanitizePhoneNumber(phoneNumber);
}

class AppContactsService {
  static final AppContactsService _instance = AppContactsService._internal();
  factory AppContactsService() => _instance;
  AppContactsService._internal();

  List<ContactModel> _contacts = [];
  List<ContactModel> get contacts => List.unmodifiable(_contacts);

  Future<List<ContactModel>> loadContacts() async {
    try {
      // For now, return sample contacts since contact access requires platform-specific implementation
      _contacts = [
        ContactModel(
          id: '1',
          name: 'John Doe',
          phoneNumber: '1234567890',
        ),
        ContactModel(
          id: '2', 
          name: 'Jane Smith',
          phoneNumber: '9876543210',
        ),
        ContactModel(
          id: '3',
          name: 'Bob Johnson', 
          phoneNumber: '5555551234',
        ),
      ];
      
      // Sort contacts alphabetically
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      
      debugPrint('Loaded ${_contacts.length} sample contacts');
      return _contacts;
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      return [];
    }
  }

  List<ContactModel> searchContacts(String query) {
    if (query.isEmpty) return _contacts;
    
    final lowercaseQuery = query.toLowerCase();
    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(lowercaseQuery) ||
             contact.phoneNumber.contains(query) ||
             contact.formattedPhone.contains(query);
    }).toList();
  }

  ContactModel? findContactByNumber(String phoneNumber) {
    final sanitized = PhoneUtils.sanitizePhoneNumber(phoneNumber);
    try {
      return _contacts.firstWhere(
        (contact) => contact.sanitizedPhone == sanitized,
      );
    } catch (e) {
      return null;
    }
  }

  // Get contact name by phone number
  String getContactName(String phoneNumber) {
    final contact = findContactByNumber(phoneNumber);
    return contact?.name ?? PhoneUtils.formatPhoneNumber(phoneNumber);
  }
}