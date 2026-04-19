// Car catalog data models shared between CreateTunePage and DashboardPage.

/// A car from the FH5 catalog, as loaded from assets/data/FH5_cars.json.
class CarSpec {
  const CarSpec({
    required this.brand,
    required this.model,
    required this.pi,
    required this.topSpeedKmh,
    required this.differential,
    required this.tireType,
    required this.driveType,
  });

  final String brand;
  final String model;
  final int pi;
  final double topSpeedKmh;
  final String differential;
  final String tireType;
  final String driveType;

  factory CarSpec.fromJson(Map<String, dynamic> json) {
    return CarSpec(
      brand: json['brand'] as String? ?? 'Unknown',
      model: json['model'] as String? ?? 'Unknown',
      pi: (json['pi'] as num? ?? 0).round(),
      topSpeedKmh: (json['topSpeedKmh'] as num? ?? 0).toDouble(),
      differential:
          json['differential'] as String? ?? 'Unknown Differential',
      tireType: json['tireType'] as String? ?? 'Street',
      driveType: json['driveType'] as String? ?? 'RWD',
    );
  }
}

/// Groups a brand's models together for the car picker UI.
class BrandBucket {
  const BrandBucket(this.brand, this.models);

  final String brand;
  final List<CarSpec> models;
}
