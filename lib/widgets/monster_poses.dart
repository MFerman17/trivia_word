/// Poses de los monstruos para las peleas y el combate.
///
/// Cada monstruo puede tener 5 poses en assets/images/monsters/, con el
/// nombre de su imagen normal + la pose. Por ejemplo, para
/// assets/images/mini_forest_guardian.png:
///   monsters/mini_forest_guardian_idle.png   (quieto)
///   monsters/mini_forest_guardian_attack.png (ataca)
///   monsters/mini_forest_guardian_hit.png    (recibe el golpe)
///   monsters/mini_forest_guardian_win.png    (gana)
///   monsters/mini_forest_guardian_lose.png   (pierde)
/// Si falta una pose, se usa la imagen normal del monstruo.
class MonsterPoses {
  MonsterPoses._();

  static const List<String> poses = ['idle', 'attack', 'hit', 'win', 'lose'];

  static String assetFor(String enemyAsset, String pose) {
    final file = enemyAsset.split('/').last.replaceAll('.png', '');
    return 'assets/images/monsters/${file}_$pose.png';
  }

  /// Nivel de daño según la vida que le queda: 0 = sano, 1 = algo golpeado
  /// (por debajo del 66 %), 2 = muy golpeado (por debajo del 33 %).
  static int damageLevel(int hp, int maxHp) {
    if (maxHp <= 0) return 0;
    final ratio = hp / maxHp;
    return ratio <= 0.33 ? 2 : ratio <= 0.66 ? 1 : 0;
  }

  /// Pose "quieto" con moretones: monsters/NOMBRE_idle_hurt1.png y
  /// NOMBRE_idle_hurt2.png. Para el resto de poses, o sin daño, la normal.
  static String assetWithDamage(String enemyAsset, String pose, int damage) {
    if (pose != 'idle' || damage <= 0) return assetFor(enemyAsset, pose);
    final file = enemyAsset.split('/').last.replaceAll('.png', '');
    return 'assets/images/monsters/${file}_idle_hurt$damage.png';
  }
}
