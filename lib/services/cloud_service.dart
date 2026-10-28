import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/player_profile.dart';
import 'save_service.dart';

enum GoogleAccountResult { linked, cancelled, failed }

class CloudService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _isSyncingSave = false;
  static bool _cloudSyncDisabledForSession = false;
  static bool _permissionDeniedLogged = false;
  static Future<void>? _googleInitialization;

  static bool get isGoogleAccountLinked =>
      _auth.currentUser?.providerData.any((info) => info.providerId == 'google.com') ?? false;

  static String? get currentAccountEmail => _auth.currentUser?.email;

  static void _handleCloudError(Object error, String operation) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      _cloudSyncDisabledForSession = true;
      if (!_permissionDeniedLogged) {
        _permissionDeniedLogged = true;
        debugPrint(
          '⚠️ Firebase negó el acceso. Se pausa la sincronización en la nube '
          'hasta reiniciar la app; el guardado local continúa. Revisa las reglas de Firestore.',
        );
      }
      return;
    }
    debugPrint('$operation: $error');
  }

  /// Mantiene una identidad local temporal para guardar el progreso desde
  /// la primera partida, antes de que el jugador vincule su cuenta Google.
  static Future<User?> signInAnonymously() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) return currentUser;
      final result = await _auth.signInAnonymously();
      debugPrint('Usuario conectado: ${result.user?.uid}');
      return result.user;
    } catch (e) {
      debugPrint('No se pudo iniciar sesión anónima: $e');
      return null;
    }
  }

  // =================================================================
  // BORRAR TODOS LOS DATOS (requisito de Google Play)
  // =================================================================

  /// Borra el avance del jugador en la nube (guardado y ranking), su cuenta
  /// de Firebase y los datos del teléfono. El juego vuelve a empezar desde
  /// cero. Se conservan solo el idioma y los ajustes de sonido.
  ///
  /// Devuelve false si no se pudo borrar lo de la nube (por ejemplo, sin
  /// internet): en ese caso NO se borra nada del teléfono, para que el
  /// jugador pueda intentarlo de nuevo sin quedarse con datos a medias.
  static Future<bool> deleteAllData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Las reglas de Firestore permiten a cada jugador borrar lo suyo.
        await _db.collection('leaderboard').doc(user.uid).delete();
        await _db.collection('player_saves').doc(user.uid).delete();
      } catch (e) {
        debugPrint('No se pudieron borrar los datos de la nube: $e');
        return false;
      }
      try {
        await user.delete(); // borra la cuenta (anónima o de Google) en Firebase
      } catch (e) {
        // Firebase puede pedir un inicio de sesión reciente para borrar una
        // cuenta de Google. Los datos ya están borrados: basta con cerrar sesión.
        debugPrint('No se pudo borrar la cuenta, se cierra la sesión: $e');
      }
      try {
        await _auth.signOut();
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await SaveService.clearLocalData();
    return true;
  }

  /// Descarga el guardado al abrir el juego. La copia local se conserva si
  /// Firebase no está disponible, y se combina para proteger progreso offline.
  static Future<void> restoreCloudSave() async {
    if (_cloudSyncDisabledForSession) return;
    try {
      final user = _auth.currentUser ?? await signInAnonymously();
      if (user == null) return;

      final localSave = await SaveService.exportCloudSave();
      final document = await _db.collection('player_saves').doc(user.uid).get();
      if (!document.exists || document.data() == null) {
        await _writeCloudSave(user.uid, localSave);
        return;
      }

      final remoteSave = Map<String, dynamic>.from(document.data()!);
      final mergedSave = _mergeSaves(localSave, remoteSave);
      await SaveService.importCloudSave(mergedSave);
      await _writeCloudSave(user.uid, mergedSave);
    } catch (e) {
      _handleCloudError(
        e,
        'No se pudo restaurar el guardado en la nube; se conserva el local',
      );
    }
  }

  /// Se llama tras cada guardado local. Si no hay conexión, SharedPreferences
  /// sigue siendo la copia de trabajo y la app intentará sincronizar al volver.
  static Future<void> syncFullSave() async {
    if (_cloudSyncDisabledForSession || _isSyncingSave) return;
    _isSyncingSave = true;
    try {
      final user = _auth.currentUser ?? await signInAnonymously();
      if (user == null) return;
      await _writeCloudSave(user.uid, await SaveService.exportCloudSave());
    } catch (e) {
      _handleCloudError(e, 'No se pudo sincronizar el progreso completo');
    } finally {
      _isSyncingSave = false;
    }
  }

  static Future<void> _writeCloudSave(String uid, Map<String, dynamic> save) async {
    if (_cloudSyncDisabledForSession) return;
    await _db.collection('player_saves').doc(uid).set({
      ...save,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Vincula el jugador anónimo a Google para conservar el mismo UID. Si esa
  /// cuenta ya existe, inicia sesión en ella y recupera su progreso guardado.
  static Future<GoogleAccountResult> connectGoogleAccount() async {
    try {
      final currentUser = _auth.currentUser ?? await signInAnonymously();
      if (currentUser == null) return GoogleAccountResult.failed;
      final localSave = await SaveService.exportCloudSave();

      UserCredential authResult;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        try {
          authResult = currentUser.isAnonymous
              ? await currentUser.linkWithPopup(provider)
              : await _auth.signInWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' && e.credential != null) {
            authResult = await _auth.signInWithCredential(e.credential!);
          } else {
            rethrow;
          }
        }
      } else {
        _googleInitialization ??= GoogleSignIn.instance.initialize();
        await _googleInitialization;
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) return GoogleAccountResult.failed;
        final credential = GoogleAuthProvider.credential(idToken: idToken);

        try {
          authResult = currentUser.isAnonymous
              ? await currentUser.linkWithCredential(credential)
              : await _auth.signInWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') {
            rethrow;
          }
          authResult = await _auth.signInWithCredential(credential);
        }
      }

      final user = authResult.user;
      if (user == null) return GoogleAccountResult.failed;
      _cloudSyncDisabledForSession = false;
      await _restoreAndMergeSaveForUser(user, localSave);
      return GoogleAccountResult.linked;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return GoogleAccountResult.cancelled;
      }
      debugPrint('Google/Firebase sign-in failed (${e.code}): ${e.message}');
      return GoogleAccountResult.failed;
    } on FirebaseException catch (e) {
      _handleCloudError(e, 'No se pudo restaurar el guardado tras iniciar sesión');
      return GoogleAccountResult.failed;
    } catch (e) {
      // google_sign_in throws a cancellation exception when the user closes
      // the account picker; it is intentionally treated as a harmless cancel.
      if (e.toString().toLowerCase().contains('cancel')) {
        return GoogleAccountResult.cancelled;
      }
      debugPrint('No se pudo vincular la cuenta Google: $e');
      return GoogleAccountResult.failed;
    }
  }

  static Future<void> _restoreAndMergeSaveForUser(
    User user,
    Map<String, dynamic> localSave,
  ) async {
    final remoteDoc = await _db.collection('player_saves').doc(user.uid).get();
    Map<String, dynamic> save = localSave;
    if (remoteDoc.exists && remoteDoc.data() != null) {
      final remoteSave = Map<String, dynamic>.from(remoteDoc.data()!);
      save = SaveService.hasMeaningfulProgress(localSave)
          ? _mergeSaves(localSave, remoteSave)
          : remoteSave;
    }
    await SaveService.importCloudSave(save);
    await _writeCloudSave(user.uid, save);
  }

  static Future<void> syncProfileToCloud(PlayerProfile profile) async {
    if (_cloudSyncDisabledForSession) return;
    try {
      final user = _auth.currentUser ?? await signInAnonymously();
      if (user == null) return;
      final save = await SaveService.exportCloudSave();
      final profileMap = Map<String, dynamic>.from(save['profile'] as Map);
      final requestedName = profile.name.trim();
      final nameToSend = requestedName.isNotEmpty
          ? requestedName
          : 'Jugador_${user.uid.substring(0, 5)}';
      // Limita por puntos de código para no cortar un carácter Unicode a la mitad.
      final playerName = String.fromCharCodes(nameToSend.runes.take(20));
      final totalStars = _totalStars(save['stages'] as Map? ?? {});

      await _db.collection('leaderboard').doc(user.uid).set({
        'name': playerName,
        'coins': profile.coins,
        'experience': profile.experience,
        'stars': totalStars,
        // País para la bandera del ranking (solo si el jugador lo eligió).
        if (profile.country.length == 2) 'country': profile.country,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      profileMap['name'] = playerName;
      profileMap['totalStars'] = totalStars;
      save['profile'] = profileMap;
      await _writeCloudSave(user.uid, save);
    } catch (e) {
      _handleCloudError(e, 'No se pudo sincronizar el ranking');
    }
  }

  static int _totalStars(Map<dynamic, dynamic> stages) {
    return stages.values.fold<int>(0, (total, value) {
      final stage = Map<String, dynamic>.from(value as Map);
      return total + ((stage['stars'] as num?)?.toInt() ?? 0);
    });
  }

  static Map<String, dynamic> _mergeSaves(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    if (!SaveService.hasMeaningfulProgress(local)) return remote;
    if (!SaveService.hasMeaningfulProgress(remote)) return local;

    final localStages = Map<String, dynamic>.from(local['stages'] as Map? ?? {});
    final remoteStages = Map<String, dynamic>.from(remote['stages'] as Map? ?? {});
    final stages = <String, dynamic>{...remoteStages};
    for (final entry in localStages.entries) {
      final localStage = Map<String, dynamic>.from(entry.value as Map);
      final remoteStage = Map<String, dynamic>.from(stages[entry.key] as Map? ?? {});
      stages[entry.key] = {
        ...remoteStage,
        ...localStage,
        'stars': _maxInt(localStage['stars'], remoteStage['stars']),
        'highScore': _maxInt(localStage['highScore'], remoteStage['highScore']),
        'isUnlocked': localStage['isUnlocked'] == true || remoteStage['isUnlocked'] == true,
      };
    }

    final localProfile = Map<String, dynamic>.from(local['profile'] as Map? ?? {});
    final remoteProfile = Map<String, dynamic>.from(remote['profile'] as Map? ?? {});
    final profile = <String, dynamic>{...localProfile, ...remoteProfile};
    for (final field in ['coins', 'gems', 'healthPotions', 'letterHints']) {
      profile[field] = _maxInt(localProfile[field], remoteProfile[field]);
    }
    final totalXp = _maxInt(_toTotalXp(localProfile), _toTotalXp(remoteProfile));
    profile.addAll(_fromTotalXp(totalXp));
    profile['totalStars'] = _totalStars(stages);

    for (final field in ['ownedAvatarCharacters', 'ownedAvatarFrames', 'ownedAvatarAccessories']) {
      profile[field] = {
        ...List<String>.from(localProfile[field] as List? ?? const []),
        ...List<String>.from(remoteProfile[field] as List? ?? const []),
      }.toList();
    }
    final localReward = DateTime.tryParse('${localProfile['lastDailyReward'] ?? ''}');
    final remoteReward = DateTime.tryParse('${remoteProfile['lastDailyReward'] ?? ''}');
    if (localReward != null && (remoteReward == null || localReward.isAfter(remoteReward))) {
      profile['lastDailyReward'] = localReward.toIso8601String();
    }

    final questsById = <String, Map<String, dynamic>>{};
    for (final item in [...(remote['quests'] as List? ?? []), ...(local['quests'] as List? ?? [])]) {
      final quest = Map<String, dynamic>.from(item as Map);
      final id = quest['id'] as String?;
      if (id == null) continue;
      final previous = questsById[id];
      if (previous == null) {
        questsById[id] = quest;
      } else {
        questsById[id] = {
          ...previous,
          ...quest,
          'currentAmount': _maxInt(previous['currentAmount'], quest['currentAmount']),
          'isClaimed': previous['isClaimed'] == true || quest['isClaimed'] == true,
        };
      }
    }

    final miniRewards = <String, dynamic>{
      ...Map<String, dynamic>.from(remote['miniRewards'] as Map? ?? {}),
      ...Map<String, dynamic>.from(local['miniRewards'] as Map? ?? {}),
    };

    return {
      'schemaVersion': 1,
      'profile': profile,
      'stages': stages,
      'quests': questsById.values.toList(),
      'miniRewards': miniRewards,
    };
  }

  static int _maxInt(dynamic first, dynamic second) {
    final a = (first as num?)?.toInt() ?? 0;
    final b = (second as num?)?.toInt() ?? 0;
    return a > b ? a : b;
  }

  static int _toTotalXp(Map<String, dynamic> profile) {
    final level = (profile['level'] as num?)?.toInt() ?? 1;
    var total = (profile['experience'] as num?)?.toInt() ?? 0;
    for (var currentLevel = 1; currentLevel < level; currentLevel++) {
      total += currentLevel * 100;
    }
    return total;
  }

  static Map<String, int> _fromTotalXp(int totalXp) {
    var level = 1;
    var remaining = totalXp;
    while (remaining >= level * 100) {
      remaining -= level * 100;
      level++;
    }
    return {'level': level, 'experience': remaining};
  }

  static Future<List<Map<String, dynamic>>> getGlobalLeaderboard() async {
    if (_cloudSyncDisabledForSession) return [];
    try {
      final snapshot = await _db.collection('leaderboard')
          .orderBy('stars', descending: true)
          .limit(20)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _handleCloudError(e, 'No se pudo cargar el ranking');
      return [];
    }
  }
}
