class Monster {
  final String id;
  final String name;
  final String element; // Ej: Fuego, Agua, Sombra, Electricidad
  final int maxHp;
  int currentHp;
  final String iconSymbol; // Ícono o emoji temporal mientras cargamos gráficos
  final int level;

  Monster({
    required this.id,
    required this.name,
    required this.element,
    required this.maxHp,
    required this.currentHp,
    required this.iconSymbol,
    this.level = 1,
  });

  // Método para recibir daño cuando el jugador responde correctamente
  void takeDamage(int damage) {
    currentHp -= damage;
    if (currentHp < 0) {
      currentHp = 0;
    }
  }

  // Comprobar si el monstruo ha sido derrotado
  bool get isDefeated => currentHp <= 0;
}