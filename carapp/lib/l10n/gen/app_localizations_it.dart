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
  String get loginPasswordLabel => 'Password';

  @override
  String loginPasswordHint(int min) {
    return 'Almeno $min caratteri';
  }

  @override
  String get loginShowPassword => 'Mostra password';

  @override
  String get loginHidePassword => 'Nascondi password';

  @override
  String get loginSignIn => 'Accedi';

  @override
  String get loginSignUp => 'Crea account';

  @override
  String get loginSignUpTitle => 'Crea il tuo account';

  @override
  String get loginToSignUp => 'Non hai un account? Registrati';

  @override
  String get loginToSignIn => 'Hai già un account? Accedi';

  @override
  String get loginConfirmTitle => 'Conferma la tua email';

  @override
  String loginConfirmBody(String email) {
    return 'Ti abbiamo mandato un link a $email. Aprilo per attivare l\'account, poi accedi.';
  }

  @override
  String loginErrorPassword(int min) {
    return 'La password deve avere almeno $min caratteri.';
  }

  @override
  String get loginErrorCredentials => 'Email o password non corretti.';

  @override
  String get loginErrorExists =>
      'Esiste già un account con questa email: accedi.';

  @override
  String get loginErrorWeak =>
      'Password troppo debole, scegline una più lunga.';

  @override
  String get loginErrorNotConfirmed =>
      'Prima conferma l\'email che ti abbiamo mandato.';

  @override
  String get loginErrorRateLimit =>
      'Troppi tentativi, riprova tra qualche minuto.';

  @override
  String get loginErrorGeneric => 'Qualcosa è andato storto, riprova.';

  @override
  String get loginErrorEmail => 'Controlla l\'indirizzo email.';

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

  @override
  String get commonRefresh => 'Aggiorna';

  @override
  String get feedEmptyTitle => 'Ancora nessun annuncio';

  @override
  String get feedEmptyBody =>
      'Torna tra poco: stiamo caricando i primi veicoli.';

  @override
  String get feedEmptyFilteredTitle => 'Nessun annuncio con questi filtri';

  @override
  String get feedEmptyFilteredBody =>
      'Prova ad allargare la ricerca: togli un filtro o alza il budget.';

  @override
  String get filterTitle => 'Filtri';

  @override
  String get filterPrice => 'Prezzo';

  @override
  String get filterBrand => 'Marca';

  @override
  String get filterBrands => 'Marche';

  @override
  String filterBrandCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count marche',
      one: '1 marca',
    );
    return '$_temp0';
  }

  @override
  String get filterYear => 'Anno';

  @override
  String get filterMileage => 'Km';

  @override
  String get filterReset => 'Azzera';

  @override
  String get filterApply => 'Mostra annunci';

  @override
  String get filterClearAll => 'Rimuovi i filtri';

  @override
  String get filterEdit => 'Modifica filtri';

  @override
  String get searchLoadMore => 'Carica altri';

  @override
  String get searchShowInFeed => 'Guarda nel feed';

  @override
  String get searchSave => 'Salva ricerca';

  @override
  String get searchSavedTitle => 'Ricerche salvate';

  @override
  String get searchNameLabel => 'Nome della ricerca';

  @override
  String get searchNotify => 'Avvisami quando arrivano annunci nuovi';

  @override
  String get searchSavedDone => 'Ricerca salvata';

  @override
  String get searchDeleted => 'Ricerca eliminata';

  @override
  String get searchDelete => 'Elimina';

  @override
  String get searchMore => 'Altre azioni';

  @override
  String get searchNotifyOn => 'Avvisi attivi';

  @override
  String get searchNotifyOff => 'Avvisi spenti';

  @override
  String get searchError => 'Operazione non riuscita, riprova.';

  @override
  String get searchLoginTitle => 'Accedi per salvare la ricerca';

  @override
  String get searchLoginSubtitle =>
      'La ritrovi qui con un tocco, su qualsiasi telefono.';

  @override
  String get searchAllVehicles => 'Tutti i veicoli';

  @override
  String get searchHint => 'Es. golf diesel dal 2018 sotto 15mila';

  @override
  String get searchClear => 'Cancella';

  @override
  String searchRemoveChip(String label) {
    return 'Togli $label';
  }

  @override
  String searchIgnored(String words) {
    return 'Parole non usate: $words';
  }

  @override
  String get searchRecent => 'Ricerche recenti';

  @override
  String get searchClearRecent => 'Cancella tutto';

  @override
  String get searchPopularBrands => 'Marche popolari';

  @override
  String get searchZeroTitle => 'Nessun annuncio trovato';

  @override
  String searchTryWithout(String label) {
    return 'Prova senza «$label»';
  }

  @override
  String get searchSaveAndNotify => 'Salva ricerca e avvisami';

  @override
  String get searchTapHint =>
      'Tocca un annuncio per aprirlo, oppure guardali tutti nel feed.';

  @override
  String priceUpTo(String price) {
    return 'Fino a $price';
  }

  @override
  String priceFrom(String price) {
    return 'Da $price';
  }

  @override
  String yearUntil(String year) {
    return 'Fino al $year';
  }

  @override
  String filterModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelli',
      one: '1 modello',
    );
    return '$_temp0';
  }

  @override
  String get filterNovice => 'Neopatentati';

  @override
  String filterNoviceNote(int kw) {
    return 'Auto fino a $kw kW, il limite di legge. Il rapporto peso/potenza va verificato: il peso non è tra i dati dell\'annuncio.';
  }

  @override
  String get legalTerms => 'Termini e condizioni';

  @override
  String get legalPrivacy => 'Informativa privacy';

  @override
  String get legalRead => 'Leggi';

  @override
  String get legalOpenError => 'Non riusciamo ad aprire il documento, riprova.';

  @override
  String consentTermsAge(int age) {
    return 'Ho almeno $age anni e accetto i Termini e condizioni';
  }

  @override
  String get consentPrivacy => 'Ho letto l\'Informativa privacy';

  @override
  String get consentMarketing => 'Voglio ricevere email con novità e offerte';

  @override
  String get consentRequired =>
      'Per creare l\'account servono le prime due spunte.';

  @override
  String get consentTitle => 'Prima di continuare';

  @override
  String get consentBody =>
      'Per usare il tuo account conferma di aver letto Termini e Informativa privacy.';

  @override
  String get consentUpdatedTitle => 'Abbiamo aggiornato i documenti';

  @override
  String get consentUpdatedBody =>
      'Termini e Informativa privacy sono cambiati: dai un\'occhiata e conferma per continuare.';

  @override
  String get consentAccept => 'Accetta e continua';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsGuest => 'Accedi per gestire account, notifiche ed email.';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsChangeEmail => 'Cambia email';

  @override
  String get settingsNewEmail => 'Nuova email';

  @override
  String get settingsCurrentPassword => 'Password attuale';

  @override
  String get settingsEmailChanged => 'Email aggiornata';

  @override
  String get settingsEmailConfirm =>
      'Ti abbiamo mandato un link per confermare la nuova email.';

  @override
  String get settingsChangePassword => 'Cambia password';

  @override
  String get settingsNewPassword => 'Nuova password';

  @override
  String get settingsPasswordChanged => 'Password aggiornata';

  @override
  String get settingsAboutYou => 'Su di te';

  @override
  String get settingsAboutYouNote =>
      'Tutto facoltativo: puoi lasciarlo vuoto o toglierlo quando vuoi.';

  @override
  String get settingsDisplayName => 'Nome visualizzato';

  @override
  String get settingsBirthDate => 'Data di nascita';

  @override
  String get settingsGender => 'Genere';

  @override
  String get settingsOptional => 'Facoltativo';

  @override
  String get settingsAdd => 'Aggiungi';

  @override
  String get settingsRemove => 'Rimuovi';

  @override
  String get genderFemale => 'Donna';

  @override
  String get genderMale => 'Uomo';

  @override
  String get genderOther => 'Altro';

  @override
  String get genderUndisclosed => 'Preferisco non dirlo';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get settingsPush => 'Notifiche push';

  @override
  String get settingsPushOn => 'Attive su questo telefono';

  @override
  String get settingsPushSoon =>
      'In arrivo: le scelte qui sotto sono già salvate.';

  @override
  String get settingsForBuyers => 'Quando cerchi';

  @override
  String get settingsForSellers => 'Quando vendi';

  @override
  String get notifNewMessage => 'Nuovi messaggi';

  @override
  String get notifPriceDrop => 'Calo di prezzo dei salvati';

  @override
  String get notifListingSold => 'Un annuncio salvato è stato venduto';

  @override
  String get notifSavedSearch => 'Nuovi annunci per le ricerche salvate';

  @override
  String get notifNewContact => 'Nuovi contatti sui tuoi annunci';

  @override
  String get notifListingExpiring => 'Annuncio in scadenza';

  @override
  String get settingsEmails => 'Email';

  @override
  String get settingsMarketingNote =>
      'Al massimo qualche email al mese. Puoi cambiare idea quando vuoi.';

  @override
  String get settingsLegal => 'Documenti e aiuto';

  @override
  String settingsAcceptedOn(String date) {
    return 'Accettati il $date';
  }

  @override
  String settingsReadOn(String date) {
    return 'Letta il $date';
  }

  @override
  String get settingsSupport => 'Contatta il supporto';

  @override
  String get settingsDeleteAccount => 'Elimina account';

  @override
  String get settingsDeleteTitle => 'Eliminare l\'account?';

  @override
  String get settingsDeleteBody =>
      'Cancelliamo il profilo, i salvati, le ricerche, i messaggi e i tuoi annunci. Non si può annullare.';

  @override
  String get settingsDeleteCta => 'Elimina definitivamente';

  @override
  String get settingsDeleted => 'Account eliminato';

  @override
  String get inboxTitle => 'Messaggi';

  @override
  String get inboxGuestTitle => 'I tuoi messaggi';

  @override
  String get inboxGuestBody =>
      'Accedi per scrivere ai venditori e ritrovare qui tutte le chat.';

  @override
  String get inboxEmptyTitle => 'Nessun messaggio';

  @override
  String get inboxEmptyBody =>
      'Quando scrivi a un venditore, la chat appare qui.';

  @override
  String get inboxExplore => 'Esplora annunci';

  @override
  String get inboxYourListing => 'Il tuo annuncio';

  @override
  String inboxYou(String text) {
    return 'Tu: $text';
  }

  @override
  String get chatPrivateSeller => 'Venditore privato';

  @override
  String get chatBuyer => 'Acquirente';

  @override
  String get chatToday => 'Oggi';

  @override
  String get chatYesterday => 'Ieri';

  @override
  String get chatNotFoundTitle => 'Chat non disponibile';

  @override
  String get chatNotFoundBody => 'Questa chat non esiste più.';

  @override
  String get chatInputHint => 'Scrivi un messaggio';

  @override
  String get chatSend => 'Invia';

  @override
  String get chatSending => 'Invio…';

  @override
  String get chatFailed => 'Non inviato · tocca per riprovare';

  @override
  String get chatDelete => 'Elimina';

  @override
  String chatNewTitle(String name) {
    return 'Scrivi a $name';
  }

  @override
  String get chatNewBody =>
      'Fai la tua domanda: la risposta arriva qui e in Inbox.';

  @override
  String get chatSafetyTip =>
      'Non pagare anticipi o caparre prima di aver visto il veicolo di persona.';

  @override
  String get chatQuickAvailable => 'È ancora disponibile?';

  @override
  String get chatQuickVisit => 'Posso vederlo dal vivo?';

  @override
  String get chatQuickPrice => 'Il prezzo è trattabile?';

  @override
  String get chatQuickTradeIn => 'Accetti permute?';

  @override
  String get chatListingSold => 'Venduto';

  @override
  String get chatListingUnavailable => 'Non più disponibile';

  @override
  String get chatSendError => 'Messaggio non inviato, riprova.';

  @override
  String get contactListingUnavailable =>
      'Questo annuncio non è più disponibile.';

  @override
  String get contactOwnListing => 'È un tuo annuncio.';

  @override
  String get contactError => 'Non riusciamo ad aprire la chat, riprova.';

  @override
  String get whatsappLabel => 'WhatsApp';

  @override
  String get whatsappNoNumber =>
      'Il venditore non ha un numero WhatsApp: scrivigli in chat.';

  @override
  String get whatsappError => 'Non riusciamo ad aprire WhatsApp.';

  @override
  String whatsappPrefill(String title, String app) {
    return 'Ciao! Ti scrivo per $title visto su $app.';
  }

  @override
  String shareText(String summary, String app, String link) {
    return '$summary\nGuarda l\'annuncio su $app: $link';
  }

  @override
  String get shareError => 'Non riusciamo ad aprire la condivisione.';

  @override
  String get sellTitle => 'Cosa vuoi vendere?';

  @override
  String get sellSubtitle =>
      'Ti guidiamo ripresa per ripresa: servono circa 5 minuti.';

  @override
  String get sellCar => 'Auto';

  @override
  String get sellCarHint => 'anche furgoni';

  @override
  String get sellMoto => 'Moto';

  @override
  String get sellMotoHint => 'anche scooter';

  @override
  String get sellBeforeTitle => 'Prima di iniziare';

  @override
  String get sellBeforeCar =>
      'Auto pulita e luce di giorno · motore pronto per l\'avviamento · se vuoi, copri la targa.';

  @override
  String get sellBeforeMoto =>
      'Moto pulita e luce di giorno · motore pronto per l\'avviamento · se vuoi, copri la targa.';

  @override
  String get sellStart => 'Inizia le riprese';

  @override
  String get sellStartNote => 'Puoi fermarti quando vuoi: salviamo la bozza';

  @override
  String get sellDraftTitle => 'Hai un annuncio in corso';

  @override
  String sellDraftBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riprese fatte',
      one: '1 ripresa fatta',
      zero: 'Nessuna ripresa ancora',
    );
    return '$_temp0';
  }

  @override
  String get sellResume => 'Riprendi';

  @override
  String get sellRestart => 'Ricomincia';

  @override
  String get sellRestartTitle => 'Ricominciare da capo?';

  @override
  String get sellRestartBody =>
      'Le riprese e i dati di questa bozza verranno eliminati.';

  @override
  String captureStepOf(int current, int total) {
    return 'Step $current di $total';
  }

  @override
  String captureVideo(int seconds) {
    return 'Video $seconds s';
  }

  @override
  String get capturePhoto => 'Foto';

  @override
  String get captureSkip => 'Salta';

  @override
  String captureNext(String step) {
    return 'Prossimo: $step';
  }

  @override
  String get captureLast => 'Ultima ripresa';

  @override
  String get capturePlateTip => 'Se vuoi, copri la targa';

  @override
  String get captureHoldStill => 'Tieni fermo il telefono';

  @override
  String captureRecording(int seconds) {
    return 'Registrazione · $seconds s';
  }

  @override
  String get captureAlignCar => 'Allinea l\'auto alla sagoma, a circa 4 metri';

  @override
  String get captureAlignMoto => 'Allinea la moto alla sagoma, a circa 3 metri';

  @override
  String get captureHintKm => 'Motore acceso: inquadra il quadro con i km';

  @override
  String get captureHintEngineBay => 'Apri il cofano e inquadra il motore';

  @override
  String get captureHintDefects =>
      'Inquadra da vicino graffi, ammaccature o usura';

  @override
  String get captureHintChain => 'Inquadra da vicino catena e battistrada';

  @override
  String get captureHintExhaust =>
      'Inquadra lo scarico, meglio a motore acceso';

  @override
  String get captureTorch => 'Torcia';

  @override
  String get captureShots => 'Le tue riprese';

  @override
  String get captureCameraDenied =>
      'Per le riprese servono fotocamera e microfono. Attivali nelle impostazioni del telefono.';

  @override
  String get captureCameraError => 'Non riusciamo ad aprire la fotocamera.';

  @override
  String get captureSaveError => 'Ripresa non salvata, riprova.';

  @override
  String get sellStepFront3q => 'Fronte 3/4';

  @override
  String get sellStepRightSide => 'Lato destro';

  @override
  String get sellStepLeftSide => 'Lato sinistro';

  @override
  String get sellStepRear => 'Posteriore';

  @override
  String get sellStepInterior => 'Interni e quadro km';

  @override
  String get sellStepEngineBay => 'Vano motore';

  @override
  String get sellStepDefects => 'Difetti visibili';

  @override
  String get sellStepTank => 'Serbatoio e quadro km';

  @override
  String get sellStepChain => 'Catena e gomme';

  @override
  String get sellStepExhaust => 'Scarico';

  @override
  String get shotsTitle => 'Le tue riprese';

  @override
  String shotsSubtitle(int done, int total) {
    return '$done di $total completate. Al resto pensiamo noi: montiamo il video e creiamo il carosello.';
  }

  @override
  String shotsVideo(int seconds) {
    return 'Video · $seconds s';
  }

  @override
  String get shotsPhoto => 'Foto';

  @override
  String get shotsTodo => 'Da fare';

  @override
  String get shotsOptional => 'Facoltativo';

  @override
  String get shotsOptionalDefects => 'Facoltativo · aumenta la fiducia';

  @override
  String get shotsEngineOn => 'motore acceso';

  @override
  String get shotsDefectsTip =>
      'Mostrare i difetti rende l\'annuncio più credibile: chi compra si fida di più.';

  @override
  String get shotsCreate => 'Crea il video';

  @override
  String get shotsCreateNote => 'Poi aggiungi prezzo, dati e descrizione';

  @override
  String shotsMissing(String steps) {
    return 'Mancano: $steps';
  }

  @override
  String get shotsNeedVideo => 'Serve almeno una ripresa video';

  @override
  String get shotsRetake => 'Rifai';

  @override
  String get shotsDelete => 'Elimina';

  @override
  String get detailsTitle => 'Dati e prezzo';

  @override
  String detailsPreparing(int percent) {
    return 'Stiamo preparando il video · $percent%';
  }

  @override
  String get detailsReady => 'Video pronto';

  @override
  String get detailsFailed => 'Video non pronto · tocca per riprovare';

  @override
  String get detailsMake => 'Marca';

  @override
  String get detailsModel => 'Modello';

  @override
  String get detailsYear => 'Anno';

  @override
  String get detailsKm => 'Chilometri';

  @override
  String get detailsFuel => 'Alimentazione';

  @override
  String get detailsMore =>
      '+ Altri dettagli (cambio, potenza, classe Euro, proprietari)';

  @override
  String get detailsLess => 'Meno dettagli';

  @override
  String get detailsVersion => 'Versione';

  @override
  String get detailsVersionHint => 'es. 1.6 TDI Life';

  @override
  String get detailsGearbox => 'Cambio';

  @override
  String get detailsPower => 'Potenza (kW)';

  @override
  String detailsPowerCv(int cv) {
    return '≈ $cv CV';
  }

  @override
  String get detailsEuro => 'Classe Euro';

  @override
  String get detailsOwners => 'Proprietari';

  @override
  String get detailsColor => 'Colore';

  @override
  String get detailsServiceHistory => 'Tagliandi documentati';

  @override
  String get detailsBodyType => 'Carrozzeria';

  @override
  String get detailsNovice => 'Adatta ai neopatentati';

  @override
  String get detailsMotoType => 'Tipo';

  @override
  String get detailsDisplacement => 'Cilindrata (cc)';

  @override
  String get detailsLicense => 'Patente';

  @override
  String get detailsPrice => 'Prezzo';

  @override
  String get detailsDescription => 'Descrizione';

  @override
  String get detailsDescriptionHint =>
      'Racconta lo stato, i tagliandi, gli extra…';

  @override
  String get detailsWhere => 'Dove si trova';

  @override
  String get detailsCity => 'Città';

  @override
  String get detailsProvince => 'Provincia';

  @override
  String get detailsWhatsapp => 'Contatto su WhatsApp';

  @override
  String get detailsWhatsappHint => 'Mostra il tuo numero a chi è interessato';

  @override
  String get detailsWhatsappDealer =>
      'Mostra il numero WhatsApp del concessionario';

  @override
  String get detailsPhone => 'Numero di telefono';

  @override
  String get detailsSellerAge =>
      'Ho almeno 18 anni, oppure vendo con il consenso di un genitore';

  @override
  String get detailsPublish => 'Pubblica annuncio';

  @override
  String get detailsPublishing => 'Pubblicazione…';

  @override
  String get detailsRequired => 'Obbligatorio';

  @override
  String detailsInvalidYear(int max) {
    return 'Tra 1950 e $max';
  }

  @override
  String get detailsInvalidPhone => 'Numero non valido';

  @override
  String get detailsChoose => 'Scegli';

  @override
  String get detailsSearchMake => 'Cerca marca';

  @override
  String get detailsSearchModel => 'Cerca modello';

  @override
  String get detailsChooseMakeFirst => 'Prima scegli la marca';

  @override
  String get detailsFixFields => 'Completa i campi evidenziati';

  @override
  String get publishErrorIncomplete => 'Mancano alcuni dati obbligatori.';

  @override
  String get publishErrorMedia =>
      'Il video non è ancora caricato: riprova tra poco.';

  @override
  String get publishErrorNetwork => 'Connessione assente o lenta: riprova.';

  @override
  String get publishError => 'Non siamo riusciti a pubblicare, riprova.';

  @override
  String doneTitle(String model) {
    return 'La tua $model è online';
  }

  @override
  String get doneTitleGeneric => 'Il tuo annuncio è online';

  @override
  String doneBody(int weeks) {
    return 'Ti avvisiamo a ogni nuovo contatto. Tra $weeks settimane ti chiederemo se è ancora disponibile.';
  }

  @override
  String get doneShare => 'Condividi il link';

  @override
  String get doneOpen => 'Vedi l\'annuncio';

  @override
  String get bodyCityCar => 'Citycar';

  @override
  String get bodyHatchback => 'Due volumi';

  @override
  String get bodySedan => 'Berlina';

  @override
  String get bodyStationWagon => 'Station wagon';

  @override
  String get bodySuv => 'SUV';

  @override
  String get bodyCoupe => 'Coupé';

  @override
  String get bodyConvertible => 'Cabrio';

  @override
  String get bodyMinivan => 'Monovolume';

  @override
  String get bodyVan => 'Furgone';

  @override
  String get bodyPickup => 'Pick-up';

  @override
  String get motoNaked => 'Naked';

  @override
  String get motoSport => 'Sportiva';

  @override
  String get motoTouring => 'Turismo';

  @override
  String get motoAdventure => 'Adventure';

  @override
  String get motoEnduro => 'Enduro';

  @override
  String get motoCross => 'Cross';

  @override
  String get motoCustom => 'Custom';

  @override
  String get motoScooter => 'Scooter';

  @override
  String get motoMotard => 'Motard';

  @override
  String get captureRecord => 'Registra';

  @override
  String get captureTakePhoto => 'Scatta';
}
