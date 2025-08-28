import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/connection.p.dart' show serverConnectionProvider;
import '../providers/sip_providers.dart';
import '../data/services/contacts_service.dart';
import '../data/models/contact_model.dart';
import '../utils/phone_utils.dart';
import '../utils/transitions.dart';
import 'call_history_screen.dart';
import 'settings_menu_screen.dart';

final phoneNumberProvider = StateProvider<String>((ref) => '');
final contactsProvider = FutureProvider<List<ContactModel>>((ref) async {
  final contactsService = ContactsService();
  return await contactsService.getStoredContacts();
});
final contactSearchProvider = StateProvider<String>((ref) => '');

class DialerScreen extends ConsumerStatefulWidget {
  const DialerScreen({super.key});

  @override
  ConsumerState<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends ConsumerState<DialerScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(duration: Duration(seconds: 1), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    final currentNumber = ref.read(phoneNumberProvider);
    final newNumber = currentNumber + digit;
    ref.read(phoneNumberProvider.notifier).state = newNumber;
    _phoneController.text = newNumber;
  }

  void _removeDigit() {
    final currentNumber = ref.read(phoneNumberProvider);
    if (currentNumber.isNotEmpty) {
      final newNumber = currentNumber.substring(0, currentNumber.length - 1);
      ref.read(phoneNumberProvider.notifier).state = newNumber;
      _phoneController.text = newNumber;
    }
  }

  void _clearNumber() {
    ref.read(phoneNumberProvider.notifier).state = '';
    _phoneController.text = '';
  }

  Future<void> _makeCall() async {
    final phoneNumber = ref.read(phoneNumberProvider);
    final sipService = ref.read(sipServiceProvider);
    final connected_ = await ref.read(serverConnectionProvider.future);

    if (phoneNumber.isEmpty) return;

    // Add haptic feedback
    HapticFeedback.heavyImpact();

    // Check microphone permission
    if (await Permission.microphone.isDenied) {
      final status = await Permission.microphone.request();
      if (status.isDenied) {
        if (mounted) {
          _showErrorSnackBar('Microphone permission is required for calls');
        }
        return;
      }
    }

    // Check connection status
    if (!connected_) {
      _showErrorSnackBar('Not connected to SIP server. Please check settings.');
      return;
    }

    // Sanitize and validate phone number
    final sanitizedNumber = PhoneUtils.sanitizePhoneNumber(phoneNumber);
    if (!PhoneUtils.isValidPhoneNumber(sanitizedNumber)) {
      _showErrorSnackBar('Please enter a valid phone number');
      return;
    }

    debugPrint('📞 Calling: $phoneNumber -> $sanitizedNumber');

    final success = await sipService.makeCall(sanitizedNumber, ref);
    if (success) {
      _clearNumber();
    } else {
      _showErrorSnackBar('Failed to make call. Please check your connection.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDialpadButton(String number, String letters, double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Font sizes based on screen width ratios
    final fontSize = screenWidth * 0.07; // 7% of screen width
    final letterSize = screenWidth * 0.025; // 2.5% of screen width

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(size / 2),
      color: isDark ? Colors.grey[850] : Colors.grey[50],
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: () {
          HapticFeedback.lightImpact();
          _addDigit(number);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (letters.isNotEmpty) ...[
                SizedBox(height: size * 0.02), // Height based on button size
                Text(
                  letters,
                  style: TextStyle(
                    fontSize: letterSize,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    Color? backgroundColor,
    Color? iconColor,
    double size = 60,
    double iconSize = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: onPressed != null ? 2 : 0.5,
      borderRadius: BorderRadius.circular(size / 2),
      color: onPressed != null ? backgroundColor : (isDark ? Colors.grey[800] : Colors.grey[300]),
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onPressed,
        onLongPress: onLongPress,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(
              color: onPressed != null ? Colors.transparent : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: onPressed != null ? iconColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('SIP Phone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24)),
        centerTitle: true,
        actions: [
          // Server Connection Status Icon
          Consumer(
            builder: (context, ref, child) {
              final connectionStatus = ref.watch(connectionStatusProvider);
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: connectionStatus ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: connectionStatus ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  connectionStatus ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: connectionStatus ? Colors.green[700] : Colors.red[700],
                  size: 20,
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () {
              AppTransitions.navigateWithTransition(context, SettingsMenuScreen(), type: TransitionType.slideFromRight);
            },
            tooltip: 'Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3.0,
          indicatorPadding: EdgeInsets.symmetric(horizontal: 20.0),
          tabs: [
            Tab(icon: Icon(Icons.dialpad), text: 'Dial'),
            Tab(icon: Icon(Icons.history), text: 'Recent'),
            Tab(icon: Icon(Icons.contacts), text: 'Contacts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Dialer Tab
          _buildDialerTab(theme, isDark),

          // Recent Calls Tab
          CallHistoryScreen(),

          // Contacts Tab
          _buildContactsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildDialerTab(ThemeData theme, bool isDark) {
    final phoneNumber = ref.watch(phoneNumberProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            // Phone Number Display
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              margin: EdgeInsets.only(top: 20, bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          phoneNumber.isEmpty ? 'Enter number' : phoneNumber,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: phoneNumber.isEmpty
                                ? (isDark ? Colors.grey[500] : Colors.grey[600])
                                : (isDark ? Colors.white : Colors.black87),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (phoneNumber.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            'Formatted: ${PhoneUtils.formatPhoneNumber(phoneNumber)}',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (phoneNumber.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _clearNumber();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Dialpad - Fill available space properly
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final screenHeight = MediaQuery.of(context).size.height;

                  // Calculate available space more carefully
                  final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top + 48; // Tab bar height
                  final actionButtonsHeight = screenHeight * 0.12;
                  final phoneFieldHeight = phoneNumber.isNotEmpty ? 80.0 : 60.0; // Dynamic height
                  final availableHeight =
                      screenHeight - appBarHeight - actionButtonsHeight - phoneFieldHeight - 60; // Extra padding

                  // Use screen ratios but ensure minimum space
                  final dialpadWidth = screenWidth * 0.92;
                  final dialpadHeight = availableHeight.clamp(300.0, availableHeight);

                  return Center(
                    child: SizedBox(width: dialpadWidth, height: dialpadHeight, child: _buildModernDialpad()),
                  );
                },
              ),
            ),

            // Action Buttons - Fixed at bottom
            Container(
              height: MediaQuery.of(context).size.height * 0.12, // 12% of screen height
              padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.015),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Backspace
                  _buildActionButton(
                    icon: Icons.backspace_outlined,
                    onPressed: phoneNumber.isNotEmpty ? _removeDigit : null,
                    onLongPress: phoneNumber.isNotEmpty ? _clearNumber : null,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    iconColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: MediaQuery.of(context).size.width * 0.13, // 13% of screen width
                  ),

                  // Call Button
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: phoneNumber.isNotEmpty ? _pulseAnimation.value : 1.0,
                        child: _buildActionButton(
                          icon: Icons.phone,
                          onPressed: phoneNumber.isNotEmpty ? _makeCall : null,
                          backgroundColor: phoneNumber.isNotEmpty ? Colors.green : Colors.grey[300],
                          iconColor: Colors.white,
                          size: MediaQuery.of(context).size.width * 0.16, // 16% of screen width
                          iconSize: MediaQuery.of(context).size.width * 0.065, // 6.5% of screen width
                        ),
                      );
                    },
                  ),

                  // Add Contact
                  _buildActionButton(
                    icon: Icons.person_add_outlined,
                    onPressed: phoneNumber.isNotEmpty
                        ? () {
                            // TODO: Add contact functionality
                          }
                        : null,
                    backgroundColor: isDark ? Colors.blue[900] : Colors.blue[50],
                    iconColor: isDark ? Colors.blue[300] : Colors.blue[600],
                    size: MediaQuery.of(context).size.width * 0.13, // 13% of screen width
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDialpad() {
    final dialpadNumbers = [
      ['1', ''],
      ['2', 'ABC'],
      ['3', 'DEF'],
      ['4', 'GHI'],
      ['5', 'JKL'],
      ['6', 'MNO'],
      ['7', 'PQRS'],
      ['8', 'TUV'],
      ['9', 'WXYZ'],
      ['*', ''],
      ['0', '+'],
      ['#', ''],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;

        // Calculate button size based on available space, not just screen width
        final maxButtonSize = constraints.maxHeight / 5; // 4 rows + spacing
        final screenBasedSize = screenWidth * 0.2; // 20% of screen width
        final buttonSize = [
          maxButtonSize,
          screenBasedSize,
          75.0,
        ].reduce((a, b) => a < b ? a : b).toDouble(); // Take minimum

        final horizontalSpacing = (constraints.maxWidth - (buttonSize * 3)) / 4;
        final verticalSpacing = (constraints.maxHeight - (buttonSize * 4)) / 6;

        // Ensure spacing is reasonable
        final safeHorizontalSpacing = horizontalSpacing.clamp(8.0, 24.0);
        final safeVerticalSpacing = verticalSpacing.clamp(4.0, 20.0);

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: safeHorizontalSpacing * 0.6, vertical: safeVerticalSpacing * 0.4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: safeHorizontalSpacing * 0.8,
              mainAxisSpacing: safeVerticalSpacing * 0.6,
            ),
            itemCount: dialpadNumbers.length,
            itemBuilder: (context, index) {
              final number = dialpadNumbers[index][0];
              final letters = dialpadNumbers[index][1];

              return _buildDialpadButton(number, letters, buttonSize);
            },
          ),
        );
      },
    );
  }

  Widget _buildContactsTab(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 0.5),
            ),
            child: Consumer(
              builder: (context, ref, child) {
                return TextField(
                  onChanged: (value) {
                    ref.read(contactSearchProvider.notifier).state = value;
                  },
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                );
              },
            ),
          ),

          // Contacts list
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final contactsAsync = ref.watch(contactsProvider);
                final searchQuery = ref.watch(contactSearchProvider);

                return contactsAsync.when(
                  data: (contacts) {
                    final contactsService = ContactsService();
                    final filteredContacts = searchQuery.isEmpty
                        ? contacts
                        : contactsService.searchContacts(searchQuery);

                    if (filteredContacts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.contacts, size: 80, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty ? 'No contacts' : 'No matching contacts',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Text(
                              searchQuery.isEmpty ? 'Sample contacts are shown' : 'Try a different search term',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        return _buildContactItem(contact, isDark);
                      },
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('Error loading contacts', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                        SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(ContactModel contact, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 0.5),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[600],
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          contact.name,
          style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
        ),
        subtitle: Text(contact.formattedPhone, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.phone, color: Colors.green[600], size: 22),
              onPressed: () {
                ref.read(phoneNumberProvider.notifier).state = contact.phoneNumber;
                _phoneController.text = contact.phoneNumber;
                _tabController.animateTo(0); // Switch to dialer tab
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Number added: ${contact.formattedPhone}'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
