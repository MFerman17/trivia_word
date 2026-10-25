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
}
