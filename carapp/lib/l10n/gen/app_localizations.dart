import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('it')];

  /// Code name, replaced when the brand is decided
  ///
  /// In it, this message translates to:
  /// **'Carfeed'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In it, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get navSearch;

  /// No description provided for @navSell.
  ///
  /// In it, this message translates to:
  /// **'Vendi'**
  String get navSell;

  /// No description provided for @navInbox.
  ///
  /// In it, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @navProfile.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get navProfile;

  /// No description provided for @commonContinue.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In it, this message translates to:
  /// **'Salta'**
  String get commonSkip;

  /// No description provided for @commonNotNow.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get commonNotNow;

  /// No description provided for @commonAll.
  ///
  /// In it, this message translates to:
  /// **'Tutte'**
  String get commonAll;

  /// No description provided for @commonAny.
  ///
  /// In it, this message translates to:
  /// **'Qualsiasi'**
  String get commonAny;

  /// No description provided for @commonSave.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get commonSave;

  /// No description provided for @commonShare.
  ///
  /// In it, this message translates to:
  /// **'Condividi'**
  String get commonShare;

  /// No description provided for @commonContact.
  ///
  /// In it, this message translates to:
  /// **'Contatta'**
  String get commonContact;

  /// No description provided for @commonDone.
  ///
  /// In it, this message translates to:
  /// **'Fatto'**
  String get commonDone;

  /// No description provided for @commonClose.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get commonRetry;

  /// No description provided for @comingSoon.
  ///
  /// In it, this message translates to:
  /// **'{feature}: in arrivo'**
  String comingSoon(String feature);

  /// No description provided for @onboardingTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa vuoi fare?'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli una cosa, il resto lo sistemiamo strada facendo.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingHaveAccount.
  ///
  /// In it, this message translates to:
  /// **'Hai già un account?'**
  String get onboardingHaveAccount;

  /// No description provided for @onboardingLogin.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get onboardingLogin;

  /// No description provided for @intentBuy.
  ///
  /// In it, this message translates to:
  /// **'Voglio comprare'**
  String get intentBuy;

  /// No description provided for @intentBuySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Un\'auto o una moto, nuova per te'**
  String get intentBuySubtitle;

  /// No description provided for @intentSell.
  ///
  /// In it, this message translates to:
  /// **'Voglio vendere'**
  String get intentSell;

  /// No description provided for @intentSellSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Pubblica il tuo veicolo in 5 minuti'**
  String get intentSellSubtitle;

  /// No description provided for @intentDealer.
  ///
  /// In it, this message translates to:
  /// **'Sono un concessionario'**
  String get intentDealer;

  /// No description provided for @intentDealerSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Porta il tuo stock nel feed'**
  String get intentDealerSubtitle;

  /// No description provided for @intentBrowse.
  ///
  /// In it, this message translates to:
  /// **'Sto solo guardando'**
  String get intentBrowse;

  /// No description provided for @intentBrowseSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun impegno, scrolla e basta'**
  String get intentBrowseSubtitle;

  /// No description provided for @prefsTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa cerchi?'**
  String get prefsTitle;

  /// No description provided for @prefsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Tutto facoltativo. Anche una sola scelta ci aiuta.'**
  String get prefsSubtitle;

  /// No description provided for @prefsVehicle.
  ///
  /// In it, this message translates to:
  /// **'Veicolo'**
  String get prefsVehicle;

  /// No description provided for @prefsBudget.
  ///
  /// In it, this message translates to:
  /// **'Budget'**
  String get prefsBudget;

  /// No description provided for @prefsBrands.
  ///
  /// In it, this message translates to:
  /// **'Marche preferite'**
  String get prefsBrands;

  /// No description provided for @prefsYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get prefsYear;

  /// No description provided for @prefsMileage.
  ///
  /// In it, this message translates to:
  /// **'Chilometri'**
  String get prefsMileage;

  /// No description provided for @prefsNovice.
  ///
  /// In it, this message translates to:
  /// **'Sono neopatentato'**
  String get prefsNovice;

  /// No description provided for @prefsNoviceSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Ti mostriamo prima i veicoli che puoi guidare'**
  String get prefsNoviceSubtitle;

  /// No description provided for @prefsCta.
  ///
  /// In it, this message translates to:
  /// **'Mostrami i veicoli'**
  String get prefsCta;

  /// No description provided for @prefsSaveCta.
  ///
  /// In it, this message translates to:
  /// **'Salva preferenze'**
  String get prefsSaveCta;

  /// No description provided for @prefsFootnote.
  ///
  /// In it, this message translates to:
  /// **'Puoi cambiare tutto quando vuoi dal profilo'**
  String get prefsFootnote;

  /// No description provided for @vehicleAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get vehicleAll;

  /// No description provided for @vehicleCar.
  ///
  /// In it, this message translates to:
  /// **'Auto'**
  String get vehicleCar;

  /// No description provided for @vehicleMotorcycle.
  ///
  /// In it, this message translates to:
  /// **'Moto'**
  String get vehicleMotorcycle;

  /// No description provided for @moreBrands.
  ///
  /// In it, this message translates to:
  /// **'+ Altre'**
  String get moreBrands;

  /// No description provided for @brandsSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Tutte le marche'**
  String get brandsSheetTitle;

  /// No description provided for @budgetUpTo.
  ///
  /// In it, this message translates to:
  /// **'Fino a {amount}'**
  String budgetUpTo(String amount);

  /// No description provided for @budgetOver.
  ///
  /// In it, this message translates to:
  /// **'Oltre {amount}'**
  String budgetOver(String amount);

  /// No description provided for @yearFrom.
  ///
  /// In it, this message translates to:
  /// **'Dal {year}'**
  String yearFrom(String year);

  /// No description provided for @mileageMax.
  ///
  /// In it, this message translates to:
  /// **'Max {km} km'**
  String mileageMax(String km);

  /// No description provided for @dealerTitle.
  ///
  /// In it, this message translates to:
  /// **'Il tuo salone'**
  String get dealerTitle;

  /// No description provided for @dealerSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Ci basta la partita IVA: il resto lo recuperiamo noi.'**
  String get dealerSubtitle;

  /// No description provided for @dealerLoginNeeded.
  ///
  /// In it, this message translates to:
  /// **'Prima accedi con la tua email: il salone sarà collegato al tuo account.'**
  String get dealerLoginNeeded;

  /// No description provided for @dealerLoginCta.
  ///
  /// In it, this message translates to:
  /// **'Accedi per continuare'**
  String get dealerLoginCta;

  /// No description provided for @dealerVatLabel.
  ///
  /// In it, this message translates to:
  /// **'Partita IVA'**
  String get dealerVatLabel;

  /// No description provided for @dealerNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome mostrato nell\'app'**
  String get dealerNameLabel;

  /// No description provided for @dealerTrialTitle.
  ///
  /// In it, this message translates to:
  /// **'Gratis per 3 mesi'**
  String get dealerTrialTitle;

  /// No description provided for @dealerTrialBody.
  ///
  /// In it, this message translates to:
  /// **'Poi resta gratis fino al sesto mese, finché non superi 30 contatti in totale. Dopo, € 29/mese bloccati per sempre. Nessuna carta richiesta.'**
  String get dealerTrialBody;

  /// No description provided for @dealerCta.
  ///
  /// In it, this message translates to:
  /// **'Crea il profilo del salone'**
  String get dealerCta;

  /// No description provided for @dealerCreated.
  ///
  /// In it, this message translates to:
  /// **'Salone creato'**
  String get dealerCreated;

  /// No description provided for @dealerErrorInvalidVat.
  ///
  /// In it, this message translates to:
  /// **'Partita IVA non valida o non attiva.'**
  String get dealerErrorInvalidVat;

  /// No description provided for @dealerErrorTaken.
  ///
  /// In it, this message translates to:
  /// **'Questa partita IVA è già registrata.'**
  String get dealerErrorTaken;

  /// No description provided for @dealerErrorVies.
  ///
  /// In it, this message translates to:
  /// **'Il servizio di verifica non risponde, riprova tra poco.'**
  String get dealerErrorVies;

  /// No description provided for @dealerErrorGeneric.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa è andato storto, riprova.'**
  String get dealerErrorGeneric;

  /// No description provided for @loginTitle.
  ///
  /// In it, this message translates to:
  /// **'Ti piace qualcosa?'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi per salvare le auto, ricevere un avviso se calano di prezzo e scrivere ai venditori.'**
  String get loginSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In it, this message translates to:
  /// **'La tua email'**
  String get loginEmailLabel;

  /// No description provided for @loginSendCode.
  ///
  /// In it, this message translates to:
  /// **'Mandami il codice'**
  String get loginSendCode;

  /// No description provided for @loginCodeTitle.
  ///
  /// In it, this message translates to:
  /// **'Controlla la tua email'**
  String get loginCodeTitle;

  /// No description provided for @loginCodeSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Abbiamo mandato un codice a {email}'**
  String loginCodeSubtitle(String email);

  /// No description provided for @loginCodeLabel.
  ///
  /// In it, this message translates to:
  /// **'Codice'**
  String get loginCodeLabel;

  /// No description provided for @loginVerify.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get loginVerify;

  /// No description provided for @loginResend.
  ///
  /// In it, this message translates to:
  /// **'Rimanda il codice'**
  String get loginResend;

  /// No description provided for @loginChangeEmail.
  ///
  /// In it, this message translates to:
  /// **'Cambia email'**
  String get loginChangeEmail;

  /// No description provided for @loginErrorEmail.
  ///
  /// In it, this message translates to:
  /// **'Controlla l\'indirizzo email.'**
  String get loginErrorEmail;

  /// No description provided for @loginErrorCode.
  ///
  /// In it, this message translates to:
  /// **'Codice non valido o scaduto.'**
  String get loginErrorCode;

  /// No description provided for @loginErrorSend.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a inviare il codice, riprova tra poco.'**
  String get loginErrorSend;

  /// No description provided for @loginTerms.
  ///
  /// In it, this message translates to:
  /// **'Continuando accetti i Termini e l\'Informativa privacy.'**
  String get loginTerms;

  /// No description provided for @profileGuestTitle.
  ///
  /// In it, this message translates to:
  /// **'Ciao!'**
  String get profileGuestTitle;

  /// No description provided for @profileGuestSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi per salvare auto e ricerche'**
  String get profileGuestSubtitle;

  /// No description provided for @profileLogin.
  ///
  /// In it, this message translates to:
  /// **'Accedi o registrati'**
  String get profileLogin;

  /// No description provided for @profileLogout.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get profileLogout;

  /// No description provided for @profileWhatILookFor.
  ///
  /// In it, this message translates to:
  /// **'Cosa cerco'**
  String get profileWhatILookFor;

  /// No description provided for @profileEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get profileEdit;

  /// No description provided for @profileNoPreferences.
  ///
  /// In it, this message translates to:
  /// **'Dicci budget e marche: il feed ti mostrerà prima i veicoli giusti.'**
  String get profileNoPreferences;

  /// No description provided for @profileSetPreferences.
  ///
  /// In it, this message translates to:
  /// **'Imposta in 30 secondi'**
  String get profileSetPreferences;

  /// No description provided for @profilePrefsGuest.
  ///
  /// In it, this message translates to:
  /// **'Registrati per salvare cosa cerchi: il feed ti mostrerà prima i veicoli giusti e ti avviseremo quando arrivano.'**
  String get profilePrefsGuest;

  /// No description provided for @profilePrefsGuestCta.
  ///
  /// In it, this message translates to:
  /// **'Registrati e imposta'**
  String get profilePrefsGuestCta;

  /// No description provided for @priceBelowAverage.
  ///
  /// In it, this message translates to:
  /// **'{percent}% sotto la media'**
  String priceBelowAverage(int percent);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
