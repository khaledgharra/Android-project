import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:daycraft/services/auth_service.dart';
import 'package:daycraft/services/theme_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = "Student";
  final TextEditingController _nameController = TextEditingController();

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name updated!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDark;
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Profile ──
          _SectionCard(
            cardBg: cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('User Profile'),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                        style: const TextStyle(color: Colors.deepPurple, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Display Name', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              hintText: 'Enter your name',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.save_rounded, color: Colors.deepPurple),
                                onPressed: () => _saveName(_nameController.text),
                                tooltip: 'Save',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Appearance ──
          _SectionCard(
            cardBg: cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Appearance'),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(isDark ? 'Dark theme enabled' : 'Light theme enabled',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  secondary: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.deepPurple.withOpacity(0.2) : Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? Colors.deepPurple.shade300 : Colors.amber.shade700,
                      size: 20,
                    ),
                  ),
                  value: isDark,
                  activeColor: Colors.deepPurple,
                  onChanged: (_) => themeService.toggle(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Notifications ──
          _SectionCard(
            cardBg: cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Notifications'),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline Reminders', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Get reminded 24h before a deadline',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  secondary: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.alarm_rounded, color: Colors.deepPurple, size: 20),
                  ),
                  value: true,
                  activeColor: Colors.deepPurple,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── About ──
          _SectionCard(
            cardBg: cardBg,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Colors.deepPurple, size: 20),
                  ),
                  title: const Text('About DayCraft', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'DayCraft',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 DayCraft',
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('A productivity app for students to manage tasks, deadlines, and schedules.'),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  ),
                  title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Sign Out"),
                        content: const Text("Are you sure you want to sign out?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: const Text("Sign Out"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey));
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color cardBg;

  const _SectionCard({required this.child, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}
