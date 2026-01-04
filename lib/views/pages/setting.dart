import 'package:ai_models/shared/ProviderX/provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _hapticFeedback = true;
  bool _spellCheck = true;
  bool _separateMode = false;
  bool _backgroundConv = false;
  bool _autocomplete = true;
  bool _trending = true;
  bool _followUp = true;
  String _selectedAppearance = "System";

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF171717),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      "Settings",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                         decoration: const BoxDecoration(
                           color: Color(0xFF2C2C2E),
                           shape: BoxShape.circle,
                         ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 20),
                    Consumer<Userprovider>(
                      builder: (context, provider, child) {
                        final firstName = provider.firstname.isNotEmpty ? provider.firstname : "Steven";
                        final lastName = provider.lastname.isNotEmpty ? provider.lastname : "Damilola";
                        final fullName = "$firstName $lastName";
                        final initial = (firstName.isNotEmpty ? firstName.substring(0, 1) : "S") +
                            (lastName.isNotEmpty ? lastName.substring(0, 1) : "D");
                        final username = provider.username.isNotEmpty ? provider.username : "q2xcrnwnz6";

                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFF545456),
                              child: Text(
                                initial.toUpperCase(),
                                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.normal),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF38383A)),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Edit profile", style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    _buildSectionHeader("Account"),
                    _buildGroup([
                      Consumer<Userprovider>(
                        builder: (c, p, _) {
                            final email = p.email.isNotEmpty ? p.email : "q2xcrnwnz6@privaterelay.appleid.com";
                            return _buildSettingsTile(
                                icon: Icons.email_outlined,
                                title: "Email",
                                subtitle: email,
                                showChevron: false,
                            );
                        }
                      ),
                      _buildSettingsTile(icon: Icons.add_circle_outline, title: "Subscription", trailingText: "Free Plan", showChevron: false),
                      _buildSettingsTile(icon: Icons.auto_awesome_outlined, title: "Upgrade to EmergeX pro", showChevron: false),
                      _buildSettingsTile(icon: Icons.refresh, title: "Restore purchases", showChevron: false),
                      _buildSettingsTile(icon: Icons.person_outline, title: "Personalization"),
                      _buildSettingsTile(icon: Icons.notifications_outlined, title: "Notifications"),
                      _buildSettingsTile(icon: Icons.grid_view, title: "Apps"),
                      _buildSettingsTile(icon: Icons.people_outline, title: "Parental controls"),
                      _buildSettingsTile(icon: Icons.table_rows_outlined, title: "Data controls"),
                      _buildSettingsTile(icon: Icons.archive_outlined, title: "Archived chats"),
                      _buildSettingsTile(icon: Icons.security, title: "Security"),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader("App"),
                    _buildGroup([
                      _buildSettingsTile(icon: Icons.language, title: "App language", trailingText: "English"),
                      _buildSettingsTile(
                          icon: Icons.dark_mode_outlined,
                          title: "Appearance",
                          trailingText: _selectedAppearance,
                          isDropdown: true,
                          showChevron: false,
                          onTap: () => _showAppearanceMenu(context),
                      ),
                      _buildSettingsTile(icon: Icons.color_lens_outlined, title: "Accent color", trailingWidget: _buildColorCircle(), trailingText: "Default"),
                      _buildSwitchTile(icon: Icons.vibration, title: "Haptic feedback", value: _hapticFeedback, onChanged: (v) => setState(() => _hapticFeedback = v)),
                      _buildSwitchTile(icon: Icons.spellcheck, title: "Correct spelling automatically", value: _spellCheck, onChanged: (v) => setState(() => _spellCheck = v)),
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionHeader("Speech"),
                    _buildGroup([
                       _buildSettingsTile(icon: Icons.language, title: "Main language", isDropdown: true),
                    ]),
                    const SizedBox(height: 12),
                     Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Text("Voice mode", style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    _buildGroup([
                        _buildSettingsTile(icon: Icons.graphic_eq, title: "Voice", trailingText: "Spruce"), 
                        _buildSwitchTile(icon: Icons.tune, title: "Separate mode", value: _separateMode, onChanged: (v) => setState(() => _separateMode = v)),
                        _buildSwitchTile(icon: Icons.chat_bubble_outline, title: "Background conversations", value: _backgroundConv, onChanged: (v) => setState(() => _backgroundConv = v)),

                    ]),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Background conversations keep the conversation going in other apps or while your screen is off.\nLearn more", style: TextStyle(color: Colors.grey, fontSize: 12))),

                    const SizedBox(height: 16),
                    _buildSectionHeader("Suggestions"),
                    _buildGroup([
                      _buildSwitchTile(icon: Icons.edit_outlined, title: "Autocomplete", value: _autocomplete, onChanged: (v) => setState(() => _autocomplete = v)),
                      _buildSwitchTile(icon: Icons.trending_up, title: "Trending searches", value: _trending, onChanged: (v) => setState(() => _trending = v)),
                      _buildSwitchTile(icon: Icons.reply, title: "Follow-up suggestions", value: _followUp, onChanged: (v) => setState(() => _followUp = v)),
                    ]),

                     const SizedBox(height: 24),
                    _buildSectionHeader("About"),
                    _buildGroup([
                      _buildSettingsTile(icon: Icons.bug_report_outlined, title: "Report bug", showChevron: false),
                      _buildSettingsTile(icon: Icons.help_outline, title: "Help Center", showChevron: false),
                      _buildSettingsTile(icon: Icons.description_outlined, title: "Terms of Use", showChevron: false),
                      _buildSettingsTile(icon: Icons.lock_outline, title: "Privacy Policy", showChevron: false),
                      _buildSettingsTile(icon: Icons.circle, title: "ChatGPT for iOS", subtitle: "1.2025.350 (20387701780)", showChevron: false),
                    ]),

                    const SizedBox(height: 24),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                            color: const Color(0xFF242426),
                            borderRadius: BorderRadius.circular(16)
                        ),
                        child: const Center(
                            child: Text("Log out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))
                        )
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAppearanceMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            elevation: 24,
            child: SizedBox(
              width: 250,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppearanceOption("System"),
                  const Divider(height: 1, color: Colors.white12),
                  _buildAppearanceOption("Dark"),
                  const Divider(height: 1, color: Colors.white12),
                  _buildAppearanceOption("Light"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppearanceOption(String label) {
    final isSelected = _selectedAppearance == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAppearance = label;
        });
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none, 
                fontFamily: '.SF Pro Text', 
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[400],
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF242426),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
            for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                     const Divider(height: 1, color: Colors.white12, indent: 50),
            ]
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    bool showChevron = true,
    bool isDropdown = false,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 24),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null) Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 15)),
            if (trailingWidget != null) Padding(padding: const EdgeInsets.only(left: 8), child: trailingWidget),
            if (isDropdown) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.unfold_more, color: Colors.grey, size: 20)),
            if (showChevron && !isDropdown) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14)),
          ],
        ),
        onTap: onTap ?? () {},
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        dense: true,
        visualDensity: const VisualDensity(vertical: 0), 
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: ListTile(
          leading: Icon(icon, color: Colors.white, size: 24),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16)),
          trailing: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
               activeTrackColor: Colors.green,
          ),
           minLeadingWidth: 20,
           contentPadding: const EdgeInsets.symmetric(horizontal: 16),
           dense: true,
           visualDensity: const VisualDensity(vertical: 0),
        ),
      );
  }
  
  Widget _buildColorCircle() {
      return Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
               border: Border.all(color: Colors.grey, width: 2)
          ),
      );
  }
}
