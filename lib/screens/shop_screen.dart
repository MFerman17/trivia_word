import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player_profile.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/particle_explosion.dart';
import '../widgets/player_avatar.dart';

enum _CosmeticSlot { character, frame, accessory }

class _CosmeticOption {
  const _CosmeticOption({
    required this.id,
    required this.name,
    required this.emoji,
    this.coins = 0,
    this.gems = 0,
  });

  final String id;
  final String name;
  final String emoji;
  final int coins;
  final int gems;
}

class _ShopOffer {
  const _ShopOffer({
    required this.name,
    required this.description,
    required this.emoji,
    required this.price,
    required this.payWithGems,
    this.potions = 0,
    this.hints = 0,
    this.coins = 0,
    this.valueNote,
  });

  final String name;
  final String description;
  final String emoji;
  final int price;
  final bool payWithGems;
  final int potions;
  final int hints;
  final int coins;
  final String? valueNote;
}

const List<_CosmeticOption> _characters = [
  _CosmeticOption(id: 'explorador', name: 'Explorador', emoji: '🧝'),
  _CosmeticOption(id: 'maga', name: 'Maga', emoji: '🧙‍♀️', gems: 5),
  _CosmeticOption(id: 'guardian', name: 'Guardián', emoji: '🛡️', coins: 220),
];

const List<_CosmeticOption> _frames = [
  _CosmeticOption(id: 'basico', name: 'Cian', emoji: '🔹'),
  _CosmeticOption(id: 'bosque', name: 'Bosque', emoji: '🌿', coins: 150),
  _CosmeticOption(id: 'magma', name: 'Magma', emoji: '🔥', gems: 6),
];

const List<_CosmeticOption> _accessories = [
  _CosmeticOption(id: 'ninguno', name: 'Ninguno', emoji: '—'),
  _CosmeticOption(id: 'brujula', name: 'Brújula', emoji: '🧭', coins: 100),
  _CosmeticOption(id: 'dragoncito', name: 'Dragón', emoji: '🐉', gems: 8),
];

const List<_ShopOffer> _offers = [
  _ShopOffer(
    name: 'Kit del Explorador',
    description: '1 poción + 2 pistas',
    emoji: '🧭',
    price: 180,
    payWithGems: false,
    potions: 1,
    hints: 2,
    valueNote: 'Ahorra 30 monedas frente al valor por separado.',
  ),
  _ShopOffer(
    name: 'Kit de Expedición',
    description: '3 pociones + 4 pistas',
    emoji: '🎒',
    price: 400,
    payWithGems: false,
    potions: 3,
    hints: 4,
    valueNote: 'Ahorra 70 monedas frente al valor por separado.',
  ),
  _ShopOffer(
    name: 'Trío de pociones',
    description: '3 pociones de salud',
    emoji: '🧪',
    price: 135,
    payWithGems: false,
    potions: 3,
    valueNote: 'Ahorra 15 monedas frente a comprarlas por unidad.',
  ),
  _ShopOffer(
    name: 'Trío de pistas',
    description: '3 pistas para tus partidas',
    emoji: '💡',
    price: 5,
    payWithGems: true,
    hints: 3,
    valueNote: 'Una gema menos que comprar las 3 por unidad.',
  ),
  _ShopOffer(
    name: 'Mochila de oro',
    description: '550 monedas para tus próximas compras',
    emoji: '💰',
    price: 12,
    payWithGems: true,
    coins: 550,
    valueNote: 'Incluye 70 monedas extra frente al cambio habitual.',
  ),
];

class ShopScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  const ShopScreen({super.key, this.playerProfile});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late PlayerProfile profile;
  late TabController _tabController;
  String _previewCharacter = 'explorador';
  String _previewFrame = 'basico';
  String _previewAccessory = 'ninguno';
  _CosmeticSlot _activeSlot = _CosmeticSlot.character;
  bool _isBusy = false;
  // Qué elemento debe soltar chispas (antes era un bool y explotaban TODAS
  // las tarjetas a la vez con cualquier compra).
  String? _sparkleId;
  // Qué anuncio se está cargando (antes giraban los dos botones a la vez).
  String? _loadingAd;

  @override
  void initState() {
    super.initState();
    profile = widget.playerProfile ?? PlayerProfile();
    _previewCharacter = profile.avatarCharacterId;
    _previewFrame = profile.avatarFrameId;
    _previewAccessory = profile.avatarAccessoryId;
    _tabController = TabController(length: 3, vsync: this);
    AdService.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await SaveService.savePlayerData(profile);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.oswald(fontSize: 14)),
          // Fondo oscuro para que el texto blanco se lea bien
          backgroundColor: error ? const Color(0xFFB3261E) : const Color(0xFF0A6F66),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  List<_CosmeticOption> _optionsFor(_CosmeticSlot slot) => switch (slot) {
        _CosmeticSlot.character => _characters,
        _CosmeticSlot.frame => _frames,
        _CosmeticSlot.accessory => _accessories,
      };

  String _previewFor(_CosmeticSlot slot) => switch (slot) {
        _CosmeticSlot.character => _previewCharacter,
        _CosmeticSlot.frame => _previewFrame,
        _CosmeticSlot.accessory => _previewAccessory,
      };

  String _equippedFor(_CosmeticSlot slot) => switch (slot) {
        _CosmeticSlot.character => profile.avatarCharacterId,
        _CosmeticSlot.frame => profile.avatarFrameId,
        _CosmeticSlot.accessory => profile.avatarAccessoryId,
      };

  List<String> _ownedFor(_CosmeticSlot slot) => switch (slot) {
        _CosmeticSlot.character => profile.ownedAvatarCharacters,
        _CosmeticSlot.frame => profile.ownedAvatarFrames,
        _CosmeticSlot.accessory => profile.ownedAvatarAccessories,
      };

  void _selectCosmetic(_CosmeticSlot slot, String id) {
    setState(() {
      _activeSlot = slot;
      switch (slot) {
        case _CosmeticSlot.character:
          _previewCharacter = id;
        case _CosmeticSlot.frame:
          _previewFrame = id;
        case _CosmeticSlot.accessory:
          _previewAccessory = id;
      }
    });
  }

  Future<void> _unlockOrEquipPreview() async {
    if (_isBusy) return;
    final slot = _activeSlot;
    final id = _previewFor(slot);
    final option = _optionsFor(slot).firstWhere((item) => item.id == id);
    final isOwned = _ownedFor(slot).contains(id);

    if (_equippedFor(slot) == id) return;
    if (!isOwned &&
        (profile.coins < option.coins || profile.gems < option.gems)) {
      _showMessage('No tienes suficientes monedas o gemas.', error: true);
      return;
    }
    final previousProfile = profile.toJson();

    setState(() {
      if (!isOwned) {
        profile.coins -= option.coins;
        profile.gems -= option.gems;
        _ownedFor(slot).add(id);
      }
      switch (slot) {
        case _CosmeticSlot.character:
          profile.avatarCharacterId = id;
        case _CosmeticSlot.frame:
          profile.avatarFrameId = id;
        case _CosmeticSlot.accessory:
          profile.avatarAccessoryId = id;
      }
      _isBusy = true;
    });

    try {
      await _saveProfile();
      if (!mounted) return;
      // Equipar algo que ya tienes suena distinto que desbloquearlo.
      isOwned ? AudioService.playEquip() : AudioService.playBuyItem();
      setState(() {
        _isBusy = false;
        _sparkleId = 'avatar';
      });
      _showMessage(isOwned ? '¡Nuevo aspecto equipado!' : '¡Aspecto desbloqueado y equipado!');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _sparkleId = null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profile = PlayerProfile.fromJson(previousProfile);
        _isBusy = false;
      });
      _showMessage('No se pudo guardar el aspecto. Inténtalo de nuevo.', error: true);
    }
  }

  Future<void> _purchaseOffer(_ShopOffer offer) async {
    if (_isBusy) return;
    final balance = offer.payWithGems ? profile.gems : profile.coins;
    if (balance < offer.price) {
      _showMessage('No tienes suficientes ${offer.payWithGems ? 'gemas' : 'monedas'}.', error: true);
      return;
    }
    final previousProfile = profile.toJson();

    setState(() {
      if (offer.payWithGems) {
        profile.gems -= offer.price;
      } else {
        profile.coins -= offer.price;
      }
      profile.healthPotions += offer.potions;
      profile.letterHints += offer.hints;
      profile.coins += offer.coins;
      _isBusy = true;
    });

    try {
      await _saveProfile();
      QuestService.incrementProgress('buy_shop_item_1');
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _sparkleId = offer.name;
      });
      AudioService.playBuyItem();
      _showMessage('¡${offer.name} añadido a tu inventario!');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _sparkleId = null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profile = PlayerProfile.fromJson(previousProfile);
        _isBusy = false;
      });
      _showMessage('No se pudo completar la compra.', error: true);
    }
  }

  Future<void> _watchAdForReward(String rewardName, VoidCallback reward) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _loadingAd = rewardName;
    });
    final previousProfile = profile.toJson();
    try {
      final earned = await AdService.showRewardedAd();
      if (!mounted) return;

      if (earned) {
        AudioService.playCoins();
        setState(reward);
        await _saveProfile();
        if (mounted) _showMessage('¡Recompensa recibida: $rewardName!');
      } else {
        _showMessage('No hay anuncios disponibles ahora. Prueba de nuevo más tarde.', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      profile = PlayerProfile.fromJson(previousProfile);
      _showMessage('No se pudo guardar la recompensa. Inténtalo de nuevo.', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _loadingAd = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'TIENDA',
                onBack: () {
                  AudioService.playButtonClick();
                  Navigator.pop(context, profile);
                },
              ),
              _buildBalanceBanner(),
              _buildTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvatarStudio(),
                    _buildCombos(),
                    _buildRewards(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // SALDO: monedas y gemas en engastes 3D
  // ---------------------------------------------------------------
  Widget _buildBalanceBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Panel3D(
        accent: WM.gold,
        depth: 5,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(child: _buildBalanceBadge('🪙', 'MONEDAS', profile.coins, WM.gold)),
            Container(
              height: 34,
              width: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: WM.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: _buildBalanceBadge('💎', 'GEMAS', profile.gems, WM.cyan)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceBadge(String icon, String label, int amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Socket3D(
          size: 40,
          color: color,
          child: Text(icon, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.oswald(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            OutlinedGameText('$amount', size: 20, colors: [Colors.white, shade(color, 0.15)]),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // PESTAÑAS 3D: la activa es dorada y está "hundida" (menos canto),
  // como un interruptor pulsado. Siguen el TabController, así que
  // también cambian al deslizar entre pestañas con el dedo.
  // ---------------------------------------------------------------
  Widget _buildTabs() {
    const labels = ['AVATAR', 'COMBOS', 'PREMIOS'];
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Pressable3D(
                  slanted: true,
                  height: 36,
                  depth: _tabController.index == i ? 2 : 5,
                  radius: 8,
                  padding: EdgeInsets.zero,
                  color: _tabController.index == i ? WM.gold : const Color(0xFF3A2A7A),
                  onTap: () {
                    AudioService.playButtonClick();
                    _tabController.animateTo(i);
                  },
                  child: OutlinedGameText(labels[i], size: 14, font: GameFont.oswald),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // PESTAÑA AVATAR
  // ---------------------------------------------------------------
  Widget _buildAvatarStudio() {
    final option = _optionsFor(_activeSlot).firstWhere(
      (item) => item.id == _previewFor(_activeSlot),
    );
    final owned = _ownedFor(_activeSlot).contains(option.id);
    final equipped = _equippedFor(_activeSlot) == option.id;
    final slotName = switch (_activeSlot) {
      _CosmeticSlot.character => 'PERSONAJE',
      _CosmeticSlot.frame => 'MARCO',
      _CosmeticSlot.accessory => 'ACCESORIO',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        EntranceFlip(index: 0, child: _buildAvatarPreview()),
        const SizedBox(height: 18),
        EntranceFlip(
          index: 1,
          child: _buildCosmeticSelector('PERSONAJE', _CosmeticSlot.character, _characters),
        ),
        EntranceFlip(
          index: 2,
          child: _buildCosmeticSelector('MARCO', _CosmeticSlot.frame, _frames),
        ),
        EntranceFlip(
          index: 3,
          child: _buildCosmeticSelector('ACCESORIO', _CosmeticSlot.accessory, _accessories),
        ),
        const SizedBox(height: 4),
        // Deja claro sobre qué pieza actúa el botón
        Center(
          child: Text(
            'Seleccionado: $slotName · ${option.name}',
            style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Pressable3D(
            onTap: _isBusy || equipped ? null : _unlockOrEquipPreview,
            color: owned ? WM.cyan : WM.gold,
            // Equipado = éxito (verde), no "desactivado" (gris)
            disabledColor: equipped ? const Color(0xFF1E8C3A) : const Color(0xFF4A4660),
            height: 54,
            // Los emojis van en un Text normal: el texto con contorno dibuja
            // cada letra 3 veces y un emoji saldría triplicado.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedGameText(
                  equipped
                      ? 'EQUIPADO'
                      : owned
                          ? 'EQUIPAR'
                          : _isFree(option)
                              ? 'DESBLOQUEAR GRATIS'
                              : 'DESBLOQUEAR',
                  size: 18,
                  font: GameFont.oswald,
                ),
                if (!owned && !_isFree(option)) ...[
                  const SizedBox(width: 10),
                  Text(option.coins > 0 ? '🪙' : '💎', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  OutlinedGameText(
                    '${option.coins > 0 ? option.coins : option.gems}',
                    size: 18,
                    font: GameFont.oswald,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPreview() {
    return Panel3D(
      accent: WM.cyan,
      glow: 0.3,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            width: 220,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  bottom: 20,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [WM.cyan.withValues(alpha: 0.3), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: CustomPaint(size: const Size(170, 46), painter: PedestalPainter()),
                ),
                Positioned(
                  bottom: 26,
                  child: ParticleExplosion(
                    trigger: _sparkleId == 'avatar',
                    particleEmoji: '✨',
                    particleCount: 18,
                    child: Bob(
                      amplitude: 6,
                      child: PlayerAvatar(
                        profile: PlayerProfile(
                          avatarCharacterId: _previewCharacter,
                          avatarFrameId: _previewFrame,
                          avatarAccessoryId: _previewAccessory,
                        ),
                        radius: 52,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const OutlinedGameText('TALLER DE HÉROES', size: 20, letterSpacing: 1.5),
          const SizedBox(height: 4),
          Text(
            'Combina personaje, marco y accesorio. Tu avatar no cambia tus estadísticas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCosmeticSelector(
    String title,
    _CosmeticSlot slot,
    List<_CosmeticOption> options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: OutlinedGameText(
              title,
              size: 15,
              font: GameFont.oswald,
              letterSpacing: 1.5,
              colors: const [WM.cyanLight, WM.cyan],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _buildCosmeticTile(slot, options[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Cada casilla muestra el avatar COMPLETO con esa pieza puesta, así el
  // jugador ve el resultado antes de elegir (antes era solo un emoji).
  Widget _buildCosmeticTile(_CosmeticSlot slot, _CosmeticOption item) {
    final selected = _previewFor(slot) == item.id;
    final isOwned = _ownedFor(slot).contains(item.id);
    final isEquipped = _equippedFor(slot) == item.id;

    final preview = PlayerProfile(
      avatarCharacterId: slot == _CosmeticSlot.character ? item.id : _previewCharacter,
      avatarFrameId: slot == _CosmeticSlot.frame ? item.id : _previewFrame,
      avatarAccessoryId: slot == _CosmeticSlot.accessory ? item.id : _previewAccessory,
    );

    final Widget status = isEquipped
        ? Text(
            'EQUIPADO',
            style: GoogleFonts.anton(color: WM.green, fontSize: 11, letterSpacing: 1),
          )
        : isOwned
            ? Text(
                '✔ TUYO',
                style: GoogleFonts.anton(color: WM.cyan, fontSize: 11, letterSpacing: 1),
              )
            : Chip3D(
                emoji: item.coins > 0 ? '🪙' : '💎',
                text: '${item.coins > 0 ? item.coins : item.gems}',
                accent: item.coins > 0 ? WM.gold : WM.cyan,
                fontSize: 11,
              );

    return GestureDetector(
      onTap: () {
        AudioService.playSelect();
        _selectCosmetic(slot, item.id);
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: selected ? 1.0 : 0.94,
        child: Panel3D(
          accent: selected ? WM.cyan : WM.violet,
          glow: selected ? 0.9 : 0,
          depth: 5,
          radius: 14,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Column(
            children: [
              PlayerAvatar(profile: preview, radius: 22),
              const SizedBox(height: 4),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.oswald(
                  color: selected ? WM.bone : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(height: 22, child: Center(child: status)),
            ],
          ),
        ),
      ),
    );
  }

  bool _isFree(_CosmeticOption option) => option.coins == 0 && option.gems == 0;

  // ---------------------------------------------------------------
  // PESTAÑA COMBOS
  // ---------------------------------------------------------------
  Widget _buildCombos() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _buildSectionHeading(
          'EQUÍPATE PARA LA AVENTURA',
          'Combos con descuento frente a comprar cada artículo por separado.',
        ),
        for (var i = 0; i < _offers.length; i++)
          EntranceFlip(index: i, child: _buildOfferCard(_offers[i])),
        const SizedBox(height: 6),
        Text(
          'Referencia de valor: 5 gemas se cambian por 200 monedas en la tienda.',
          textAlign: TextAlign.center,
          style: GoogleFonts.oswald(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedGameText(
            title,
            size: 18,
            colors: const [WM.cyanLight, WM.cyan],
            letterSpacing: 1,
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: GoogleFonts.oswald(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildOfferCard(_ShopOffer offer) {
    final Color currency = offer.payWithGems ? WM.cyan : WM.gold;
    final int balance = offer.payWithGems ? profile.gems : profile.coins;
    final bool affordable = balance >= offer.price;

    return ParticleExplosion(
      trigger: _sparkleId == offer.name,
      particleEmoji: '✨',
      particleCount: 16,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Panel3D(
          accent: currency,
          depth: 6,
          radius: 17,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Socket3D(
                size: 56,
                color: currency,
                child: Text(offer.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedGameText(offer.name.toUpperCase(), size: 16),
                    const SizedBox(height: 2),
                    Text(
                      offer.description,
                      style: GoogleFonts.oswald(color: Colors.white70, fontSize: 12),
                    ),
                    if (offer.valueNote != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '▲ ${offer.valueNote!}',
                        style: GoogleFonts.oswald(
                          color: const Color(0xFF7CFF6B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Si no alcanza el saldo, el botón sale gris: el jugador lo sabe
              // antes de pulsar en vez de enterarse por un mensaje de error.
              Pressable3D(
                slanted: true,
                onTap: _isBusy || !affordable ? null : () => _purchaseOffer(offer),
                color: currency,
                height: 40,
                depth: 5,
                radius: 8,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(offer.payWithGems ? '💎' : '🪙', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    OutlinedGameText('${offer.price}', size: 17),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // PESTAÑA PREMIOS (anuncios)
  // ---------------------------------------------------------------
  Widget _buildRewards() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _buildSectionHeading(
          'RECOMPENSAS POR ANUNCIO',
          'Mira un video opcional y recibe un recurso para tu próxima aventura.',
        ),
        EntranceFlip(
          index: 0,
          child: _buildRewardCard(
            emoji: '🧪',
            title: 'Poción de salud',
            description: 'Una poción extra, solo cuando el anuncio se complete.',
            rewardName: '1 poción de salud',
            onPressed: () => _watchAdForReward('1 poción de salud', () => profile.healthPotions++),
          ),
        ),
        EntranceFlip(
          index: 1,
          child: _buildRewardCard(
            emoji: '💡',
            title: 'Pista de sabiduría',
            description: 'Una pista extra para ayudarte en una pregunta.',
            rewardName: '1 pista',
            onPressed: () => _watchAdForReward('1 pista', () => profile.letterHints++),
          ),
        ),
        const SizedBox(height: 6),
        EntranceFlip(
          index: 2,
          child: Panel3D(
            accent: WM.violet,
            depth: 4,
            radius: 14,
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                const Socket3D(
                  size: 38,
                  color: WM.violet,
                  child: Icon(Icons.info_outline_rounded, color: WM.bone, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Los anuncios son opcionales. Si no hay uno disponible, no se descontará nada ni se entregará un premio.',
                    style: GoogleFonts.oswald(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardCard({
    required String emoji,
    required String title,
    required String description,
    required String rewardName,
    required VoidCallback onPressed,
  }) {
    final bool loading = _loadingAd == rewardName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel3D(
        accent: WM.gold,
        depth: 6,
        radius: 17,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Socket3D(
              size: 56,
              color: WM.gold,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedGameText(title.toUpperCase(), size: 16),
                  const SizedBox(height: 2),
                  Text(description, style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Pressable3D(
              slanted: true,
              onTap: _isBusy ? null : onPressed,
              color: WM.gold,
              height: 40,
              depth: 5,
              radius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: WM.outline),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 2),
                        OutlinedGameText('VIDEO', size: 14, font: GameFont.oswald),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
