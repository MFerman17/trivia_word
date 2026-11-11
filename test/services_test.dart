// Pruebas de la lógica de los servicios que no necesitan pantalla ni
// internet: edad, racha, torre y topes diarios de videos.
//
// Ejecutar con:  flutter test test/services_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:words_and_monsters/services/ad_service.dart';
import 'package:words_and_monsters/services/age_gate_service.dart';
import 'package:words_and_monsters/services/streak_service.dart';
import 'package:words_and_monsters/services/tower_service.dart';

String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pantalla de edad', () {
    final year = DateTime.now().year;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sin responder no se sabe la edad', () async {
      await AgeGateService.init();
      expect(AgeGateService.answered, isFalse);
    });

    test('menor de 13 es niño', () async {
      await AgeGateService.setBirthYear(year - 9);
      expect(AgeGateService.isChild, isTrue);
    });

    test('quien cumple 13 este año se trata como niño (prudencia)', () async {
      await AgeGateService.setBirthYear(year - 13);
      expect(AgeGateService.isChild, isTrue);
    });

    test('14 o más no es niño', () async {
      await AgeGateService.setBirthYear(year - 14);
      expect(AgeGateService.isChild, isFalse);
      await AgeGateService.setBirthYear(year - 40);
      expect(AgeGateService.isChild, isFalse);
    });

    test('la respuesta se recuerda al volver a abrir', () async {
      await AgeGateService.setBirthYear(year - 30);
      await AgeGateService.init();
      expect(AgeGateService.answered, isTrue);
      expect(AgeGateService.isChild, isFalse);
    });
  });

  group('Racha de 7 días', () {
    final now = DateTime.now();

    test('jugador nuevo: día 1, se puede reclamar', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await StreakService.status();
      expect((s.day, s.canClaim, s.lost), (1, true, false));
    });

    test('reclamó ayer el día 3: hoy toca el 4', () async {
      SharedPreferences.setMockInitialValues({
        'streak_day': 3,
        'streak_last': _day(now.subtract(const Duration(days: 1))),
      });
      final s = await StreakService.status();
      expect((s.day, s.canClaim), (4, true));
    });

    test('tras el día 7 vuelve al 1', () async {
      SharedPreferences.setMockInitialValues({
        'streak_day': 7,
        'streak_last': _day(now.subtract(const Duration(days: 1))),
      });
      expect((await StreakService.status()).day, 1);
    });

    test('ya reclamado hoy: no se puede otra vez', () async {
      SharedPreferences.setMockInitialValues({'streak_day': 2, 'streak_last': _day(now)});
      final s = await StreakService.status();
      expect((s.day, s.canClaim), (2, false));
    });

    test('se saltó un día: pierde la racha', () async {
      SharedPreferences.setMockInitialValues({
        'streak_day': 5,
        'streak_last': _day(now.subtract(const Duration(days: 3))),
      });
      final s = await StreakService.status();
      expect((s.day, s.lost), (1, true));
    });

    test('hay 7 premios y el último es el mayor en monedas', () {
      expect(StreakService.rewards.length, 7);
      final coins = StreakService.rewards.map((r) => r.coins);
      expect(StreakService.rewards.last.coins, coins.reduce((a, b) => a > b ? a : b));
    });
  });

  group('Torre infinita', () {
    test('la dificultad sube por tramos', () {
      expect([1, 5, 6, 10, 11, 20, 21, 35, 36, 200].map(TowerService.difficultyFor),
          [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]);
    });

    test('premios: monedas por piso y una gema cada 25', () {
      expect(TowerService.coinsFor(10), 50);
      expect(TowerService.gemsFor(24), 0);
      expect(TowerService.gemsFor(25), 1);
      expect(TowerService.gemsFor(60), 2);
    });
  });

  group('Topes diarios de videos', () {
    test('sin usar: quedan todos', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AdService.remainingToday('shop_potion', AdService.shopVideosPerDay), 5);
    });

    test('cuenta los de hoy y nunca baja de 0', () async {
      final n = DateTime.now();
      final key = 'adlimit_life_${n.year}-${n.month}-${n.day}';
      SharedPreferences.setMockInitialValues({key: 3});
      expect(await AdService.remainingToday('life', 5), 2);
      SharedPreferences.setMockInitialValues({key: 9});
      expect(await AdService.remainingToday('life', 5), 0);
    });

    test('los de ayer no cuentan', () async {
      final y = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({'adlimit_life_${y.year}-${y.month}-${y.day}': 5});
      expect(await AdService.remainingToday('life', 5), 5);
    });
  });
}
