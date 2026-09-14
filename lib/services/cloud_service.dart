import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/player_profile.dart';
import 'save_service.dart'; // 👈 Importamos SaveService para contar las estrellas

class CloudService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 1. Login Anónimo (Crea una cuenta invisible temporal para el jugador)
  static Future<User?> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      debugPrint("✅ Usuario conectado: ${userCredential.user?.uid}");
      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Error en login anónimo: $e");
      return null;
    }
  }

  /// 2. Sincronizar los datos del jugador a la nube
  static Future<void> syncProfileToCloud(PlayerProfile profile) async {
    try {
      User? user = _auth.currentUser ?? await signInAnonymously();
      if (user == null) return;

      // 👈 SOLUCIÓN: Calculamos las estrellas reales desde las fases completadas
      int totalStars = await SaveService.getTotalStarsObtained();

      // Generamos un nombre por defecto si el perfil no tiene uno
      String playerName = profile.name.isNotEmpty 
          ? profile.name 
          : 'Jugador_${user.uid.substring(0, 5)}';

      // Guardamos/Actualizamos el documento en Firestore
      await _db.collection('leaderboard').doc(user.uid).set({
        'name': playerName,
        'coins': profile.coins,
        'experience': profile.experience,
        'stars': totalStars, // 👈 Enviamos el total calculado
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint("☁️ Datos sincronizados con éxito en la nube.");
    } catch (e) {
      debugPrint("❌ Error al sincronizar con la nube: $e");
    }
  }

  /// 3. Obtener el Ranking Global (Top 20 jugadores)
  static Future<List<Map<String, dynamic>>> getGlobalLeaderboard() async {
    try {
      QuerySnapshot snapshot = await _db.collection('leaderboard')
          .orderBy('stars', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint("❌ Error al obtener leaderboard: $e");
      return [];
    }
  }
}