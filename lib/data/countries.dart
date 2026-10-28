/// Países que el jugador puede elegir al crear su alias (código ISO de 2
/// letras → nombre en español e inglés). La bandera se calcula del código.
/// Para añadir uno, basta una línea nueva.
class Countries {
  Countries._();

  static const Map<String, (String es, String en)> all = {
    'ES': ('España', 'Spain'),
    'MX': ('México', 'Mexico'),
    'AR': ('Argentina', 'Argentina'),
    'CO': ('Colombia', 'Colombia'),
    'VE': ('Venezuela', 'Venezuela'),
    'PE': ('Perú', 'Peru'),
    'CL': ('Chile', 'Chile'),
    'EC': ('Ecuador', 'Ecuador'),
    'GT': ('Guatemala', 'Guatemala'),
    'CU': ('Cuba', 'Cuba'),
    'BO': ('Bolivia', 'Bolivia'),
    'DO': ('República Dominicana', 'Dominican Republic'),
    'HN': ('Honduras', 'Honduras'),
    'PY': ('Paraguay', 'Paraguay'),
    'SV': ('El Salvador', 'El Salvador'),
    'NI': ('Nicaragua', 'Nicaragua'),
    'CR': ('Costa Rica', 'Costa Rica'),
    'PA': ('Panamá', 'Panama'),
    'UY': ('Uruguay', 'Uruguay'),
    'PR': ('Puerto Rico', 'Puerto Rico'),
    'GQ': ('Guinea Ecuatorial', 'Equatorial Guinea'),
    'US': ('Estados Unidos', 'United States'),
    'CA': ('Canadá', 'Canada'),
    'BR': ('Brasil', 'Brazil'),
    'PT': ('Portugal', 'Portugal'),
    'GB': ('Reino Unido', 'United Kingdom'),
    'IE': ('Irlanda', 'Ireland'),
    'FR': ('Francia', 'France'),
    'IT': ('Italia', 'Italy'),
    'DE': ('Alemania', 'Germany'),
    'NL': ('Países Bajos', 'Netherlands'),
    'BE': ('Bélgica', 'Belgium'),
    'CH': ('Suiza', 'Switzerland'),
    'AT': ('Austria', 'Austria'),
    'AD': ('Andorra', 'Andorra'),
    'MA': ('Marruecos', 'Morocco'),
    'PH': ('Filipinas', 'Philippines'),
    'AU': ('Australia', 'Australia'),
    'NZ': ('Nueva Zelanda', 'New Zealand'),
    'IN': ('India', 'India'),
    'JP': ('Japón', 'Japan'),
    'CN': ('China', 'China'),
    'KR': ('Corea del Sur', 'South Korea'),
    'ZA': ('Sudáfrica', 'South Africa'),
    'NG': ('Nigeria', 'Nigeria'),
    'RO': ('Rumanía', 'Romania'),
    'PL': ('Polonia', 'Poland'),
    'UA': ('Ucrania', 'Ukraine'),
    'RU': ('Rusia', 'Russia'),
    'SE': ('Suecia', 'Sweden'),
    'NO': ('Noruega', 'Norway'),
    'TR': ('Turquía', 'Turkey'),
  };

  /// Bandera como emoji: cada letra del código se convierte en su
  /// "letra regional" Unicode (E+S → 🇪🇸).
  static String flag(String? code) {
    if (code == null || code.length != 2) return '🌍';
    final upper = code.toUpperCase();
    return String.fromCharCodes(upper.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
  }

  static String name(String code, String languageCode) {
    final entry = all[code.toUpperCase()];
    if (entry == null) return code;
    return languageCode == 'es' ? entry.$1 : entry.$2;
  }
}
