import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';
import 'lives_service.dart';
import 'save_service.dart';
import 'streak_service.dart';

/// NOTIFICACIONES LOCALES
///
/// Avisos que programa el propio teléfono (no hace falta servidor ni
/// internet). Son pocos y útiles, para que el jugador no los desactive:
///  1. Vidas llenas: cuando terminan de recargarse.
///  2. Cofre diario listo: 24 h después de abrir el anterior.
///  3. Recordatorio diario (19:00): la racha y el reto del día esperan.
///
/// Cómo funciona: al salir del juego (pasa a segundo plano) se calculan y
/// programan; al volver, se cancelan (estando dentro no hacen falta). Así
/// siempre usan los datos más recientes.
///
/// Se programan como "inexactas": Android puede retrasarlas unos minutos
/// para ahorrar batería, pero no hace falta pedir el permiso especial de
/// alarmas exactas (Google Play lo restringe a relojes y calendarios).
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _enabledKey = 'notifications_enabled';
  static const _askedKey = 'notifications_asked';

  static bool enabled = true;

  static const int _idLives = 1;
  static const int _idChest = 2;
  static const int _idDaily = 3;

  /// Hora del recordatorio diario (hora del teléfono).
  static const int reminderHour = 19;

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'game_reminders',
    'Recordatorios del juego',
    channelDescription: 'Vidas llenas, cofre diario y racha',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_enabledKey) ?? true;
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          // El permiso se pide más tarde, en un buen momento (ver askPermission).
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notificaciones: no se pudieron preparar: $e');
    }
  }

  /// Pide permiso una sola vez (Android 13+ e iOS lo exigen). Se llama al
  /// llegar a la portada tras la bienvenida, no nada más abrir el juego.
  static Future<void> askPermissionOnce() async {
    if (!_ready || !enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;
      await prefs.setBool(_askedKey, true);
      await _requestPermission();
    } catch (e) {
      debugPrint('Notificaciones: no se pudo pedir permiso: $e');
    }
  }

  static Future<bool> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    return false;
  }

  /// Interruptor de Ajustes. Al activarlo se vuelve a pedir el permiso
  /// (por si el jugador lo rechazó la primera vez).
  static Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
    if (!_ready) return;
    if (value) {
      await _requestPermission();
    } else {
      await cancelAll();
    }
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Programa los avisos con los datos actuales. Se llama al salir del juego.
  static Future<void> scheduleAll() async {
    if (!_ready || !enabled) return;
    await cancelAll();
    final l = L10n.current;
    final now = DateTime.now();

    // 1. Vidas llenas.
    final full = LivesService.fullAt;
    if (full != null && full.isAfter(now)) {
      await _schedule(_idLives, full, l.notifLivesTitle, l.notifLivesBody);
    }

    // 2. Cofre diario.
    try {
      final profile = await SaveService.loadPlayerData();
      final last = profile.lastDailyReward;
      final ready = last?.add(const Duration(hours: 24));
      if (ready != null && ready.isAfter(now)) {
        await _schedule(_idChest, ready, l.notifChestTitle, l.notifChestBody);
      }
    } catch (_) {}

    // 3. Recordatorio diario: hoy a las 19:00 si aún no se reclamó la racha
    //    y no ha pasado la hora; si no, mañana a las 19:00.
    final streak = await StreakService.status();
    var at = DateTime(now.year, now.month, now.day, reminderHour);
    if (!streak.canClaim || !at.isAfter(now)) at = at.add(const Duration(days: 1));
    // Mañana el día de la racha será el siguiente al de hoy (si se reclamó).
    final nextDay = streak.canClaim ? streak.day : streak.day % StreakService.rewards.length + 1;
    await _schedule(_idDaily, at, l.notifDailyTitle, l.notifDailyBody(nextDay));
  }

  static Future<void> _schedule(int id, DateTime when, String title, String body) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Notificaciones: no se pudo programar $id: $e');
    }
  }

  /// Engancha la programación al ciclo de vida de la app.
  static void onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      scheduleAll();
    } else if (state == AppLifecycleState.resumed) {
      cancelAll();
    }
  }
}
