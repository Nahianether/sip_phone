import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_model.dart';
import '../../utils/phone_utils.dart';

class ContactsService {
  static final ContactsService _instance = ContactsService._internal();
  factory ContactsService() => _instance;
  ContactsService._internal();

  List<ContactModel> _cachedContacts = [];
  bool _contactsLoaded = false;

  // Load all contacts from device storage
  Future<List<ContactModel>> getStoredContacts() async {
    if (_contactsLoaded && _cachedContacts.isNotEmpty) {
      return _cachedContacts;
    }
    
    return await loadDeviceContacts();
  }

  // Load contacts from device
  Future<List<ContactModel>> loadDeviceContacts() async {
    try {
      // Request contacts permission
      final permissionStatus = await Permission.contacts.request();
      
      if (!permissionStatus.isGranted) {
        debugPrint('Contacts permission denied');
        // Return sample contacts if permission is denied
        return _getSampleContacts();
      }

      debugPrint('Loading device contacts...');
      
      // Get contacts from device
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
        withPhoto: false,
      );

      List<ContactModel> contactModels = [];
      
      for (Contact contact in contacts) {
        // Skip contacts without phone numbers
        if (contact.phones.isEmpty) {
          continue;
        }
        
        for (Phone phone in contact.phones) {
          if (phone.number.isNotEmpty) {
            final contactModel = ContactModel(
              id: contact.id,
              displayName: contact.displayName.isNotEmpty ? contact.displayName : 'Unknown',
              phoneNumber: PhoneUtils.sanitizePhoneNumber(phone.number),
              initials: _getInitials(contact.displayName.isNotEmpty ? contact.displayName : 'Unknown'),
            );
            contactModels.add(contactModel);
          }
        }
      }

      // Sort contacts alphabetically
      contactModels.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
      
      _cachedContacts = contactModels;
      _contactsLoaded = true;
      
      debugPrint('Loaded ${contactModels.length} device contacts');
      return contactModels;
      
    } catch (e) {
      debugPrint('Error loading device contacts: $e');
      // Return sample contacts on error
      return _getSampleContacts();
    }
  }

  // Refresh contacts from device
  Future<List<ContactModel>> refreshContacts() async {
    _contactsLoaded = false;
    _cachedContacts.clear();
    return await loadDeviceContacts();
  }

  // Get sample contacts when device contacts can't be accessed
  List<ContactModel> _getSampleContacts() {
    _cachedContacts = [
      ContactModel(
        id: '1',
        displayName: 'John Doe',
        phoneNumber: '01712345678',
        initials: 'JD',
      ),
      ContactModel(
        id: '2', 
        displayName: 'Jane Smith',
        phoneNumber: '01887654321',
        initials: 'JS',
      ),
      ContactModel(
        id: '3',
        displayName: 'Bob Johnson', 
        phoneNumber: '01955551234',
        initials: 'BJ',
      ),
      ContactModel(
        id: '4',
        displayName: 'Alice Brown', 
        phoneNumber: '01633445566',
        initials: 'AB',
      ),
      ContactModel(
        id: '5',
        displayName: 'Charlie Wilson', 
        phoneNumber: '01777889900',
        initials: 'CW',
      ),
    ];
    
    _contactsLoaded = true;
    debugPrint('Using ${_cachedContacts.length} sample contacts');
    return _cachedContacts;
  }

  // Search contacts
  List<ContactModel> searchContacts(String query) {
    if (query.isEmpty) return _cachedContacts;
    
    final lowercaseQuery = query.toLowerCase();
    return _cachedContacts.where((contact) {
      return ((contact.displayName ?? '').toLowerCase().contains(lowercaseQuery)) ||
             contact.phoneNumber.contains(query);
    }).toList();
  }

  // Find contact by phone number
  ContactModel? findContactByNumber(String phoneNumber) {
    final sanitized = PhoneUtils.sanitizePhoneNumber(phoneNumber);
    try {
      return _cachedContacts.firstWhere(
        (contact) => PhoneUtils.sanitizePhoneNumber(contact.phoneNumber) == sanitized,
      );
    } catch (e) {
      return null;
    }
  }

  // Get contact name by phone number
  String getContactName(String phoneNumber) {
    final contact = findContactByNumber(phoneNumber);
    return contact?.displayName ?? PhoneUtils.formatPhoneNumber(phoneNumber);
  }

  // Generate initials from display name
  String _getInitials(String displayName) {
    if (displayName.isEmpty) return '?';
    
    final nameParts = displayName.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    } else {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
  }

  // Check if contacts permission is granted
  Future<bool> hasContactsPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }
}