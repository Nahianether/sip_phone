class PhoneUtils {
  // Remove country code prefixes that our server can't handle
  static String sanitizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters first
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove common country codes that cause issues
    if (cleanNumber.startsWith('88') && cleanNumber.length > 10) {
      cleanNumber = cleanNumber.substring(2);
    }
    if (cleanNumber.startsWith('880') && cleanNumber.length > 10) {
      cleanNumber = cleanNumber.substring(3);
    }
    if (cleanNumber.startsWith('8880') && cleanNumber.length > 10) {
      cleanNumber = cleanNumber.substring(4);
    }
    
    return cleanNumber;
  }
  
  // Format phone number for display
  static String formatPhoneNumber(String phoneNumber) {
    String cleanNumber = sanitizePhoneNumber(phoneNumber);
    
    if (cleanNumber.length == 11) {
      // Format as: 01XXX XXX XXX
      return '${cleanNumber.substring(0, 5)} ${cleanNumber.substring(5, 8)} ${cleanNumber.substring(8)}';
    } else if (cleanNumber.length == 10) {
      // Format as: 1XXX XXX XXX
      return '${cleanNumber.substring(0, 4)} ${cleanNumber.substring(4, 7)} ${cleanNumber.substring(7)}';
    }
    
    return cleanNumber;
  }
  
  // Check if phone number is valid
  static bool isValidPhoneNumber(String phoneNumber) {
    String cleanNumber = sanitizePhoneNumber(phoneNumber);
    return cleanNumber.length >= 10 && cleanNumber.length <= 11;
  }
  
  // Extract display name from full contact name
  static String getDisplayName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Unknown';
    
    // Split by space and take first name and last initial
    List<String> parts = fullName.split(' ');
    if (parts.length == 1) return parts[0];
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    
    return fullName;
  }
}