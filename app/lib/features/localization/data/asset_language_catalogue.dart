import 'package:flutter/services.dart';
import 'package:hisaab/features/localization/domain/language.dart';

/// Catalogues bundled as `assets/l10n/<code>.yaml` (FR-29-05).
class AssetLanguageCatalogue implements LanguageCatalogue {
  /// Creates the catalogue over [bundle] (the app bundle by default).
  AssetLanguageCatalogue([AssetBundle? bundle])
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<String?> load(Language l) async {
    try {
      return await _bundle.loadString('assets/l10n/${l.code}.yaml');
    } on Object {
      return null;
    }
  }
}
