import '../../../l10n/gen/app_localizations.dart';
import '../data/capture_step.dart';

/// Italian labels for the capture steps and the category fields.
extension SellLabels on AppLocalizations {
  String stepLabel(String stepId) => switch (stepId) {
        'front' => sellStepFront,
        'front_three_quarter' => sellStepFront3q, // drafts from before 15
        'right_side' => sellStepRightSide,
        'left_side' => sellStepLeftSide,
        'rear' => sellStepRear,
        'interior_dashboard' => sellStepInterior,
        'engine_bay' => sellStepEngineBay,
        'defects' => sellStepDefects,
        'tank_dashboard' => sellStepTank,
        'chain_tyres' => sellStepChain,
        'exhaust' => sellStepExhaust,
        _ => stepId.replaceAll('_', ' '),
      };

  String photoSlotLabel(String slotId) => switch (slotId) {
        'front_three_quarter' => photoFront3q,
        'front' => photoFront,
        'side' => photoSide,
        'rear_three_quarter' => photoRear3q,
        'rear' => photoRear,
        'dashboard' => photoDashboard,
        'interior' => photoInterior,
        'rear_seats' => photoRearSeats,
        'trunk' => photoTrunk,
        'wheels' => photoWheels,
        'tank' => photoTank,
        'chain_tyres' => photoChainTyres,
        'exhaust' => photoExhaust,
        _ => photoOther,
      };

  /// How to take it: under the title on the camera and in the summary.
  String photoSlotHint(String slotId) => switch (slotId) {
        'front_three_quarter' => photoFront3qHint,
        'front' => photoFrontHint,
        'side' => photoSideHint,
        'rear_three_quarter' => photoRear3qHint,
        'rear' => photoRearHint,
        'dashboard' => photoDashboardHint,
        'interior' => photoInteriorHint,
        'rear_seats' => photoRearSeatsHint,
        'trunk' => photoTrunkHint,
        'wheels' => photoWheelsHint,
        'tank' => photoTankHint,
        'chain_tyres' => photoChainTyresHint,
        'exhaust' => photoExhaustHint,
        _ => captureHoldStill,
      };

  /// The line under the step title on the camera.
  String stepInstruction(CaptureStep step, String categoryId) {
    if (step.id == 'front') return captureAlignFront;
    if (step.silhouette != null) {
      return categoryId == 'motorcycle' ? captureAlignMoto : captureAlignCar;
    }
    if (step.hint == 'engine_running_show_km') return captureHintKm;
    return switch (step.id) {
      'engine_bay' => captureHintEngineBay,
      'defects' => captureHintDefects,
      'chain_tyres' => captureHintChain,
      'exhaust' => captureHintExhaust,
      _ => captureHoldStill,
    };
  }

  String bodyTypeLabel(String value) => switch (value) {
        'city_car' => bodyCityCar,
        'hatchback' => bodyHatchback,
        'sedan' => bodySedan,
        'station_wagon' => bodyStationWagon,
        'suv' => bodySuv,
        'coupe' => bodyCoupe,
        'convertible' => bodyConvertible,
        'minivan' => bodyMinivan,
        'van' => bodyVan,
        'pickup' => bodyPickup,
        _ => value,
      };

  String motoTypeLabel(String value) => switch (value) {
        'naked' => motoNaked,
        'sport' => motoSport,
        'touring' => motoTouring,
        'adventure' => motoAdventure,
        'enduro' => motoEnduro,
        'cross' => motoCross,
        'custom' => motoCustom,
        'scooter' => motoScooter,
        'motard' => motoMotard,
        _ => value,
      };
}
