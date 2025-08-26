import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/contacts_service.dart';

final contactsServiceProvider = Provider<AppContactsService>((ref) {
  return AppContactsService();
});

final contactsProvider = FutureProvider<List<ContactModel>>((ref) async {
  final service = ref.watch(contactsServiceProvider);
  return service.loadContacts();
});

final contactSearchProvider = StateProvider<String>((ref) => '');

final filteredContactsProvider = Provider<List<ContactModel>>((ref) {
  final contacts = ref.watch(contactsProvider);
  final searchQuery = ref.watch(contactSearchProvider);
  
  return contacts.when(
    data: (contactsList) {
      if (searchQuery.isEmpty) return contactsList;
      final service = ref.watch(contactsServiceProvider);
      return service.searchContacts(searchQuery);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});