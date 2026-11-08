import 'package:flutter/material.dart';

import '../services/asset_catalog.dart';

/// Iconos propios del juego (assets/images/icons/) que sustituyen a los
/// emojis. Cada marca de teléfono dibuja los emojis a su manera; con imágenes
/// propias el juego se ve igual en todos y con su estilo.
///
/// El código sigue escribiendo el emoji (es corto y se entiende), y estos
/// widgets lo cambian por su imagen al dibujarlo. Si un emoji no tiene icono
/// (o la imagen falta), se dibuja el emoji de siempre.
const Map<String, String> kGameIcons = {
  '🪙': 'coin',
  '💰': 'coin',
  '💎': 'gem',
  '❤️': 'heart',
  '❤': 'heart',
  '💡': 'hint',
  '🧪': 'potion',
  '⭐': 'star',
  '🏆': 'trophy',
  '🗝️': 'key',
  '🗝': 'key',
  '🔑': 'key',
  '🎁': 'chest',
  '📖': 'xp',
};

/// Un emoji del juego dibujado con su icono propio.
class GameIcon extends StatelessWidget {
  final String emoji;

  /// Tamaño equivalente al fontSize que tendría el emoji como texto.
  final double size;

  const GameIcon(this.emoji, {super.key, this.size = 16});

  /// Imagen que corresponde al emoji, o null si no hay.
  static String? assetFor(String emoji) {
    final name = kGameIcons[emoji.trim()];
    if (name == null) return null;
    final asset = 'assets/images/icons/icon_$name.png';
    return AssetCatalog.has(asset) ? asset : null;
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(emoji);
    if (asset == null) return Text(emoji, style: TextStyle(fontSize: size));
    // Un emoji ocupa algo más que su fontSize; así el icono mide lo mismo.
    final side = size * 1.2;
    return Image.asset(
      asset,
      width: side,
      height: side,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Texto que puede llevar emojis del juego dentro ("+80 🪙 +1 💡"): los
/// emojis con icono se dibujan como imagen, el resto queda como texto.
class GameText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const GameText(this.text, {super.key, this.style, this.textAlign});

  static final RegExp _pattern = RegExp(
    // Los más largos primero, para que '❤️' gane a '❤'.
    (kGameIcons.keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
        .map(RegExp.escape)
        .join('|'),
  );

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final size = base.fontSize ?? 14;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GameIcon(m.group(0)!, size: size),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: style, textAlign: textAlign);
  }
}
