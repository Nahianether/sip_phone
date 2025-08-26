import '../../utils/phone_utils.dart';

class ContactModel {
  final String id;
  final String? displayName;
  final String phoneNumber;
  final String initials;

  ContactModel({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.initials,
  });

  // Getter for name compatibility
  String get name => displayName ?? 'Unknown';

  // Getter for formatted phone number
  String get formattedPhone => PhoneUtils.formatPhoneNumber(phoneNumber);

  @override
  String toString() {
    return 'ContactModel(id: $id, displayName: $displayName, phoneNumber: $phoneNumber, initials: $initials)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactModel &&
        other.id == id &&
        other.displayName == displayName &&
        other.phoneNumber == phoneNumber &&
        other.initials == initials;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        displayName.hashCode ^
        phoneNumber.hashCode ^
        initials.hashCode;
  }
}