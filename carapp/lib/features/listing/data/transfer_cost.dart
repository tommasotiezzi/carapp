/// Estimate of the Italian ownership transfer ("passaggio di proprietà")
/// for a used car bought from a private seller.
///
/// - IPT (provincial tax): fixed up to [iptBaseMaxKw] kW, per kW above it,
///   plus the provincial surcharge (up to +30%, applied by most provinces).
/// - Fixed fees: ACI/PRA emoluments 27 + PRA stamp duty 32
///   + DU stamp duty 16 + Motorizzazione fees 10.20 = 85.20 EUR.
///
/// Values can be overridden from `app_config.transfer_costs` without a release.
/// Motorcycles are not estimated: their IPT rules differ and are not confirmed.
class TransferCostRules {
  const TransferCostRules({
    this.iptBaseCents = 15081,
    this.iptBaseMaxKw = 53,
    this.iptPerKwCents = 351.19,
    this.provincialSurchargePct = 30,
    this.fixedFeesCents = 8520,
  });

  final int iptBaseCents;
  final int iptBaseMaxKw;
  final double iptPerKwCents;
  final double provincialSurchargePct;
  final int fixedFeesCents;

  /// Reads `app_config.transfer_costs`; missing keys keep the defaults.
  factory TransferCostRules.fromConfig(Map<String, dynamic> json) {
    const d = TransferCostRules();
    num? n(String key) => json[key] as num?;
    return TransferCostRules(
      iptBaseCents: n('ipt_base_cents')?.toInt() ?? d.iptBaseCents,
      iptBaseMaxKw: n('ipt_base_max_kw')?.toInt() ?? d.iptBaseMaxKw,
      iptPerKwCents: n('ipt_per_kw_cents')?.toDouble() ?? d.iptPerKwCents,
      provincialSurchargePct:
          n('provincial_surcharge_pct')?.toDouble() ?? d.provincialSurchargePct,
      fixedFeesCents: n('fixed_fees_cents')?.toInt() ?? d.fixedFeesCents,
    );
  }

  /// null when there is not enough data to estimate.
  int? estimateCents({required String categoryId, required int? powerKw}) {
    if (categoryId != 'car' || powerKw == null || powerKw <= 0) return null;
    final ipt = powerKw <= iptBaseMaxKw ? iptBaseCents.toDouble() : iptPerKwCents * powerKw;
    return (ipt * (1 + provincialSurchargePct / 100) + fixedFeesCents).round();
  }
}
