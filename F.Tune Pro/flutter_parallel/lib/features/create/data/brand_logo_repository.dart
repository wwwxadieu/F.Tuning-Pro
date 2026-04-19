class BrandLogoRepository {
  BrandLogoRepository._();

  static const Map<String, String> _slugByKey = <String, String>{
    'abarth': 'abarth',
    'acura': 'acura',
    'alfa': 'alfaromeo',
    'alpine': 'alpine',
    'amg': 'mercedesbenz',
    'aston': 'astonmartin',
    'audi': 'audi',
    'bentley': 'bentley',
    'bmw': 'bmw',
    'bugatti': 'bugatti',
    'buick': 'buick',
    'cadillac': 'cadillac',
    'chevrolet': 'chevrolet',
    'citroen': 'citroen',
    'cupra': 'cupra',
    'datsun': 'datsun',
    'delorean': 'delorean',
    'dodge': 'dodge',
    'ds': 'ds',
    'ferrari': 'ferrari',
    'fiat': 'fiat',
    'ford': 'ford',
    'gmc': 'gmc',
    'holden': 'holden',
    'honda': 'honda',
    'hummer': 'hummer',
    'hyundai': 'hyundai',
    'infiniti': 'infiniti',
    'jaguar': 'jaguar',
    'jeep': 'jeep',
    'kia': 'kia',
    'koenigsegg': 'koenigsegg',
    'ktm': 'ktm',
    'lamborghini': 'lamborghini',
    'lancia': 'lancia',
    'land': 'landrover',
    'lexus': 'lexus',
    'lincoln': 'lincoln',
    'lotus': 'lotus',
    'lucid': 'lucid',
    'lynk': 'lynkco',
    'maserati': 'maserati',
    'mazda': 'mazda',
    'mclaren': 'mclaren',
    'mercedesamg': 'mercedes-amg',
    'mercedesbenz': 'mercedes-benz',
    'mg': 'mg',
    'mini': 'mini',
    'mitsubishi': 'mitsubishi',
    'morgan': 'morgan',
    'nio': 'nio',
    'nissan': 'nissan',
    'opel': 'opel',
    'pagani': 'pagani',
    'peugeot': 'peugeot',
    'polaris': 'polaris',
    'pontiac': 'pontiac',
    'porsche': 'porsche',
    'ram': 'ram',
    'renault': 'renault',
    'rimac': 'rimac',
    'rivian': 'rivian',
    'subaru': 'subaru',
    'toyota': 'toyota',
    'vauxhall': 'vauxhall',
    'volkswagen': 'volkswagen',
    'volvo': 'volvo',
    'wuling': 'wuling',
    'xpeng': 'xpeng',
  };

  static const Map<String, String> _carLogosSlugOverrides = <String, String>{
    'alfa': 'alfa-romeo',
    'aston': 'aston-martin',
    'land': 'land-rover',
    'lynk': 'lynkco',
    'amg': 'mercedes-amg',
    'austinhealey': 'austin',
    'automobili': 'pininfarina',
    'spania': 'spania-gta',
    'w': 'w-motors',
    'willys': 'willys-overland',
  };

  static const Map<String, String> _githubSlugOverrides = <String, String>{
    'cupra': 'cupra',
    'amc': 'amc',
  };

  static const Map<String, List<String>> _extraSlugCandidatesByKey =
      <String, List<String>>{
        'apollo': <String>['apollo-automobil', 'apollo-automobiles'],
        'ariel': <String>['ariel-motor-company', 'ariel-motor'],
        'ascari': <String>['ascari-cars'],
        'ats': <String>['ats-automobili'],
        'auto': <String>['auto-union'],
        'autozam': <String>['mazda-autozam'],
        'bac': <String>['briggs-automotive-company'],
        'brabham': <String>['brabham-automotive'],
        'canam': <String>['can-am'],
        'caterham': <String>['caterham-cars'],
        'czinger': <String>['czinger-vehicles'],
        'donkervoort': <String>['donkervoort-automobielen'],
        'eagle': <String>['eagle-cars'],
        'elemental': <String>['elemental-cars'],
        'funco': <String>['funco-motorsports'],
        'ginetta': <String>['ginetta-cars'],
        'gordon': <String>['gordon-murray', 'gordon-murray-automotive'],
        'hdt': <String>['hdt-special-vehicles'],
        'hennessey': <String>['hennessey-performance'],
        'hoonigan': <String>['hoonigan-racing-division'],
        'hsv': <String>['holden-special-vehicles'],
        'international': <String>['international-harvester'],
        'italdesign': <String>['italdesign-giugiaro'],
        'local': <String>['local-motors'],
        'lola': <String>['lola-cars'],
        'meyers': <String>['meyers-manx'],
        'morris': <String>['morris-motors'],
        'mosler': <String>['mosler-automotive'],
        'noble': <String>['noble-automotive'],
        'radical': <String>['radical-sportscars'],
        'raesr': <String>['rice-advanced-engineering-systems-and-research'],
        'rossion': <String>['rossion-automotive'],
        'saleen': <String>['saleen-automotive'],
        'shelby': <String>['shelby-american'],
        'sierra': <String>['sierra-cars'],
        'ultima': <String>['ultima-sports'],
        'vuhl': <String>['vuhl-05'],
        'zenvo': <String>['zenvo-automotive'],
      };

  static String normalizeBrandKey(String brand) {
    final folded = brand
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ñ', 'n')
        .replaceAll('ó', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ý', 'y');
    return folded
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static String toBrandLogoSlug(String brand) {
    final normalizedKey = normalizeBrandKey(brand);
    final mapped = _slugByKey[normalizedKey];
    if (mapped != null && mapped.isNotEmpty) {
      return mapped;
    }

    final slug = brand
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    return slug;
  }

  static List<String> getBrandLogoUrlCandidates(String brand) {
    final logoKey = normalizeBrandKey(brand);
    final defaultSlug = toBrandLogoSlug(brand);
    final primarySlug = _carLogosSlugOverrides[logoKey] ?? defaultSlug;
    final secondarySlug = _githubSlugOverrides[logoKey] ?? primarySlug;
    final slugCandidates = <String>{
      primarySlug,
      secondarySlug,
      defaultSlug,
      ...?_extraSlugCandidatesByKey[logoKey],
    }.where((slug) => slug.isNotEmpty);

    final urls = <String>[];
    for (final slug in slugCandidates) {
      urls.add('https://www.carlogos.org/car-logos/$slug-logo.png');
      urls.add(
        'https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/optimized/$slug.png',
      );
    }
    return urls;
  }

  static String getBrandLogoFallbackText(String brand) {
    final tokens = brand
        .trim()
        .split(RegExp(r'[\s\-]+'))
        .where((token) => token.trim().isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '--';
    if (tokens.length == 1) {
      final token = tokens.first;
      return token.length >= 2
          ? token.substring(0, 2).toUpperCase()
          : token.toUpperCase();
    }
    return '${tokens[0][0]}${tokens[1][0]}'.toUpperCase();
  }
}
