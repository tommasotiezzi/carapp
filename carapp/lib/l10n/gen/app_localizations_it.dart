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
  String get profilePrefsGuest =>
      'Registrati per salvare cosa cerchi: il feed ti mostrerà prima i veicoli giusti e ti avviseremo quando arrivano.';

  @override
  String get profilePrefsGuestCta => 'Registrati e imposta';

  @override
  String priceBelowAverage(int percent) {
    return '$percent% sotto la media';
  }

  @override
  String get errorTitle => 'Qualcosa è andato storto';

  @override
  String get errorBody => 'Controlla la connessione e riprova.';

  @override
  String get commonYes => 'Sì';

  @override
  String get commonNo => 'No';

  @override
  String get fuelPetrol => 'Benzina';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelHybrid => 'Ibrida';

  @override
  String get fuelPluginHybrid => 'Ibrida plug-in';

  @override
  String get fuelElectric => 'Elettrica';

  @override
  String get fuelLpg => 'GPL';

  @override
  String get fuelCng => 'Metano';

  @override
  String get fuelOther => 'Altro';

  @override
  String get transmissionManual => 'Manuale';

  @override
  String get transmissionAutomatic => 'Automatico';

  @override
  String get transmissionSemiAutomatic => 'Semiautomatico';

  @override
  String get listingNotFoundTitle => 'Annuncio non disponibile';

  @override
  String get listingNotFoundBody =>
      'Potrebbe essere stato venduto o rimosso dal venditore.';

  @override
  String get listingBackToFeed => 'Torna al feed';

  @override
  String get listingPhotos => 'Foto';

  @override
  String get listingSpecs => 'Caratteristiche';

  @override
  String get specYear => 'Anno';

  @override
  String get specMileage => 'Chilometri';

  @override
  String get specFuel => 'Alimentazione';

  @override
  String get specTransmission => 'Cambio';

  @override
  String get specPower => 'Potenza';

  @override
  String get specEuroClass => 'Classe ambientale';

  @override
  String specEuroValue(int euro) {
    return 'Euro $euro';
  }

  @override
  String get specColor => 'Colore';

  @override
  String get specOwners => 'Proprietari';

  @override
  String get specServiceHistory => 'Tagliandi documentati';

  @override
  String get specWarranty => 'Garanzia';

  @override
  String specWarrantyMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months mesi',
      one: '1 mese',
    );
    return '$_temp0';
  }

  @override
  String get listingDescription => 'Descrizione';

  @override
  String get listingShowMore => 'Mostra tutto';

  @override
  String get listingShowLess => 'Mostra meno';

  @override
  String get costTitle => 'Quanto spendi davvero';

  @override
  String get costPrice => 'Prezzo';

  @override
  String get costTransfer => 'Passaggio di proprietà (stima)';

  @override
  String get costTotal => 'Totale stimato';

  @override
  String get costNote =>
      'Stima indicativa: imposta provinciale con la maggiorazione massima più i diritti fissi. Dai concessionari il passaggio può essere già incluso nel prezzo.';

  @override
  String get sellerTitle => 'Venditore';

  @override
  String get sellerPrivate => 'Venditore privato';

  @override
  String get sellerDealer => 'Concessionario';

  @override
  String get sellerVatVerified => 'Partita IVA verificata';

  @override
  String get reviewsTitle => 'Recensioni';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recensioni',
      one: '1 recensione',
      zero: 'Nessuna recensione',
    );
    return '$_temp0';
  }

  @override
  String get qaTitle => 'Domande e risposte';

  @override
  String get qaEmpty => 'Nessuna domanda per ora. Chiedi tu per primo.';

  @override
  String get qaAsk => 'Fai una domanda';

  @override
  String get qaPending => 'In attesa di risposta';

  @override
  String get qaYourQuestion => 'La tua domanda';

  @override
  String get qaHint => 'Es. ha mai avuto incidenti?';

  @override
  String get qaNote =>
      'Il venditore può rendere pubblica la risposta per tutti.';

  @override
  String get qaSend => 'Invia';

  @override
  String get qaSent => 'Domanda inviata al venditore';

  @override
  String get qaError => 'Non siamo riusciti a inviare la domanda, riprova.';

  @override
  String get qaLoginTitle => 'Accedi per fare una domanda';

  @override
  String get qaLoginSubtitle =>
      'Il venditore riceve la tua domanda e ti risponde qui.';

  @override
  String get savedTitle => 'Salvati';

  @override
  String get savedLabel => 'Salvato';

  @override
  String get savedEmpty =>
      'Non hai ancora salvato niente. Tocca Salva su un annuncio per ritrovarlo qui.';

  @override
  String get savedAdded => 'Salvato. Lo ritrovi nel profilo.';

  @override
  String get savedRemoved => 'Rimosso dai salvati';

  @override
  String get savedError => 'Non siamo riusciti a salvare, riprova.';

  @override
  String get savedUnavailable => 'Non più disponibile';

  @override
  String get savedRemove => 'Rimuovi dai salvati';

  @override
  String savedPriceDrop(String amount) {
    return 'Sceso di $amount';
  }
}
