import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../widgets/particle_explosion.dart';

// Colores coherentes con el estilo del juego
const Color kOutline = Color(0xFF0D0326);
const Color kCyan = Color(0xFF1EE3CF);
const Color kBone = Color(0xFFF4EBDD);

class ShopScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  const ShopScreen({super.key, this.playerProfile});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late PlayerProfile profile;
  bool _triggerSparkle = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Cargamos el perfil recibido o uno por defecto
    profile = widget.playerProfile ??
        PlayerProfile(
          name: 'Jugador 1',
          level: 1,
          experience: 0,
          coins: 150,
          gems: 10,
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Lógica central para realizar las compras
  void _buyItem({
    required int cost,
    required bool isGem,
    required String title,
    required VoidCallback onSuccess,
  }) async {
    final currentBalance = isGem ? profile.gems : profile.coins;
    final currencyName = isGem ? 'gemas' : 'monedas';

    if (currentBalance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ No tienes suficientes $currencyName para $title',
            style: GoogleFonts.oswald(fontSize: 14),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (isGem) {
        profile.gems -= cost;
      } else {
        profile.coins -= cost;
      }
      onSuccess();
    });
    _onPurchaseSuccess();
    QuestService.incrementProgress('buy_shop_item_1');

    // Guardar automáticamente tras modificar el saldo o los recursos
    await SaveService.savePlayerData(profile);

    // 🔊 AUDIO REPRODUCIDO TRAS UNA COMPRA EXITOSA
    AudioService.playBuyItem();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 ¡Compraste $title con éxito!',
            style: GoogleFonts.oswald(fontSize: 14, color: kOutline),
          ),
          backgroundColor: kCyan,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Simulación de compra o reclamación mediante Anuncio (Ad)
  void _watchAdForItem(String itemName, VoidCallback onReward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D36),
        title: Text('VER ANUNCIO', style: GoogleFonts.anton(color: kCyan)),
        content: Text(
          '¿Deseas ver un breve video publicitario para reclamar "$itemName" gratis?',
          style: GoogleFonts.oswald(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.oswald(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kCyan),
            onPressed: () {
              Navigator.pop(context);
              AudioService.playButtonClick();
              setState(() {
                onReward();
              });
              _onPurchaseSuccess();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('¡Has obtenido $itemName con éxito! 🌟',
                      style: GoogleFonts.oswald(color: kOutline)),
                  backgroundColor: kCyan,
                ),
              );
            },
            child: Text('Ver Video',
                style: GoogleFonts.anton(color: kOutline, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _onPurchaseSuccess() {
    setState(() {
      _triggerSparkle = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _triggerSparkle = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOutline,
      appBar: AppBar(
        backgroundColor: kOutline.withValues(alpha: 0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 22),
          onPressed: () {
            AudioService.playButtonClick();
            Navigator.pop(context, profile);
          },
        ),
        title: Text(
          'TIENDA ÉPICA',
          style: GoogleFonts.anton(
            color: kCyan,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kCyan,
          labelColor: kCyan,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'VIDAS Y SALUD'),
            Tab(text: 'COMODINES'),
            Tab(text: 'ORO Y GEMAS'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C20), Color(0xFF1F1D36), Color(0xFF261C4C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. RESUMEN DE SALDO (MONEDAS Y GEMAS)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kCyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBalanceBadge(
                      icon: '🪙',
                      label: 'Monedas',
                      amount: profile.coins,
                      color: Colors.amber,
                    ),
                    Container(height: 30, width: 1, color: Colors.white24),
                    _buildBalanceBadge(
                      icon: '💎',
                      label: 'Gemas',
                      amount: profile.gems,
                      color: kCyan,
                    ),
                  ],
                ),
              ),

              // 2. CONTENIDO DE PESTAÑAS (TabBarView)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pestaña 1: Vidas y Salud
                    ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildShopCategoryHeader('SUPERVIVENCIA Y ENERGÍA'),
                        _buildShopItemCard(
                          iconEmoji: '🧪',
                          title: 'Poción de Salud',
                          description: 'Restaura 1 punto de vida durante la partida.',
                          ownedCount: profile.healthPotions,
                          priceText: '50',
                          isGem: false,
                          accentColor: Colors.greenAccent,
                          onBuy: () => _buyItem(
                            cost: 50,
                            isGem: false,
                            title: 'Poción de Salud',
                            onSuccess: () => profile.healthPotions++,
                          ),
                        ),
                        _buildShopItemCard(
                          iconEmoji: '❤',
                          title: 'Recarga de Corazones (Ad)',
                          description: 'Rellena tu vida viendo un corto video.',
                          ownedCount: null,
                          priceText: 'Ver Ad',
                          isGem: false,
                          isAdButton: true,
                          accentColor: kCyan,
                          onBuy: () => _watchAdForItem('Recarga de Corazones', () {
                            // Acción al ver el ad (ej. restaurar vidas)
                          }),
                        ),
                      ],
                    ),

                    // Pestaña 2: Comodines (Palabras, Matemáticas, Trivia)
                    ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildShopCategoryHeader('COMODINES Y SABIDURÍA'),
                        _buildShopItemCard(
                          iconEmoji: '💡',
                          title: 'Pista de Letra / Acertijo',
                          description: 'Descarta opciones o revela pistas clave.',
                          ownedCount: profile.letterHints,
                          priceText: '2',
                          isGem: true,
                          accentColor: Colors.orangeAccent,
                          onBuy: () => _buyItem(
                            cost: 2,
                            isGem: true,
                            title: 'Pista de Letra',
                            onSuccess: () => profile.letterHints++,
                          ),
                        ),
                        _buildShopItemCard(
                          iconEmoji: '🔍',
                          title: 'Lupa de Sabiduría (Ad)',
                          description: 'Consigue una pista gratis viendo un anuncio.',
                          ownedCount: profile.letterHints,
                          priceText: 'Ver Ad',
                          isGem: false,
                          isAdButton: true,
                          accentColor: kCyan,
                          onBuy: () => _watchAdForItem('Lupa de Sabiduría', () {
                            profile.letterHints++;
                          }),
                        ),
                      ],
                    ),

                    // Pestaña 3: Oro y Gemas
                    ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildShopCategoryHeader('RECURSOS Y ECONOMÍA'),
                        _buildShopItemCard(
                          iconEmoji: '💰',
                          title: 'Bolsa de Monedas',
                          description: 'Obtén 200 monedas de oro para tus compras.',
                          ownedCount: null,
                          priceText: '5',
                          isGem: true,
                          accentColor: Colors.amber,
                          onBuy: () => _buyItem(
                            cost: 5,
                            isGem: true,
                            title: 'Bolsa de Monedas',
                            onSuccess: () => profile.coins += 200,
                          ),
                        ),
                        _buildShopItemCard(
                          iconEmoji: '🎁',
                          title: 'Cofre Diario Gratuito',
                          description: 'Reclama recompensas sorpresa viendo un anuncio.',
                          ownedCount: null,
                          priceText: 'Gratis',
                          isGem: false,
                          isAdButton: true,
                          accentColor: Colors.purpleAccent,
                          onBuy: () => _watchAdForItem('Cofre Diario', () {
                            profile.coins += 100;
                            profile.gems += 5;
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildBalanceBadge({
    required String icon,
    required String label,
    required int amount,
    required Color color,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.oswald(color: Colors.white60, fontSize: 11),
            ),
            Text(
              '$amount',
              style: GoogleFonts.anton(
                color: color,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShopCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: GoogleFonts.oswald(
          color: kCyan,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildShopItemCard({
    required String iconEmoji,
    required String title,
    required String description,
    required int? ownedCount,
    required String priceText,
    required bool isGem,
    bool isAdButton = false,
    required Color accentColor,
    required VoidCallback onBuy,
  }) {
    return ParticleExplosion(
      trigger: _triggerSparkle,
      particleEmoji: '✨',
      particleCount: 25,
      type: ExplosionType.burst,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            // Ícono del item
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(iconEmoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 12),

            // Detalles e Inventario
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.anton(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.oswald(color: Colors.white60, fontSize: 12),
                  ),
                  if (ownedCount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'En propiedad: $ownedCount',
                      style: GoogleFonts.oswald(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Botón de compra o anuncio
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdButton ? kCyan : accentColor.withValues(alpha: 0.2),
                foregroundColor: isAdButton ? kOutline : accentColor,
                side: BorderSide(color: isAdButton ? kCyan : accentColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: onBuy,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    priceText,
                    style: GoogleFonts.anton(
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (!isAdButton) ...[
                    const SizedBox(width: 4),
                    Text(
                      isGem ? '💎' : '🪙',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}