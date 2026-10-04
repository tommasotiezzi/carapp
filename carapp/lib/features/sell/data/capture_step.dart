/// One step of the guided capture, from `vehicle_categories.capture_steps`.
class CaptureStep {
  const CaptureStep({
    required this.id,
    this.seconds = 5,
    this.silhouette,
    this.plateTip = false,
    this.hint,
    this.required = true,
  });

  /// e.g. 'front', also the ARB key suffix of its label.
  final String id;
  final int seconds;

  /// Outline drawn over the camera ('car_side_l', ...); null = none.
  final String? silhouette;

  /// Show "se vuoi, copri la targa".
  final bool plateTip;

  /// Extra instruction, e.g. 'engine_running_show_km'.
  final String? hint;
  final bool required;

  factory CaptureStep.fromJson(Map<String, dynamic> json) => CaptureStep(
        id: json['id'] as String,
        seconds: (json['seconds'] as num?)?.toInt() ?? 5,
        silhouette: json['silhouette'] as String?,
        plateTip: (json['plate_tip'] as bool?) ?? false,
        hint: json['hint'] as String?,
        required: (json['required'] as bool?) ?? true,
      );

  static List<CaptureStep> listFromJson(Object? json) => ((json as List?) ?? const [])
      .cast<Map<String, dynamic>>()
      .map(CaptureStep.fromJson)
      .toList();

  /// Same as the database (05_seed.sql, first car step from 15): used when the catalog cannot be
  /// read (offline at the first launch), so capture can still start.
  static List<CaptureStep> defaultsFor(String categoryId) => categoryId == 'motorcycle'
      ? const [
          CaptureStep(id: 'left_side', silhouette: 'moto_side_l'),
          CaptureStep(id: 'right_side', silhouette: 'moto_side_r'),
          CaptureStep(id: 'rear', silhouette: 'moto_rear', plateTip: true),
          CaptureStep(id: 'tank_dashboard', hint: 'engine_running_show_km'),
          CaptureStep(id: 'chain_tyres', required: false),
          CaptureStep(id: 'exhaust', required: false),
          CaptureStep(id: 'defects', required: false),
        ]
      : const [
          CaptureStep(id: 'front', silhouette: 'car_front', plateTip: true),
          CaptureStep(id: 'right_side', silhouette: 'car_side_r'),
          CaptureStep(id: 'left_side', silhouette: 'car_side_l'),
          CaptureStep(id: 'rear', silhouette: 'car_rear', plateTip: true),
          CaptureStep(id: 'interior_dashboard', hint: 'engine_running_show_km'),
          CaptureStep(id: 'engine_bay', required: false),
          CaptureStep(id: 'defects', required: false),
        ];
}
