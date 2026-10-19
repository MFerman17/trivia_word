import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Atajo para leer los textos traducidos en cualquier pantalla:
///   `Text(context.l10n.playAdventure)`
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Textos del idioma actual para el código que no tiene `context`
/// (controladores y servicios). Se actualiza en main.dart cada vez que
/// cambia el idioma.
class L10n {
  L10n._();

  static AppLocalizations current = lookupAppLocalizations(const Locale('es'));
}
