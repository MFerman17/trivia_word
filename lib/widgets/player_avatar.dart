import 'package:flutter/material.dart';
import '../models/player_profile.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.profile,
    this.radius = 24,
  });

  final PlayerProfile profile;
  final double radius;

  static const Map<String, String> _characterAssets = {
    'explorador': 'assets/images/avatar_explorer.png',
    'maga': 'assets/images/avatar_mage.png',
    'guardian': 'assets/images/avatar_guardian.png',
  };

  static const Map<String, String> _characterFallbacks = {
    'explorador': '🧝',
    'maga': '🧙‍♀️',
    'guardian': '🛡️',
  };

  static const Map<String, Color> _frames = {
    'basico': Color(0xFF1EE3CF),
    'bosque': Color(0xFF71D57A),
    'magma': Color(0xFFFF8A50),
  };

  static const Map<String, String> _accessories = {
    'ninguno': '',
    'brujula': '🧭',
    'dragoncito': '🐉',
  };

  @override
  Widget build(BuildContext context) {
    final frameColor = _frames[profile.avatarFrameId] ?? _frames['basico']!;
    final characterAsset = _characterAssets[profile.avatarCharacterId] ??
        _characterAssets['explorador']!;
    final characterFallback =
        _characterFallbacks[profile.avatarCharacterId] ?? '🧝';
    final accessory = _accessories[profile.avatarAccessoryId] ?? '';

    return SizedBox(
      width: radius * 2 + 10,
      height: radius * 2 + 10,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: radius * 2 + 6,
            height: radius * 2 + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [frameColor, frameColor.withValues(alpha: 0.45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: frameColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: const BoxDecoration(
                  color: Color(0xFF1F1D36),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: ClipOval(
                  child: Image.asset(
                    characterAsset,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.12),
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        characterFallback,
                        style: TextStyle(fontSize: radius * 1.12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (accessory.isNotEmpty)
            Positioned(
              top: -2,
              right: -1,
              child: Text(accessory, style: TextStyle(fontSize: radius * 0.65)),
            ),
        ],
      ),
    );
  }
}
