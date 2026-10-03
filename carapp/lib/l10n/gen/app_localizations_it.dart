// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Carfeed';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Cerca';

  @override
  String get navSell => 'Vendi';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profilo';

  @override
  String get commonContinue => 'Continua';

  @override
  String get commonSkip => 'Salta';

  @override
  String get commonNotNow => 'Non ora';

  @override
  String get commonAll => 'Tutte';

  @override
  String get commonAny => 'Qualsiasi';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonShare => 'Condividi';

  @override
  String get commonContact => 'Contatta';

  @override
  String get commonDone => 'Fatto';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonRetry => 'Riprova';

  @override
  String comingSoon(String feature) {
    return '$feature: in arrivo';
  }

  @override
  String get onboardingTitle => 'Cosa vuoi fare?';

  @override
  String get onboardingSubtitle =>
      'Scegli una cosa, il resto lo sistemiamo strada facendo.';

  @override
  String get onboardingHaveAccount => 'Hai già un account?';

  @override
  String get onboardingLogin => 'Accedi';

  @override
  String get intentBuy => 'Voglio comprare';

  @override
  String get intentBuySubtitle => 'Un\'auto o una moto, nuova per te';

  @override
  String get intentSell => 'Voglio vendere';

  @override
  String get intentSellSubtitle => 'Pubblica il tuo veicolo in 5 minuti';

  @override
  String get intentDealer => 'Sono un concessionario';

  @override
  String get intentDealerSubtitle => 'Porta il tuo stock nel feed';

  @override
  String get intentBrowse => 'Sto solo guardando';

  @override
  String get intentBrowseSubtitle => 'Nessun impegno, scrolla e basta';

  @override
  String get prefsTitle => 'Cosa cerchi?';

  @override
  String get prefsSubtitle =>
      'Tutto facoltativo. Anche una sola scelta ci aiuta.';

  @override
  String get prefsVehicle => 'Veicolo';

  @override
  String get prefsBudget => 'Budget';

  @override
  String get prefsBrands => 'Marche preferite';

  @override
  String get prefsYear => 'Anno';

  @override
  String get prefsMileage => 'Chilometri';

  @override
  String get prefsNovice => 'Sono neopatentato';

  @override
  String get prefsNoviceSubtitle =>
      'Ti mostriamo prima i veicoli che puoi guidare';

  @override
  String get prefsCta => 'Mostrami i veicoli';

  @override
  String get prefsSaveCta => 'Salva preferenze';

  @override
  String get prefsFootnote => 'Puoi cambiare tutto quando vuoi dal profilo';

  @override
  String get vehicleAll => 'Tutti';

  @override
  String get vehicleCar => 'Auto';

  @override
  String get vehicleMotorcycle => 'Moto';

  @override
  String get moreBrands => '+ Altre';

  @override
  String get brandsSheetTitle => 'Tutte le marche';

  @override
  String budgetUpTo(String amount) {
    return 'Fino a $amount';
  }

  @override
  String budgetOver(String amount) {
    return 'Oltre $amount';
  }

  @override
  String yearFrom(String year) {
    return 'Dal $year';
  }

  @override
  String mileageMax(String km) {
    return 'Max $km km';
  }

  @override
  String get dealerTitle => 'Il tuo salone';

  @override
  String get dealerSubtitle =>
      'Ci basta la partita IVA: il resto lo recuperiamo noi.';

  @override
  String get dealerLoginNeeded =>
      'Prima accedi con la tua email: il salone sarà collegato al tuo account.';

  @override
  String get dealerLoginCta => 'Accedi per continuare';

  @override
  String get dealerVatLabel => 'Partita IVA';

  @override
  String get dealerNameLabel => 'Nome mostrato nell\'app';

  @override
  String get dealerTrialTitle => 'Gratis per 3 mesi';

  @override
  String get dealerTrialBody =>
      'Poi resta gratis fino al sesto mese, finché non superi 30 contatti in totale. Dopo, € 29/mese bloccati per sempre. Nessuna carta richiesta.';

  @override
  String get dealerCta => 'Crea il profilo del salone';

  @override
  String get dealerCreated => 'Salone creato';

  @override
  String get dealerErrorInvalidVat => 'Partita IVA non valida o non attiva.';

  @override
  String get dealerErrorTaken => 'Questa partita IVA è già registrata.';

  @override
  String get dealerErrorVies =>
      'Il servizio di verifica non risponde, riprova tra poco.';

  @override
  String get dealerErrorGeneric => 'Qualcosa è andato storto, riprova.';

  @override
  String get loginTitle => 'Ti piace qualcosa?';

  @override
  String get loginSubtitle =>
      'Accedi per salvare le auto, ricevere un avviso se calano di prezzo e scrivere ai venditori.';

  @override
  String get loginEmailLabel => 'La tua email';

  @override
  String get loginSendCode => 'Mandami il codice';

  @override
  String get loginCodeTitle => 'Controlla la tua email';

  @override
  String loginCodeSubtitle(String email) {
    return 'Abbiamo mandato un codice a $email';
  }

  @override
  String get loginCodeLabel => 'Codice';

  @override
  String get loginVerify => 'Accedi';

  @override
  String get loginResend => 'Rimanda il codice';

  @override
  String get loginChangeEmail => 'Cambia email';

  @override
  String get loginErrorEmail => 'Controlla l\'indirizzo email.';

  @override
  String get loginErrorCode => 'Codice non valido o scaduto.';

  @override
  String get loginErrorSend =>
      'Non siamo riusciti a inviare il codice, riprova tra poco.';

  @override
  String get loginTerms =>
      'Continuando accetti i Termini e l\'Informativa privacy.';

  @override
  String get profileGuestTitle => 'Ciao!';

  @override
  String get profileGuestSubtitle => 'Accedi per salvare auto e ricerche';

  @override
  String get profileLogin => 'Accedi o registrati';

  @override
  String get profileLogout => 'Esci';

  @override
  String get profileWhatILookFor => 'Cosa cerco';

  @override
  String get profileEdit => 'Modifica';

  @override
  String get profileNoPreferences =>
      'Dicci budget e marche: il feed ti mostrerà prima i veicoli giusti.';

  @override
  String get profileSetPreferences => 'Imposta in 30 secondi';

  @override
  String priceBelowAverage(int percent) {
    return '$percent% sotto la media';
  }
}
