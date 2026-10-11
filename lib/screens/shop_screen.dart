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

const Color kOutline = Color(0xFF0D0326);
const Color kCyan = Color(0xFF1EE3CF);
const Color kBone = Color(0xFFF4EBDD);

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
  bool _triggerSparkle = false;

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
          backgroundColor: error ? Colors.redAccent : kCyan,
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
      setState(() {
        _isBusy = false;
        _triggerSparkle = true;
      });
      _showMessage(isOwned ? '¡Nuevo aspecto equipado!' : '¡Aspecto desbloqueado y equipado!');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _triggerSparkle = false);
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
        _triggerSparkle = true;
      });
      AudioService.playBuyItem();
      _showMessage('¡${offer.name} añadido a tu inventario!');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _triggerSparkle = false);
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
    setState(() => _isBusy = true);
    final previousProfile = profile.toJson();
    try {
      final earned = await AdService.showRewardedAd();
      if (!mounted) return;

      if (earned) {
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
      if (mounted) setState(() => _isBusy = false);
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
              _buildShopHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: WM.gold,
                  indicatorWeight: 3,
                  labelColor: WM.gold,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: const [
                    Tab(text: 'AVATAR'),
                    Tab(text: 'COMBOS'),
                    Tab(text: 'RECOMPENSAS'),
                  ],
                ),
              ),
              _buildBalanceBanner(),
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

  Widget _buildShopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Pressable3D(
            onTap: () {
              AudioService.playButtonClick();
              Navigator.pop(context, profile);
            },
            color: const Color(0xFF3A2A7A),
            height: 40,
            depth: 5,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: const Icon(Icons.arrow_back_rounded, color: WM.bone, size: 24),
          ),
          const Expanded(
            child: Center(
              child: OutlinedGameText(
                'TIENDA',
                size: 26,
                letterSpacing: 2,
                colors: [WM.cyanLight, WM.cyan],
              ),
            ),
          ),
          const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildBalanceBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Panel3D(
        accent: WM.gold,
        depth: 4,
        radius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBalanceBadge('🪙', 'Monedas', profile.coins, WM.gold),
            Container(height: 30, width: 1, color: Colors.white24),
            _buildBalanceBadge('💎', 'Gemas', profile.gems, WM.cyan),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceBadge(String icon, String label, int amount, Color color) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.oswald(color: Colors.white60, fontSize: 11)),
            Text('$amount', style: GoogleFonts.anton(color: color, fontSize: 18)),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarStudio() {
    final option = _optionsFor(_activeSlot).firstWhere(
      (item) => item.id == _previewFor(_activeSlot),
    );
    final owned = _ownedFor(_activeSlot).contains(option.id);
    final equipped = _equippedFor(_activeSlot) == option.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Panel3D(
          accent: WM.cyan,
          glow: 0.25,
          radius: 22,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              PlayerAvatar(
                profile: PlayerProfile(
                  avatarCharacterId: _previewCharacter,
                  avatarFrameId: _previewFrame,
                  avatarAccessoryId: _previewAccessory,
                ),
                radius: 44,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OutlinedGameText('TALLER DE HÉROES', size: 17, letterSpacing: 1),
                    const SizedBox(height: 5),
                    Text('Combina personaje, marco y accesorio. Tu avatar no cambia tus estadísticas.',
                        style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCosmeticSelector('PERSONAJE', _CosmeticSlot.character, _characters),
        _buildCosmeticSelector('MARCO', _CosmeticSlot.frame, _frames),
        _buildCosmeticSelector('ACCESORIO', _CosmeticSlot.accessory, _accessories),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _isBusy || equipped ? null : _unlockOrEquipPreview,
          style: ElevatedButton.styleFrom(
            backgroundColor: kCyan,
            foregroundColor: kOutline,
            disabledBackgroundColor: Colors.white12,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(owned ? Icons.check_circle_outline : Icons.lock_open_rounded),
          label: Text(
            equipped
                ? 'EQUIPADO'
                : owned
                    ? 'EQUIPAR'
                    : _priceLabel(option),
            style: GoogleFonts.anton(fontSize: 16, letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCosmeticSelector(
    String title,
    _CosmeticSlot slot,
    List<_CosmeticOption> options,
  ) {
    final selectedId = _previewFor(slot);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.oswald(color: kCyan, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: options.map((item) {
              final selected = selectedId == item.id;
              final isOwned = _ownedFor(slot).contains(item.id);
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => _selectCosmetic(slot, item.id),
                selectedColor: kCyan.withValues(alpha: 0.2),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(color: selected ? kCyan : Colors.white24),
                avatar: _activeSlot == _CosmeticSlot.character
                    ? PlayerAvatar(
                        profile: PlayerProfile(
                          avatarCharacterId: item.id,
                          avatarFrameId: _previewFrame,
                          avatarAccessoryId: _previewAccessory,
                        ),
                        radius: 13,
                      )
                    : Text(item.emoji, style: const TextStyle(fontSize: 16)),
                label: Text(
                  '${item.name}${isOwned ? '' : ' · ${_priceLabel(item)}'}',
                  style: GoogleFonts.oswald(color: selected ? kBone : Colors.white70, fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _priceLabel(_CosmeticOption option) {
    if (option.coins > 0) return '🪙 ${option.coins}';
    if (option.gems > 0) return '💎 ${option.gems}';
    return 'Gratis';
  }

  Widget _buildCombos() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildSectionHeading('EQUÍPATE PARA LA AVENTURA', 'Combos con descuento frente a comprar cada artículo por separado.'),
        _buildOfferCard(_offers[0]),
        _buildOfferCard(_offers[1]),
        _buildOfferCard(_offers[2]),
        _buildOfferCard(_offers[3]),
        _buildOfferCard(_offers[4]),
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
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
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
    return ParticleExplosion(
      trigger: _triggerSparkle,
      particleEmoji: '✨',
      particleCount: 16,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Panel3D(
          accent: WM.cyan,
          depth: 5,
          radius: 17,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Socket3D(
                size: 52,
                color: offer.payWithGems ? WM.cyan : WM.gold,
                child: Text(offer.emoji, style: const TextStyle(fontSize: 25)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedGameText(offer.name.toUpperCase(), size: 15, font: GameFont.anton),
                    Text(offer.description, style: GoogleFonts.oswald(color: Colors.white70, fontSize: 12)),
                    if (offer.valueNote != null)
                      Text(offer.valueNote!, style: GoogleFonts.oswald(color: WM.green, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pressable3D(
                onTap: _isBusy ? null : () => _purchaseOffer(offer),
                color: WM.cyan,
                height: 38,
                depth: 4,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${offer.price}', style: GoogleFonts.anton(color: WM.outline, fontSize: 14)),
                    Text(offer.payWithGems ? '💎' : '🪙', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewards() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildSectionHeading('RECOMPENSAS POR ANUNCIO', 'Mira un video opcional y recibe un recurso para tu próxima aventura.'),
        _buildRewardCard(
          emoji: '🧪',
          title: 'Poción de salud',
          description: 'Una poción extra, solo cuando el anuncio se complete.',
          onPressed: () => _watchAdForReward('1 poción de salud', () => profile.healthPotions++),
        ),
        _buildRewardCard(
          emoji: '💡',
          title: 'Pista de sabiduría',
          description: 'Una pista extra para ayudarte en una pregunta.',
          onPressed: () => _watchAdForReward('1 pista', () => profile.letterHints++),
        ),
        const SizedBox(height: 10),
        Panel3D(
          accent: WM.gold,
          depth: 4,
          radius: 14,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              const Socket3D(
                size: 38,
                color: WM.gold,
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
      ],
    );
  }

  Widget _buildRewardCard({
    required String emoji,
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel3D(
        accent: WM.gold,
        depth: 5,
        radius: 17,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Socket3D(
              size: 54,
              color: WM.gold,
              child: Text(emoji, style: const TextStyle(fontSize: 27)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedGameText(title.toUpperCase(), size: 15),
                  Text(description, style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Pressable3D(
              onTap: _isBusy ? null : onPressed,
              color: WM.gold,
              height: 38,
              depth: 4,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _isBusy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('VER VIDEO', style: GoogleFonts.anton(color: WM.outline, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
