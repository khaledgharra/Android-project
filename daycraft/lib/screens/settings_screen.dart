import 'package:flutter/material.dart'; // <-- THIS WAS MISSING
import 'package:daycraft/services/auth_service.dart';
import 'package:daycraft/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = "Student";
  final TextEditingController _nameController = TextEditingController();
  bool _deadlineRemindersEnabled = true;

  @override
  void initState() {
    super.initState();
    final currentUser = AuthService.currentUser;
    if (currentUser != null && currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
      _userName = currentUser.displayName!;
    }
    _nameController.text = _userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(String newName) async {
    final trimmed = newName.trim();
    final updated = trimmed.isEmpty ? "Student" : trimmed;
    setState(() {
      _userName = updated;
      _nameController.text = updated;
    });
    await AuthService.updateDisplayName(updated);
  }

  Widget _sectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(thickness: 1.2, height: 1.0, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Colors.white;
    final cornerRadius = 16.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        elevation: 0,
        backgroundColor: const Color(0xFFFDFBF7),
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(cornerRadius),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: const Icon(Icons.person, color: Colors.deepPurple, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Name',
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              hintText: 'Enter your display name',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.save_rounded),
                                onPressed: () => _saveName(_nameController.text),
                                tooltip: 'Save name',
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Current display name: $_userName',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionDivider(),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(cornerRadius),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Manage when you would like to be reminded about deadlines and events.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Deadline Reminders'),
                  subtitle: const Text('Receive reminders before deadlines.'),
                  value: _deadlineRemindersEnabled,
                  onChanged: (val) {
                    setState(() {
                      _deadlineRemindersEnabled = val;
                    });
                  },
                  secondary: const Icon(Icons.alarm_on_rounded, color: Colors.deepPurple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionDivider(),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(cornerRadius),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.deepPurple),
                  title: const Text('About DayCraft'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: _showAboutDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.deepPurple),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Privacy Policy coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'DayCraft',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 DayCraft Team',
      applicationIcon: SizedBox(
        width: 48,
        height: 48,
        child: _buildAboutIcon(),
      ),
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('DayCraft is a productivity app for students to manage tasks, deadlines, and schedules.'),
        ),
      ],
    );
  }

  Widget _buildAboutIcon() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.apps, color: Colors.deepPurple, size: 28),
    );
  }
}