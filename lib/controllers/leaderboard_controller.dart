import 'package:flutter/foundation.dart';
import '../services/cloud_service.dart';

class LeaderboardController extends ChangeNotifier {
  bool isLoading = true;
  List<Map<String, dynamic>> topPlayers = [];

  /// Llama al servicio de la nube y actualiza la lista de jugadores
  Future<void> fetchLeaderboard() async {
    isLoading = true;
    notifyListeners();

    topPlayers = await CloudService.getGlobalLeaderboard();

    isLoading = false;
    notifyListeners();
  }
}