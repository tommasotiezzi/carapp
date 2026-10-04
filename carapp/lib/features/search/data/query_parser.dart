import '../../feed/data/feed_filters.dart';
import 'catalog.dart';

/// What the Search box understood.
class ParsedQuery {
  const ParsedQuery({required this.filters, this.ignored = const []});

  final FeedFilters filters;

  /// Words not understood and not used (structured filters were found,
  /// so they are dropped instead of risking zero results).
  final List<String> ignored;
}

/// Turns "golf diesel dal 2018 sotto 15mila milano" into [FeedFilters],
/// locally, with the catalog already in memory. Rules:
/// - province capitals, makes and models: longest word sequence first;
///   bare numbers ("500", "2008") and very short names ("up") are models
///   only next to a recognized make;
/// - 4 digits between 1950 and this year = year ("dal" = from, "fino al"
///   = up to, alone = that year);
/// - "8000", "8k", "8mila", "sotto 10mila" = max price ("da", "sopra",
///   "oltre" = min price); "100k km", "100.000 km" = max mileage;
/// - auto/moto, automatica/manuale, neopatentato, fuel synonyms;
/// - other words: searched in version and description only when nothing
///   else was recognized.
class QueryParser {
  QueryParser(this.catalog, {int? currentYear}) : currentYear = currentYear ?? DateTime.now().year;

  final Catalog catalog;
  final int currentYear;

  static const _minYear = 1950;
  static const _minPriceEur = 500;
  static const _maxTextWords = 5;

  static const _stopWords = {
    'a', 'ad', 'al', 'alla', 'allo', 'ai', 'il', 'lo', 'la', 'le', 'i', 'gli', 'l', 'un', 'una',
    'uno', 'di', 'del', 'della', 'dello', 'dei', 'delle', 'degli', 'e', 'ed', 'o', 'con', 'in',
    'per', 'che', 'mi', 'cerco', 'voglio', 'vorrei', 'usata', 'usato', 'usate', 'usati', 'anno',
    'anni', 'prezzo', 'budget', 'euro', '€', 'km', 'chilometri', 'cambio', 'alimentazione',
    'provincia', 'zona', 'vicino', 'circa',
  };

  static const _minMods = {'da', 'sopra', 'oltre', 'almeno', 'minimo', 'piu', 'tra', 'dal', 'dopo'};
  static const _maxMods = {'sotto', 'max', 'massimo', 'entro', 'meno', 'fino', 'prima'};

  static const _categories = {
    'auto': 'car', 'macchina': 'car', 'macchine': 'car', 'automobile': 'car', 'car': 'car',
    'moto': 'motorcycle', 'motocicletta': 'motorcycle', 'motociclette': 'motorcycle',
    'motorino': 'motorcycle', 'scooter': 'motorcycle', 'motorbike': 'motorcycle',
  };

  static const _transmissions = {
    'automatica': 'automatic', 'automatico': 'automatic', 'automatiche': 'automatic',
    'automatici': 'automatic', 'manuale': 'manual', 'manuali': 'manual',
    'semiautomatica': 'semi_automatic', 'semiautomatico': 'semi_automatic',
    'robotizzata': 'semi_automatic', 'robotizzato': 'semi_automatic',
    'sequenziale': 'semi_automatic',
  };

  static const _fuels = {
    'benzina': 'petrol', 'diesel': 'diesel', 'gasolio': 'diesel', 'gpl': 'lpg',
    'metano': 'cng', 'ibrida': 'hybrid', 'ibrido': 'hybrid', 'ibride': 'hybrid',
    'ibridi': 'hybrid', 'hybrid': 'hybrid', 'plugin': 'plugin_hybrid', 'phev': 'plugin_hybrid',
    'elettrica': 'electric', 'elettrico': 'electric', 'elettriche': 'electric',
    'elettrici': 'electric', 'ev': 'electric', 'bev': 'electric',
  };

  static final _number = RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+(?:,\d+)?)(k|mila)?(km)?$');

  ParsedQuery parse(String query) {
    final tokens = Catalog.normalize(query).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const ParsedQuery(filters: FeedFilters.empty);
    final used = List<bool>.filled(tokens.length, false);

    String? province;
    final makeIds = <String>{};
    final modelIds = <String>{};

    // 1. Province capitals, makes, models: longest sequence first.
    for (var i = 0; i < tokens.length; i++) {
      if (used[i]) continue;
      for (var n = 3; n >= 1; n--) {
        if (i + n > tokens.length || used.sublist(i, i + n).contains(true)) continue;
        final key = tokens.sublist(i, i + n).join(' ');
        final code = _provinces[key];
        if (code != null && province == null) {
          province = code;
          used.fillRange(i, i + n, true);
          break;
        }
        final makes = _isNumeric(key) ? null : catalog.makesByKey[key];
        if (makes != null) {
          makeIds.addAll(makes.map((m) => m.id));
          used.fillRange(i, i + n, true);
          break;
        }
      }
    }
    for (var i = 0; i < tokens.length; i++) {
      if (used[i]) continue;
      for (var n = 3; n >= 1; n--) {
        if (i + n > tokens.length || used.sublist(i, i + n).contains(true)) continue;
        final key = tokens.sublist(i, i + n).join(' ');
        final models = _matchModels(key, makeIds);
        if (models.isNotEmpty) {
          modelIds.addAll(models.map((m) => m.id));
          used.fillRange(i, i + n, true);
          break;
        }
      }
    }

    // 2. Everything else, left to right.
    String? category;
    String? transmission;
    var novice = false;
    final fuels = <String>{};
    int? priceMin, priceMax, yearMin, yearMax, mileageMax;
    final unknown = <String>[];
    String? mod; // the last modifier word, applies to the next number

    for (var i = 0; i < tokens.length; i++) {
      if (used[i]) continue;
      final tok = tokens[i];
      final next = i + 1 < tokens.length ? tokens[i + 1] : null;
      final prev = i > 0 ? tokens[i - 1] : null;

      if (_minMods.contains(tok) || _maxMods.contains(tok)) {
        mod = tok;
        continue;
      }
      if (tok == 'plug' && next == 'in') {
        fuels.add('plugin_hybrid');
        i++;
        continue;
      }
      if (tok == 'neo' && next != null && next.startsWith('patentat')) {
        novice = true;
        i++;
        continue;
      }
      if (tok.startsWith('neopatentat')) {
        novice = true;
        continue;
      }
      if (_categories.containsKey(tok)) {
        category = _categories[tok];
        continue;
      }
      if (_transmissions.containsKey(tok)) {
        transmission = _transmissions[tok];
        continue;
      }
      if (_fuels.containsKey(tok)) {
        fuels.add(_fuels[tok]!);
        continue;
      }

      final m = _number.firstMatch(tok);
      if (m != null) {
        final multiplier = m.group(2) == null ? 1 : 1000;
        final base = double.parse(m.group(1)!.replaceAll('.', '').replaceAll(',', '.'));
        final value = (base * multiplier).round();
        final isKm = m.group(3) != null || next == 'km' || next == 'chilometri';
        final isEuro = next == '€' || next == 'euro' || prev == '€';
        final plainFourDigits = multiplier == 1 && RegExp(r'^\d{4}$').hasMatch(m.group(1)!);

        if (isKm) {
          mileageMax = value;
        } else if (!isEuro && plainFourDigits && value >= _minYear && value <= currentYear) {
          if (mod == 'dal' || mod == 'dopo' || mod == 'da') {
            yearMin = value;
          } else if (_maxMods.contains(mod) || (yearMin != null && (prev == 'al' || prev == 'a'))) {
            yearMax = value;
          } else {
            yearMin = value;
            yearMax = value;
          }
        } else if (isEuro || multiplier > 1 || value >= _minPriceEur) {
          final cents = value * 100;
          final wantsMin = _minMods.contains(mod) && mod != 'dal' && mod != 'dopo';
          if (wantsMin && priceMin == null) {
            priceMin = cents;
          } else {
            priceMax = cents;
          }
        } else {
          unknown.add(tok);
        }
        mod = null;
        continue;
      }

      if (_stopWords.contains(tok)) continue;
      unknown.add(tok);
      mod = null;
    }

    if (fuels.contains('plugin_hybrid')) fuels.remove('hybrid');

    // A category keeps only the makes / models that belong to it
    // ("moto honda" = Honda motorcycles, not cars).
    if (category != null) {
      makeIds.removeWhere((id) => catalog.makeById[id]?.categoryId != category);
      modelIds.removeWhere((id) => catalog.categoryOfModel(id) != category);
    }
    // "golf 2015 2018": two years without modifiers -> a range.
    if (yearMin != null && yearMax != null && yearMin > yearMax) {
      (yearMin, yearMax) = (yearMax, yearMin);
    }
    if (priceMin != null && priceMax != null && priceMin > priceMax) {
      (priceMin, priceMax) = (priceMax, priceMin);
    }

    final structured = FeedFilters(
      categoryId: category,
      priceMinCents: priceMin,
      priceMaxCents: priceMax,
      makeIds: makeIds,
      modelIds: modelIds,
      yearMin: yearMin,
      yearMax: yearMax,
      mileageMaxKm: mileageMax,
      fuelTypes: fuels,
      transmission: transmission,
      noviceDriver: novice,
      province: province,
    );
    final words = {...unknown}.toList();
    if (structured.isEmpty) {
      return ParsedQuery(filters: structured.copyWith(textWords: words.take(_maxTextWords).toList()));
    }
    return ParsedQuery(filters: structured, ignored: words);
  }

  List<CatalogModel> _matchModels(String key, Set<String> makeIds) {
    final candidates = catalog.modelsByKey[key];
    if (candidates == null) return const [];
    if (makeIds.isNotEmpty) {
      return candidates.where((m) => makeIds.contains(m.makeId)).toList();
    }
    // Without a make: no bare numbers ("500" could be a price) and no tiny
    // names ("up", "ka"), except letter+digit codes like "q3" or "x5".
    final shortCode = key.length == 2 && RegExp(r'[a-z]').hasMatch(key) && RegExp(r'\d').hasMatch(key);
    if (_isNumeric(key) || (key.length < 3 && !shortCode)) return const [];
    return candidates;
  }

  static bool _isNumeric(String key) => RegExp(r'^[\d. ]+$').hasMatch(key);

  /// Province capital (normalized) -> `listings.province` code.
  static const _provinces = {
    'agrigento': 'AG', 'alessandria': 'AL', 'ancona': 'AN', 'aosta': 'AO', 'arezzo': 'AR',
    'ascoli piceno': 'AP', 'ascoli': 'AP', 'asti': 'AT', 'avellino': 'AV', 'bari': 'BA',
    'barletta': 'BT', 'andria': 'BT', 'trani': 'BT', 'belluno': 'BL', 'benevento': 'BN',
    'bergamo': 'BG', 'biella': 'BI', 'bologna': 'BO', 'bolzano': 'BZ', 'brescia': 'BS',
    'brindisi': 'BR', 'cagliari': 'CA', 'caltanissetta': 'CL', 'campobasso': 'CB',
    'caserta': 'CE', 'catania': 'CT', 'catanzaro': 'CZ', 'chieti': 'CH', 'como': 'CO',
    'cosenza': 'CS', 'cremona': 'CR', 'crotone': 'KR', 'cuneo': 'CN', 'enna': 'EN',
    'fermo': 'FM', 'ferrara': 'FE', 'firenze': 'FI', 'foggia': 'FG', 'forli': 'FC',
    'cesena': 'FC', 'frosinone': 'FR', 'genova': 'GE', 'gorizia': 'GO', 'grosseto': 'GR',
    'imperia': 'IM', 'isernia': 'IS', 'l aquila': 'AQ', 'aquila': 'AQ', 'la spezia': 'SP',
    'spezia': 'SP', 'latina': 'LT', 'lecce': 'LE', 'lecco': 'LC', 'livorno': 'LI', 'lodi': 'LO',
    'lucca': 'LU', 'macerata': 'MC', 'mantova': 'MN', 'massa': 'MS', 'carrara': 'MS',
    'matera': 'MT', 'messina': 'ME', 'milano': 'MI', 'modena': 'MO', 'monza': 'MB',
    'napoli': 'NA', 'novara': 'NO', 'nuoro': 'NU', 'oristano': 'OR', 'padova': 'PD',
    'palermo': 'PA', 'parma': 'PR', 'pavia': 'PV', 'perugia': 'PG', 'pesaro': 'PU',
    'urbino': 'PU', 'pescara': 'PE', 'piacenza': 'PC', 'pisa': 'PI', 'pistoia': 'PT',
    'pordenone': 'PN', 'potenza': 'PZ', 'prato': 'PO', 'ragusa': 'RG', 'ravenna': 'RA',
    'reggio calabria': 'RC', 'reggio emilia': 'RE', 'rieti': 'RI', 'rimini': 'RN',
    'roma': 'RM', 'rovigo': 'RO', 'salerno': 'SA', 'sassari': 'SS', 'savona': 'SV',
    'siena': 'SI', 'siracusa': 'SR', 'sondrio': 'SO', 'taranto': 'TA', 'teramo': 'TE',
    'terni': 'TR', 'torino': 'TO', 'trapani': 'TP', 'trento': 'TN', 'treviso': 'TV',
    'trieste': 'TS', 'udine': 'UD', 'varese': 'VA', 'venezia': 'VE', 'verbania': 'VB',
    'vercelli': 'VC', 'verona': 'VR', 'vibo valentia': 'VV', 'vicenza': 'VI', 'viterbo': 'VT',
  };

  /// Code -> capital, for chips ("Milano", "L'Aquila", "Forlì").
  static final Map<String, String> provinceNames = () {
    const aliases = {'ascoli', 'aquila', 'spezia', 'andria', 'trani', 'cesena', 'carrara', 'urbino'};
    const spelled = {'FC': 'Forlì', 'AQ': "L'Aquila"};
    final names = <String, String>{};
    for (final MapEntry(key: name, value: code) in _provinces.entries) {
      if (aliases.contains(name) || names.containsKey(code)) continue;
      names[code] = spelled[code] ??
          name.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    }
    return names;
  }();
}
