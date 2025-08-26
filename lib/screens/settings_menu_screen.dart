import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_screen.dart';

class SettingsMenuScreen extends ConsumerWidget {
  const SettingsMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Settings List
              Expanded(
                child: ListView(
                  children: [
                    _buildSettingsCard(
                      context: context,
                      isDark: isDark,
                      icon: Icons.account_circle_outlined,
                      title: 'Account Settings',
                      subtitle: 'Configure SIP account and connection',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: Text('Account Settings'),
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                              ),
                              body: SettingsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 12),
                    
                    _buildSettingsCard(
                      context: context,
                      isDark: isDark,
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Ringtones and notification settings',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Notification settings coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 12),
                    
                    _buildSettingsCard(
                      context: context,
                      isDark: isDark,
                      icon: Icons.security_outlined,
                      title: 'Privacy & Security',
                      subtitle: 'Permissions and security settings',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Privacy settings coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 12),
                    
                    _buildSettingsCard(
                      context: context,
                      isDark: isDark,
                      icon: Icons.storage_outlined,
                      title: 'Storage & Data',
                      subtitle: 'Call logs and data management',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Storage settings coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: 12),
                    
                    _buildSettingsCard(
                      context: context,
                      isDark: isDark,
                      icon: Icons.info_outlined,
                      title: 'About',
                      subtitle: 'App version and information',
                      onTap: () {
                        _showAboutDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.blue[600],
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About SIP Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SIP Phone Flutter App'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('A modern SIP client built with Flutter'),
            SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text('• Voice calls over SIP'),
            Text('• Contact management'),
            Text('• Call history'),
            Text('• Modern UI design'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}