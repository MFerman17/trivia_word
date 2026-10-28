import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player_profile.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/fighter_service.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../widgets/game_3d.dart';
import '../widgets/particle_explosion.dart';
import '../widgets/player_avatar.dart';
import '../l10n/l10n.dart';

enum _CosmeticSlot { character, frame, accessory }

class _CosmeticOption {
  const _CosmeticOption({
    required this.id,
    required this.emoji,
    this.coins = 0,
    this.gems = 0,
  });

  final String id;
  final String emoji;
  final int coins;
  final int gems;
}

class _ShopOffer {
  const _ShopOffer({
    required this.id,
    required this.emoji,
    required this.price,
    required this.payWithGems,
    this.potions = 0,
    this.hints = 0,
    this.coins = 0,
  });

  /// Identificador: con él se busca el nombre traducido (ver _offerTexts).
  final String id;
  final String emoji;
  final int price;
  final bool payWithGems;
  final int potions;
  final int hints;
  final int coins;
}

const List<_CosmeticOption> _characters = [
  _CosmeticOption(id: 'explorador', emoji: '🧝'),
  _CosmeticOption(id: 'maga', emoji: '🧙‍♀️', gems: 5),
  _CosmeticOption(id: 'guardian', emoji: '🛡️', coins: 220),
];

const List<_CosmeticOption> _frames = [
  _CosmeticOption(id: 'basico', emoji: '🔹'),
  _CosmeticOption(id: 'bosque', emoji: '🌿', coins: 150),
  _CosmeticOption(id: 'magma', emoji: '🔥', gems: 6),
];

const List<_CosmeticOption> _accessories = [
  _CosmeticOption(id: 'ninguno', emoji: '—'),
  _CosmeticOption(id: 'brujula', emoji: '🧭', coins: 100),
  _CosmeticOption(id: 'dragoncito', emoji: '🐉', gems: 8),
];

const List<_ShopOffer> _offers = [
  _ShopOffer(
    id: 'explorerKit',
    emoji: '🧭',
    price: 180,
    payWithGems: false,
    potions: 1,
    hints: 2,
  ),
  _ShopOffer(
    id: 'expeditionKit',
    emoji: '🎒',
    price: 400,
    payWithGems: false,
    potions: 3,
    hints: 4,
  ),
  _ShopOffer(
    id: 'potionTrio',
    emoji: '🧪',
    price: 135,
    payWithGems: false,
    potions: 3,
  ),
  _ShopOffer(
    id: 'hintTrio',
    emoji: '💡',
    price: 5,
    payWithGems: true,
    hints: 3,
  ),
  _ShopOffer(
    id: 'goldBag',
    emoji: '💰',
    price: 12,
    payWithGems: true,
    coins: 550,
  ),
];

class ShopScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  /// Pestaña con la que se abre (0 = Avatar). La pelea abre directamente
  /// la de mejoras con [fighterTab] cuando el jugador pierde.
  final int initialTab;
  static const int fighterTab = 3;

  const ShopScreen({super.key, this.playerProfile, this.initialTab = 0});

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
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3).toInt(),
    );
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

  // ---------------------------------------------------------------
  // TEXTOS TRADUCIDOS de artículos, combos y mejoras (por su id)
  // ---------------------------------------------------------------
  String _cosmeticName(String id) {
    final l = context.l10n;
    return switch (id) {
      'explorador' => l.charExplorer,
      'maga' => l.charMage,
      'guardian' => l.charGuardian,
      'basico' => l.frameCyan,
      'bosque' => l.frameForest,
      'magma' => l.frameMagma,
      'ninguno' => l.accNone,
      'brujula' => l.accCompass,
      'dragoncito' => l.accDragon,
      _ => id,
    };
  }

  ({String name, String description, String note}) _offerTexts(_ShopOffer offer) {
    final l = context.l10n;
    return switch (offer.id) {
      'explorerKit' => (
          name: l.offerExplorerKit,
          description: l.offerExplorerKitDesc,
          note: l.offerExplorerKitNote,
        ),
      'expeditionKit' => (
          name: l.offerExpeditionKit,
          description: l.offerExpeditionKitDesc,
          note: l.offerExpeditionKitNote,
        ),
      'potionTrio' => (
          name: l.offerPotionTrio,
          description: l.offerPotionTrioDesc,
          note: l.offerPotionTrioNote,
        ),
      'hintTrio' => (
          name: l.offerHintTrio,
          description: l.offerHintTrioDesc,
          note: l.offerHintTrioNote,
        ),
      _ => (
          name: l.offerGoldBag,
          description: l.offerGoldBagDesc,
          note: l.offerGoldBagNote,
        ),
    };
  }

  ({String title, String description}) _upgradeTexts(FighterUpgrade upgrade) {
    final l = context.l10n;
    return switch (upgrade) {
      FighterUpgrade.health => (title: l.upgradeHealth, description: l.upgradeHealthDesc),
      FighterUpgrade.power => (title: l.upgradePower, description: l.upgradePowerDesc),
      FighterUpgrade.superCharge => (title: l.upgradeSuper, description: l.upgradeSuperDesc),
    };
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
      _showMessage(context.l10n.notEnoughCurrency, error: true);
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
      _showMessage(isOwned ? context.l10n.lookEquipped : context.l10n.lookUnlocked);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _sparkleId = null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profile = PlayerProfile.fromJson(previousProfile);
        _isBusy = false;
      });
      _showMessage(context.l10n.lookSaveFailed, error: true);
    }
  }

  Future<void> _purchaseOffer(_ShopOffer offer) async {
    if (_isBusy) return;
    final balance = offer.payWithGems ? profile.gems : profile.coins;
    if (balance < offer.price) {
      _showMessage(
        offer.payWithGems ? context.l10n.notEnoughGems : context.l10n.notEnoughCoins,
        error: true,
      );
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
      QuestService.track(QuestEvent.shopPurchase);
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _sparkleId = offer.id;
      });
      AudioService.playBuyItem();
      _showMessage(context.l10n.offerAdded(_offerTexts(offer).name));
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _sparkleId = null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profile = PlayerProfile.fromJson(previousProfile);
        _isBusy = false;
      });
      _showMessage(context.l10n.purchaseFailed, error: true);
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
        if (mounted) _showMessage(context.l10n.rewardReceived(rewardName));
      } else {
        _showMessage(context.l10n.noAdsNow, error: true);
      }
    } catch (_) {
      if (!mounted) return;
      profile = PlayerProfile.fromJson(previousProfile);
      _showMessage(context.l10n.rewardSaveFailed, error: true);
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
                title: context.l10n.shopTitle,
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
                    _buildFighter(),
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
            Expanded(child: _buildBalanceBadge('🪙', context.l10n.coinsLabel, profile.coins, WM.gold)),
            Container(
              height: 34,
              width: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: WM.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: _buildBalanceBadge('💎', context.l10n.gemsLabel, profile.gems, WM.cyan)),
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
    final labels = [
      context.l10n.shopTabAvatar,
      context.l10n.shopTabCombos,
      context.l10n.shopTabRewards,
      context.l10n.shopTabFighter,
    ];
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: OutlinedGameText(labels[i], size: 14, font: GameFont.oswald),
                  ),
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
      _CosmeticSlot.character => context.l10n.slotCharacter,
      _CosmeticSlot.frame => context.l10n.slotFrame,
      _CosmeticSlot.accessory => context.l10n.slotAccessory,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        EntranceFlip(index: 0, child: _buildAvatarPreview()),
        const SizedBox(height: 18),
        EntranceFlip(
          index: 1,
          child: _buildCosmeticSelector(context.l10n.slotCharacter, _CosmeticSlot.character, _characters),
        ),
        EntranceFlip(
          index: 2,
          child: _buildCosmeticSelector(context.l10n.slotFrame, _CosmeticSlot.frame, _frames),
        ),
        EntranceFlip(
          index: 3,
          child: _buildCosmeticSelector(context.l10n.slotAccessory, _CosmeticSlot.accessory, _accessories),
        ),
        const SizedBox(height: 4),
        // Deja claro sobre qué pieza actúa el botón
        Center(
          child: Text(
            context.l10n.shopSelected(slotName, _cosmeticName(option.id)),
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
                      ? context.l10n.equipped
                      : owned
                          ? context.l10n.equip
                          : _isFree(option)
                              ? context.l10n.unlockFree
                              : context.l10n.unlock,
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
          OutlinedGameText(context.l10n.heroWorkshop, size: 20, letterSpacing: 1.5),
          const SizedBox(height: 4),
          Text(
            context.l10n.heroWorkshopHint,
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
            context.l10n.equipped,
            style: GoogleFonts.anton(color: WM.green, fontSize: 11, letterSpacing: 1),
          )
        : isOwned
            ? Text(
                context.l10n.owned,
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
                _cosmeticName(item.id),
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
          context.l10n.combosTitle,
          context.l10n.combosSubtitle,
        ),
        for (var i = 0; i < _offers.length; i++)
          EntranceFlip(index: i, child: _buildOfferCard(_offers[i])),
        const SizedBox(height: 6),
        Text(
          context.l10n.valueReference,
          textAlign: TextAlign.center,
          style: GoogleFonts.oswald(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // PESTAÑA LUCHADOR: mejoras para las peleas
  // ---------------------------------------------------------------
  Widget _buildFighter() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _buildSectionHeading(
          context.l10n.fighterTitle,
          context.l10n.fighterSubtitle,
        ),
        for (var i = 0; i < FighterUpgrade.values.length; i++)
          EntranceFlip(index: i, child: _buildUpgradeCard(FighterUpgrade.values[i])),
        const SizedBox(height: 6),
        Text(
          context.l10n.fighterStats(
            FighterService.playerMaxHp(profile),
            FighterService.powerMultiplier(profile).toStringAsFixed(1),
            (1 / FighterService.superFillPerHit(profile)).ceil(),
          ),
          textAlign: TextAlign.center,
          style: GoogleFonts.oswald(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildUpgradeCard(FighterUpgrade upgrade) {
    final level = FighterService.levelOf(profile, upgrade);
    final cost = FighterService.nextCost(profile, upgrade);
    final maxed = cost == null;
    final affordable = cost != null && profile.coins >= cost;
    final accent = switch (upgrade) {
      FighterUpgrade.health => const Color(0xFFFF4D5E),
      FighterUpgrade.power => const Color(0xFFFF9D00),
      FighterUpgrade.superCharge => const Color(0xFF00B8FF),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel3D(
        accent: accent,
        glow: affordable ? 0.4 : 0,
        child: Row(
          children: [
            Socket3D(
              size: 54,
              color: accent,
              child: Text(upgrade.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedGameText(_upgradeTexts(upgrade).title, size: 18, font: GameFont.oswald),
                  Text(
                    _upgradeTexts(upgrade).description,
                    style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  // Nivel actual en bloques (como las barras de un RPG).
                  Row(
                    children: [
                      for (var i = 0; i < FighterService.maxUpgradeLevel; i++)
                        Container(
                          width: 18,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i < level ? accent : WM.outline,
                            border: Border.all(color: WM.outline, width: 1.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Pressable3D(
                onTap: affordable && !_isBusy ? () => _buyUpgrade(upgrade) : null,
                color: WM.gold,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: maxed
                    ? OutlinedGameText(context.l10n.maxLevel, size: 15, font: GameFont.oswald)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: OutlinedGameText('$cost', size: 15, font: GameFont.oswald),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buyUpgrade(FighterUpgrade upgrade) async {
    setState(() => _isBusy = true);
    final ok = await FighterService.buy(profile, upgrade);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (ok) {
      AudioService.playEquip();
      QuestService.track(QuestEvent.upgradeBought);
      _showMessage(context.l10n.upgradeDone(
        _upgradeTexts(upgrade).title,
        FighterService.levelOf(profile, upgrade),
      ));
    } else {
      _showMessage(context.l10n.notEnoughCoins, error: true);
    }
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
      trigger: _sparkleId == offer.id,
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
                    OutlinedGameText(_offerTexts(offer).name.toUpperCase(), size: 16),
                    const SizedBox(height: 2),
                    Text(
                      _offerTexts(offer).description,
                      style: GoogleFonts.oswald(color: Colors.white70, fontSize: 12),
                    ),
                    ...[
                      const SizedBox(height: 3),
                      Text(
                        '▲ ${_offerTexts(offer).note}',
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
          context.l10n.adRewardsTitle,
          context.l10n.adRewardsSubtitle,
        ),
        EntranceFlip(
          index: 0,
          child: _buildRewardCard(
            emoji: '🧪',
            title: context.l10n.adPotionTitle,
            description: context.l10n.adPotionDesc,
            rewardName: context.l10n.adPotionReward,
            onPressed: () =>
                _watchAdForReward(context.l10n.adPotionReward, () => profile.healthPotions++),
          ),
        ),
        EntranceFlip(
          index: 1,
          child: _buildRewardCard(
            emoji: '💡',
            title: context.l10n.adHintTitle,
            description: context.l10n.adHintDesc,
            rewardName: context.l10n.adHintReward,
            onPressed: () =>
                _watchAdForReward(context.l10n.adHintReward, () => profile.letterHints++),
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
                    context.l10n.adsOptionalNote,
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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 2),
                        OutlinedGameText(context.l10n.videoLabel, size: 14, font: GameFont.oswald),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
