import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/countries.dart';
import '../l10n/l10n.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/cloud_service.dart';
import '../services/locale_service.dart';
import '../services/save_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/player_avatar.dart';

/// Alias y país del jugador.
///
/// - La primera vez que se abre el juego aparece sola (sin botón de volver):
///   el alias es lo que identifica al jugador en el ranking.
/// - Desde el Perfil se abre en modo edición ([editing] = true).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.profile, this.editing = false});

  final PlayerProfile profile;
  final bool editing;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final TextEditingController _alias = TextEditingController(
    // El nombre por defecto ("Jugador 1") no se propone como alias.
    text: widget.profile.name == 'Jugador 1' ? '' : widget.profile.name,
  );
  String? _country;
  String? _error;
  bool _saving = false;

  /// Letras (de cualquier idioma), números, espacios y _ . -
  static final RegExp _validAlias = RegExp(r'^[\p{L}\p{N} _.\-]{3,16}$', unicode: true);

  /// Palabras que no se aceptan dentro de un alias (lista básica).
  static const List<String> _blocked = [
    'puta', 'puto', 'mierda', 'joder', 'coño', 'polla', 'verga', 'pendej',
    'cabron', 'cabrón', 'marica', 'zorra', 'fuck', 'shit', 'bitch', 'dick',
    'pussy', 'nigg', 'nazi', 'hitler', 'porn', 'sexo', 'sex',
  ];

  @override
  void initState() {
    super.initState();
    final saved = widget.profile.country;
    if (saved.isNotEmpty) {
      _country = saved;
    } else {
      // Propuesta inicial: el país del teléfono, si está en la lista.
      final device = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (device != null && Countries.all.containsKey(device.toUpperCase())) {
        _country = device.toUpperCase();
      }
    }
  }

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  String? _validate(String alias) {
    if (!_validAlias.hasMatch(alias)) return context.l10n.aliasInvalid;
    final lower = alias.toLowerCase().replaceAll(RegExp(r'[\s_.\-]'), '');
    if (_blocked.any(lower.contains)) return context.l10n.aliasNotAllowed;
    if (_country == null) return context.l10n.countryRequired;
    return null;
  }

  Future<void> _save() async {
    // Espacios repetidos se juntan en uno.
    final alias = _alias.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final error = _validate(alias);
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _saving = true);
    AudioService.playEquip();
    final profile = widget.profile
      ..name = alias
      ..country = _country!;
    await SaveService.savePlayerData(profile);
    // Sube el alias y la bandera al ranking (si no hay internet, se hará
    // en la siguiente sincronización).
    CloudService.syncProfileToCloud(profile);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickCountry() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPicker(selected: _country),
    );
    if (code != null) {
      AudioService.playSelect();
      setState(() {
        _country = code;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = LocaleService.languageCode;
    return PopScope(
      // La primera vez no se puede salir sin elegir alias y país.
      canPop: widget.editing,
      child: Scaffold(
        backgroundColor: WM.outline,
        body: GameBackground(
          child: SafeArea(
            child: Column(
              children: [
                if (widget.editing) GameHeader(title: l.editProfileTitle),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      if (!widget.editing) ...[
                        OutlinedGameText(
                          l.welcomeTitle,
                          size: 28,
                          letterSpacing: 1.5,
                          colors: const [WM.cyanLight, WM.cyan],
                        ),
                        const SizedBox(height: 14),
                      ],
                      Center(
                        child: Bob(
                          amplitude: 5,
                          child: PlayerAvatar(profile: widget.profile, radius: 48),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!widget.editing)
                        Text(
                          l.welcomeBody,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.oswald(color: Colors.white70, fontSize: 15),
                        ),
                      const SizedBox(height: 18),
                      Panel3D(
                        accent: WM.cyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(l.aliasLabel),
                            TextField(
                              controller: _alias,
                              maxLength: 16,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.oswald(color: Colors.white, fontSize: 20),
                              onChanged: (_) => setState(() => _error = null),
                              decoration: InputDecoration(
                                hintText: l.aliasHint,
                                hintStyle: GoogleFonts.oswald(color: Colors.white30),
                                counterStyle: GoogleFonts.oswald(color: Colors.white38),
                                filled: true,
                                fillColor: WM.outline.withValues(alpha: 0.7),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.white24, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: WM.cyan, width: 2),
                                ),
                              ),
                            ),
                            Text(
                              l.aliasRules,
                              style: GoogleFonts.oswald(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            _label(l.countryLabel),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: Pressable3D(
                                onTap: _pickCountry,
                                color: const Color(0xFF3A2A7A),
                                height: 50,
                                child: Row(
                                  children: [
                                    Text(Countries.flag(_country), style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _country == null
                                            ? l.chooseCountry
                                            : Countries.name(_country!, lang),
                                        style: GoogleFonts.oswald(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.expand_more_rounded, color: WM.cyan),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.oswald(color: const Color(0xFFFFB3BA), fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Pulse(
                        amount: 0.03,
                        child: Pressable3D(
                          onTap: _saving ? null : _save,
                          color: WM.gold,
                          height: 56,
                          child: OutlinedGameText(
                            widget.editing ? l.saveButton : l.startPlaying,
                            size: 20,
                            font: GameFont.oswald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.oswald(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      );
}

/// Lista de países con buscador, en una hoja que sube desde abajo.
class _CountryPicker extends StatefulWidget {
  const _CountryPicker({this.selected});
  final String? selected;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _query = '';

  /// Para buscar sin importar tildes ni mayúsculas ("peru" encuentra Perú).
  String _plain(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  Widget build(BuildContext context) {
    final lang = LocaleService.languageCode;
    final codes = Countries.all.keys
        .where((c) => _plain(Countries.name(c, lang)).contains(_plain(_query)))
        .toList()
      ..sort((a, b) => _plain(Countries.name(a, lang)).compareTo(_plain(Countries.name(b, lang))));

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A0F40),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: WM.cyan, width: 2)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.oswald(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, color: WM.cyan),
                  hintText: context.l10n.searchCountry,
                  hintStyle: GoogleFonts.oswald(color: Colors.white38),
                  filled: true,
                  fillColor: WM.outline,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: codes.length,
                itemBuilder: (context, i) {
                  final code = codes[i];
                  final selected = code == widget.selected;
                  return ListTile(
                    leading: Text(Countries.flag(code), style: const TextStyle(fontSize: 26)),
                    title: Text(
                      Countries.name(code, lang),
                      style: GoogleFonts.oswald(
                        color: selected ? WM.cyan : Colors.white,
                        fontSize: 16,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    trailing: selected ? const Icon(Icons.check_rounded, color: WM.cyan) : null,
                    onTap: () => Navigator.of(context).pop(code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
