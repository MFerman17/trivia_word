import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameTheme {
  // Paleta estilo Fortnite / Monster Legends
  static const Color bgDark = Color(0xFF0D0B21);      // Fondo noche profunda
  static const Color cardBg = Color(0xFF1E1A3C);      // Tarjeta púrpura vibrante
  static const Color accentYellow = Color(0xFFFFCC00); // Amarillo Fortnite / Victoria
  static const Color accentPurple = Color(0xFF8B5CF6); // Púrpura Épico
  static const Color hpRed = Color(0xFFFF3366);        // Rojo impacto
  static const Color shieldBlue = Color(0xFF00D2FF);   // Azul escudo / poción
  static const Color successGreen = Color(0xFF00FF87); // Verde Neón

  // Sombras 3D estilizadas
  static List<BoxShadow> popShadow({Color color = Colors.black38}) => [
        BoxShadow(
          color: color,
          offset: const Offset(0, 4),
          blurRadius: 0, // Borde definido estilo Pop/Comic
        ),
      ];

  // Estilo de Texto Principal (Títulos estilo Fortnite)
  static TextStyle titleStyle({double size = 24, Color color = Colors.white}) {
    return GoogleFonts.luckiestGuy(
      fontSize: size,
      color: color,
      letterSpacing: 1.2,
      shadows: const [
        Shadow(offset: Offset(2, 2), color: Colors.black, blurRadius: 0),
      ],
    );
  }

  // Estilo de Texto Secundario (Botones y Preguntas)
  static TextStyle bodyStyle({
    double size = 16,
    Color color = Colors.white,
    FontWeight weight = FontWeight.bold,
  }) {
    return GoogleFonts.rajdhani(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}