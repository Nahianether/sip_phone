import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
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
      // Check if contacts permission is granted
      final permissionStatus = await Permission.contacts.status;
      debugPrint('🔍 Contacts permission status: $permissionStatus');
      
      if (!await Permission.contacts.isGranted) {
        debugPrint('❌ Contacts permission not granted');
        return [];
      }

      debugPrint('📱 Loading device contacts...');
      
      // Get all contacts with phone numbers
      final List<Contact> deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false, // We can add photos later if needed
      );
      
      debugPrint('📞 Found ${deviceContacts.length} device contacts');
      
      // Convert to our ContactModel and filter out contacts without phone numbers
      _contacts = deviceContacts
          .where((contact) => contact.phones.isNotEmpty && contact.displayName.isNotEmpty)
          .expand((contact) {
            // Create a ContactModel for each phone number
            return contact.phones.map((phone) => ContactModel(
              id: '${contact.id}_${phone.number.hashCode}',
              name: contact.displayName,
              phoneNumber: phone.number,
            ));
          })
          .toList();
      
      // Remove duplicates based on phone number
      final Map<String, ContactModel> uniqueContacts = {};
      for (var contact in _contacts) {
        final sanitized = contact.sanitizedPhone;
        if (sanitized.isNotEmpty && !uniqueContacts.containsKey(sanitized)) {
          uniqueContacts[sanitized] = contact;
        }
      }
      
      _contacts = uniqueContacts.values.toList();
      
      // Sort contacts alphabetically
      _contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      
      debugPrint('✅ Successfully loaded ${_contacts.length} real device contacts');
      
      // Debug: Print first few contacts
      if (_contacts.isNotEmpty) {
        debugPrint('📋 First contacts:');
        for (int i = 0; i < (_contacts.length > 3 ? 3 : _contacts.length); i++) {
          final contact = _contacts[i];
          debugPrint('  ${i + 1}. ${contact.name} - ${contact.phoneNumber}');
        }
      }
      
      return _contacts;
    } catch (e) {
      debugPrint('❌ Error loading device contacts: $e');
      // Return empty list instead of dummy data when there's an error
      _contacts = [];
      throw Exception('Failed to load contacts: $e');
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

  // Refresh contacts - useful for manual refresh
  Future<List<ContactModel>> refreshContacts() async {
    debugPrint('🔄 Refreshing contacts...');
    _contacts.clear();
    return await loadContacts();
  }

  // Check if we have loaded contacts
  bool get hasLoadedContacts => _contacts.isNotEmpty;
}