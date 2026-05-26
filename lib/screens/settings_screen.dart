import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../services/rest_sound_player.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _assetPathController;

  @override
  void initState() {
    super.initState();

    final settingsBox = Hive.box('settings');
    _assetPathController = TextEditingController(
      text: RestSoundPlayer.assetPath(settingsBox),
    );
  }

  @override
  void dispose() {
    _assetPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050A0F),
        foregroundColor: const Color(0xFFEAF2F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<Box<dynamic>>(
          valueListenable: Hive.box('settings').listenable(),
          builder: (context, settingsBox, _) {
            final soundEnabled = RestSoundPlayer.isEnabled(settingsBox);
            final currentAssetPath = RestSoundPlayer.assetPath(settingsBox);

            if (_assetPathController.text != currentAssetPath &&
                !_assetPathController.selection.isValid) {
              _assetPathController.text = currentAssetPath;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                _SettingsSection(
                  title: 'Satzpause',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SoundToggleTile(
                        enabled: soundEnabled,
                        onChanged: (value) async {
                          await RestSoundPlayer.setEnabled(settingsBox, value);
                        },
                      ),
                      const SizedBox(height: 16),
                      _AssetPathField(
                        controller: _assetPathController,
                        enabled: soundEnabled,
                        onSave: () async {
                          await RestSoundPlayer.setAssetPath(
                            settingsBox,
                            _assetPathController.text,
                          );

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sound-Datei gespeichert.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _TestSoundButton(
                        enabled: soundEnabled,
                        onTap: soundEnabled
                            ? () async {
                                await RestSoundPlayer.play(settingsBox);
                              }
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const _HintBox(
                        text:
                            'Lege deine .wav oder .mp3 Datei zum Beispiel unter assets/audio/rest_complete.wav ab und trage denselben Pfad hier ein. In pubspec.yaml muss der Asset-Pfad ebenfalls registriert sein.',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF09131B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.07),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFEAF2F4),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SoundToggleTile extends StatelessWidget {
  const _SoundToggleTile({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF050A0F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF00E5FF).withValues(alpha: 0.09),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: const Color(0xFF7DD3FC),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ton nach Satzpause',
                  style: TextStyle(
                    color: Color(0xFFEAF2F4),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'Aktiv' : 'Lautlos',
                  style: const TextStyle(
                    color: Color(0xFF8A93A3),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: const Color(0xFF3DDC97),
            activeTrackColor: const Color(0xFF3DDC97).withValues(alpha: 0.22),
            inactiveThumbColor: const Color(0xFF64748B),
            inactiveTrackColor: const Color(0xFF1F2937),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AssetPathField extends StatelessWidget {
  const _AssetPathField({
    required this.controller,
    required this.enabled,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: const TextStyle(
              color: Color(0xFFEAF2F4),
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Sound-Datei',
              hintText: RestSoundPlayer.defaultAssetPath,
              labelStyle: const TextStyle(color: Color(0xFF8A93A3)),
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              prefixIcon: const Icon(
                Icons.audio_file_rounded,
                color: Color(0xFF7DD3FC),
              ),
              filled: true,
              fillColor: const Color(0xFF050A0F),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: const Color(0xFF64748B).withValues(alpha: 0.20),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(54, 54),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF1F2937),
              disabledForegroundColor: const Color(0xFF64748B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: enabled ? onSave : null,
            child: const Icon(Icons.save_rounded),
          ),
        ),
      ],
    );
  }
}

class _TestSoundButton extends StatelessWidget {
  const _TestSoundButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00E5FF),
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF1F2937),
          disabledForegroundColor: const Color(0xFF64748B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onTap,
        icon: Icon(enabled ? Icons.play_arrow_rounded : Icons.volume_off_rounded),
        label: const Text(
          'Testton abspielen',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF8A93A3),
          height: 1.35,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
