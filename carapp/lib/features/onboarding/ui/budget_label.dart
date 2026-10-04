import '../../../l10n/gen/app_localizations.dart';
import '../data/buyer_preferences.dart';

/// "Fino a 5k", "5–10k"... shared by onboarding preferences and feed filters.
extension BudgetLabels on AppLocalizations {
  String budgetLabel(BudgetOption o) => switch (o) {
        BudgetOption.upTo5k => budgetUpTo('5k'),
        BudgetOption.from5to10k => '5–10k',
        BudgetOption.from10to15k => '10–15k',
        BudgetOption.from15to25k => '15–25k',
        BudgetOption.over25k => budgetOver('25k'),
      };
}
