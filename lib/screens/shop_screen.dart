import 'package:flutter/material.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../widgets/particle_explosion.dart';

class ShopScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  const ShopScreen({super.key, this.playerProfile});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late PlayerProfile profile;
  bool _triggerSparkle = false;

  @override
  void initState() {
    super.initState();
    // Cargamos el perfil recibido o uno por defecto
    profile =
        widget.playerProfile ??
        PlayerProfile(
          name: 'Jugador 1',
          level: 1,
          experience: 0,
          coins: 150,
          gems: 10,
        );
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
          content: Text('❌ No tienes suficientes $currencyName para $title'),
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
    await SaveService.savePlayerData(
      profile,
    ); // o SaveService.loadPlayerData() según corresponda

    // 🔊 AUDIO REPRODUCIDO TRAS UNA COMPRA EXITOSA (LÍNEA 58)
    AudioService.playBuyItem();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 ¡Compraste $title con éxito!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
      body: Container(
        width: double.infinity,
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
              // 1. ENCABEZADO Y REGRESO
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        AudioService.playButtonClick();
                        Navigator.pop(context, profile);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Tienda de Mejoras',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                    ), // Espaciador para centrar el título
                  ],
                ),
              ),

              // 2. RESUMEN DE SALDO (MONEDAS Y GEMAS)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
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
                      color: Colors.cyanAccent,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 3. LISTA DE ARTÍCULOS EN LA TIENDA
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  children: [
                    _buildShopCategoryHeader('POTENCIADORES Y PISTAS'),

                    _buildShopItemCard(
                      iconEmoji: '🧪',
                      title: 'Poción de Salud',
                      description:
                          'Restaura 1 punto de vida durante la partida.',
                      ownedCount: profile.healthPotions,
                      price: 50,
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
                      iconEmoji: '💡',
                      title: 'Pista de Letra',
                      description:
                          'Descarta 2 opciones incorrectas en la pregunta.',
                      ownedCount: profile.letterHints,
                      price: 2,
                      isGem: true,
                      accentColor: Colors.orangeAccent,
                      onBuy: () => _buyItem(
                        cost: 2,
                        isGem: true,
                        title: 'Pista de Letra',
                        onSuccess: () => profile.letterHints++,
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildShopCategoryHeader('RECURSOS RÁPIDOS'),

                    _buildShopItemCard(
                      iconEmoji: '🪙',
                      title: 'Bolsa de Monedas',
                      description:
                          'Obtén 200 monedas de oro para tus compras básicas.',
                      ownedCount: null, // No aplica
                      price: 5,
                      isGem: true,
                      accentColor: Colors.amber,
                      onBuy: () => _buyItem(
                        cost: 5,
                        isGem: true,
                        title: 'Bolsa de Monedas',
                        onSuccess: () => profile.coins += 200,
                      ),
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
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            Text(
              '$amount',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 12,
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
    required int price,
    required bool isGem,
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
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  if (ownedCount != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'En propiedad: $ownedCount',
                      style: TextStyle(
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

            // Botón de compra
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor.withValues(alpha: 0.2),
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onPressed: onBuy,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$price',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isGem ? '💎' : '🪙',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
