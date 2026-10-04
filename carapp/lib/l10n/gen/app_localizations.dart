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

  /// No description provided for @loginPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In it, this message translates to:
  /// **'Almeno {min} caratteri'**
  String loginPasswordHint(int min);

  /// No description provided for @loginShowPassword.
  ///
  /// In it, this message translates to:
  /// **'Mostra password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In it, this message translates to:
  /// **'Nascondi password'**
  String get loginHidePassword;

  /// No description provided for @loginSignIn.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get loginSignIn;

  /// No description provided for @loginSignUp.
  ///
  /// In it, this message translates to:
  /// **'Crea account'**
  String get loginSignUp;

  /// No description provided for @loginSignUpTitle.
  ///
  /// In it, this message translates to:
  /// **'Crea il tuo account'**
  String get loginSignUpTitle;

  /// No description provided for @loginToSignUp.
  ///
  /// In it, this message translates to:
  /// **'Non hai un account? Registrati'**
  String get loginToSignUp;

  /// No description provided for @loginToSignIn.
  ///
  /// In it, this message translates to:
  /// **'Hai già un account? Accedi'**
  String get loginToSignIn;

  /// No description provided for @loginConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Conferma la tua email'**
  String get loginConfirmTitle;

  /// No description provided for @loginConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'Ti abbiamo mandato un link a {email}. Aprilo per attivare l\'account, poi accedi.'**
  String loginConfirmBody(String email);

  /// No description provided for @loginErrorPassword.
  ///
  /// In it, this message translates to:
  /// **'La password deve avere almeno {min} caratteri.'**
  String loginErrorPassword(int min);

  /// No description provided for @loginErrorCredentials.
  ///
  /// In it, this message translates to:
  /// **'Email o password non corretti.'**
  String get loginErrorCredentials;

  /// No description provided for @loginErrorExists.
  ///
  /// In it, this message translates to:
  /// **'Esiste già un account con questa email: accedi.'**
  String get loginErrorExists;

  /// No description provided for @loginErrorWeak.
  ///
  /// In it, this message translates to:
  /// **'Password troppo debole, scegline una più lunga.'**
  String get loginErrorWeak;

  /// No description provided for @loginErrorNotConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Prima conferma l\'email che ti abbiamo mandato.'**
  String get loginErrorNotConfirmed;

  /// No description provided for @loginErrorRateLimit.
  ///
  /// In it, this message translates to:
  /// **'Troppi tentativi, riprova tra qualche minuto.'**
  String get loginErrorRateLimit;

  /// No description provided for @loginErrorGeneric.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa è andato storto, riprova.'**
  String get loginErrorGeneric;

  /// No description provided for @loginErrorEmail.
  ///
  /// In it, this message translates to:
  /// **'Controlla l\'indirizzo email.'**
  String get loginErrorEmail;

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

  /// No description provided for @errorTitle.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa è andato storto'**
  String get errorTitle;

  /// No description provided for @errorBody.
  ///
  /// In it, this message translates to:
  /// **'Controlla la connessione e riprova.'**
  String get errorBody;

  /// No description provided for @commonYes.
  ///
  /// In it, this message translates to:
  /// **'Sì'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In it, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @fuelPetrol.
  ///
  /// In it, this message translates to:
  /// **'Benzina'**
  String get fuelPetrol;

  /// No description provided for @fuelDiesel.
  ///
  /// In it, this message translates to:
  /// **'Diesel'**
  String get fuelDiesel;

  /// No description provided for @fuelHybrid.
  ///
  /// In it, this message translates to:
  /// **'Ibrida'**
  String get fuelHybrid;

  /// No description provided for @fuelPluginHybrid.
  ///
  /// In it, this message translates to:
  /// **'Ibrida plug-in'**
  String get fuelPluginHybrid;

  /// No description provided for @fuelElectric.
  ///
  /// In it, this message translates to:
  /// **'Elettrica'**
  String get fuelElectric;

  /// No description provided for @fuelLpg.
  ///
  /// In it, this message translates to:
  /// **'GPL'**
  String get fuelLpg;

  /// No description provided for @fuelCng.
  ///
  /// In it, this message translates to:
  /// **'Metano'**
  String get fuelCng;

  /// No description provided for @fuelOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get fuelOther;

  /// No description provided for @transmissionManual.
  ///
  /// In it, this message translates to:
  /// **'Manuale'**
  String get transmissionManual;

  /// No description provided for @transmissionAutomatic.
  ///
  /// In it, this message translates to:
  /// **'Automatico'**
  String get transmissionAutomatic;

  /// No description provided for @transmissionSemiAutomatic.
  ///
  /// In it, this message translates to:
  /// **'Semiautomatico'**
  String get transmissionSemiAutomatic;

  /// No description provided for @listingNotFoundTitle.
  ///
  /// In it, this message translates to:
  /// **'Annuncio non disponibile'**
  String get listingNotFoundTitle;

  /// No description provided for @listingNotFoundBody.
  ///
  /// In it, this message translates to:
  /// **'Potrebbe essere stato venduto o rimosso dal venditore.'**
  String get listingNotFoundBody;

  /// No description provided for @listingBackToFeed.
  ///
  /// In it, this message translates to:
  /// **'Torna al feed'**
  String get listingBackToFeed;

  /// No description provided for @listingPhotos.
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get listingPhotos;

  /// No description provided for @listingSpecs.
  ///
  /// In it, this message translates to:
  /// **'Caratteristiche'**
  String get listingSpecs;

  /// No description provided for @specYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get specYear;

  /// No description provided for @specMileage.
  ///
  /// In it, this message translates to:
  /// **'Chilometri'**
  String get specMileage;

  /// No description provided for @specFuel.
  ///
  /// In it, this message translates to:
  /// **'Alimentazione'**
  String get specFuel;

  /// No description provided for @specTransmission.
  ///
  /// In it, this message translates to:
  /// **'Cambio'**
  String get specTransmission;

  /// No description provided for @specPower.
  ///
  /// In it, this message translates to:
  /// **'Potenza'**
  String get specPower;

  /// No description provided for @specEuroClass.
  ///
  /// In it, this message translates to:
  /// **'Classe ambientale'**
  String get specEuroClass;

  /// No description provided for @specEuroValue.
  ///
  /// In it, this message translates to:
  /// **'Euro {euro}'**
  String specEuroValue(int euro);

  /// No description provided for @specColor.
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get specColor;

  /// No description provided for @specOwners.
  ///
  /// In it, this message translates to:
  /// **'Proprietari'**
  String get specOwners;

  /// No description provided for @specServiceHistory.
  ///
  /// In it, this message translates to:
  /// **'Tagliandi documentati'**
  String get specServiceHistory;

  /// No description provided for @specWarranty.
  ///
  /// In it, this message translates to:
  /// **'Garanzia'**
  String get specWarranty;

  /// No description provided for @specWarrantyMonths.
  ///
  /// In it, this message translates to:
  /// **'{months, plural, =1{1 mese} other{{months} mesi}}'**
  String specWarrantyMonths(int months);

  /// No description provided for @listingDescription.
  ///
  /// In it, this message translates to:
  /// **'Descrizione'**
  String get listingDescription;

  /// No description provided for @listingShowMore.
  ///
  /// In it, this message translates to:
  /// **'Mostra tutto'**
  String get listingShowMore;

  /// No description provided for @listingShowLess.
  ///
  /// In it, this message translates to:
  /// **'Mostra meno'**
  String get listingShowLess;

  /// No description provided for @costTitle.
  ///
  /// In it, this message translates to:
  /// **'Quanto spendi davvero'**
  String get costTitle;

  /// No description provided for @costPrice.
  ///
  /// In it, this message translates to:
  /// **'Prezzo'**
  String get costPrice;

  /// No description provided for @costTransfer.
  ///
  /// In it, this message translates to:
  /// **'Passaggio di proprietà (stima)'**
  String get costTransfer;

  /// No description provided for @costTotal.
  ///
  /// In it, this message translates to:
  /// **'Totale stimato'**
  String get costTotal;

  /// No description provided for @costNote.
  ///
  /// In it, this message translates to:
  /// **'Stima indicativa: imposta provinciale con la maggiorazione massima più i diritti fissi. Dai concessionari il passaggio può essere già incluso nel prezzo.'**
  String get costNote;

  /// No description provided for @sellerTitle.
  ///
  /// In it, this message translates to:
  /// **'Venditore'**
  String get sellerTitle;

  /// No description provided for @sellerPrivate.
  ///
  /// In it, this message translates to:
  /// **'Venditore privato'**
  String get sellerPrivate;

  /// No description provided for @sellerDealer.
  ///
  /// In it, this message translates to:
  /// **'Concessionario'**
  String get sellerDealer;

  /// No description provided for @sellerVatVerified.
  ///
  /// In it, this message translates to:
  /// **'Partita IVA verificata'**
  String get sellerVatVerified;

  /// No description provided for @reviewsTitle.
  ///
  /// In it, this message translates to:
  /// **'Recensioni'**
  String get reviewsTitle;

  /// No description provided for @reviewsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna recensione} =1{1 recensione} other{{count} recensioni}}'**
  String reviewsCount(int count);

  /// No description provided for @qaTitle.
  ///
  /// In it, this message translates to:
  /// **'Domande e risposte'**
  String get qaTitle;

  /// No description provided for @qaEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna domanda per ora. Chiedi tu per primo.'**
  String get qaEmpty;

  /// No description provided for @qaAsk.
  ///
  /// In it, this message translates to:
  /// **'Fai una domanda'**
  String get qaAsk;

  /// No description provided for @qaPending.
  ///
  /// In it, this message translates to:
  /// **'In attesa di risposta'**
  String get qaPending;

  /// No description provided for @qaYourQuestion.
  ///
  /// In it, this message translates to:
  /// **'La tua domanda'**
  String get qaYourQuestion;

  /// No description provided for @qaHint.
  ///
  /// In it, this message translates to:
  /// **'Es. ha mai avuto incidenti?'**
  String get qaHint;

  /// No description provided for @qaNote.
  ///
  /// In it, this message translates to:
  /// **'Il venditore può rendere pubblica la risposta per tutti.'**
  String get qaNote;

  /// No description provided for @qaSend.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get qaSend;

  /// No description provided for @qaSent.
  ///
  /// In it, this message translates to:
  /// **'Domanda inviata al venditore'**
  String get qaSent;

  /// No description provided for @qaError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a inviare la domanda, riprova.'**
  String get qaError;

  /// No description provided for @qaLoginTitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi per fare una domanda'**
  String get qaLoginTitle;

  /// No description provided for @qaLoginSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Il venditore riceve la tua domanda e ti risponde qui.'**
  String get qaLoginSubtitle;

  /// No description provided for @savedTitle.
  ///
  /// In it, this message translates to:
  /// **'Salvati'**
  String get savedTitle;

  /// No description provided for @savedLabel.
  ///
  /// In it, this message translates to:
  /// **'Salvato'**
  String get savedLabel;

  /// No description provided for @savedEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non hai ancora salvato niente. Tocca Salva su un annuncio per ritrovarlo qui.'**
  String get savedEmpty;

  /// No description provided for @savedAdded.
  ///
  /// In it, this message translates to:
  /// **'Salvato. Lo ritrovi nel profilo.'**
  String get savedAdded;

  /// No description provided for @savedRemoved.
  ///
  /// In it, this message translates to:
  /// **'Rimosso dai salvati'**
  String get savedRemoved;

  /// No description provided for @savedError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a salvare, riprova.'**
  String get savedError;

  /// No description provided for @savedUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Non più disponibile'**
  String get savedUnavailable;

  /// No description provided for @savedRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dai salvati'**
  String get savedRemove;

  /// No description provided for @savedPriceDrop.
  ///
  /// In it, this message translates to:
  /// **'Sceso di {amount}'**
  String savedPriceDrop(String amount);

  /// No description provided for @commonRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get commonRefresh;

  /// No description provided for @feedEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Ancora nessun annuncio'**
  String get feedEmptyTitle;

  /// No description provided for @feedEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Torna tra poco: stiamo caricando i primi veicoli.'**
  String get feedEmptyBody;

  /// No description provided for @feedEmptyFilteredTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun annuncio con questi filtri'**
  String get feedEmptyFilteredTitle;

  /// No description provided for @feedEmptyFilteredBody.
  ///
  /// In it, this message translates to:
  /// **'Prova ad allargare la ricerca: togli un filtro o alza il budget.'**
  String get feedEmptyFilteredBody;

  /// No description provided for @filterTitle.
  ///
  /// In it, this message translates to:
  /// **'Filtri'**
  String get filterTitle;

  /// No description provided for @filterPrice.
  ///
  /// In it, this message translates to:
  /// **'Prezzo'**
  String get filterPrice;

  /// No description provided for @filterBrand.
  ///
  /// In it, this message translates to:
  /// **'Marca'**
  String get filterBrand;

  /// No description provided for @filterBrands.
  ///
  /// In it, this message translates to:
  /// **'Marche'**
  String get filterBrands;

  /// No description provided for @filterBrandCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 marca} other{{count} marche}}'**
  String filterBrandCount(int count);

  /// No description provided for @filterYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get filterYear;

  /// No description provided for @filterMileage.
  ///
  /// In it, this message translates to:
  /// **'Km'**
  String get filterMileage;

  /// No description provided for @filterReset.
  ///
  /// In it, this message translates to:
  /// **'Azzera'**
  String get filterReset;

  /// No description provided for @filterApply.
  ///
  /// In it, this message translates to:
  /// **'Mostra annunci'**
  String get filterApply;

  /// No description provided for @filterClearAll.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi i filtri'**
  String get filterClearAll;

  /// No description provided for @filterEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica filtri'**
  String get filterEdit;

  /// No description provided for @searchResults.
  ///
  /// In it, this message translates to:
  /// **'Risultati'**
  String get searchResults;

  /// No description provided for @searchNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun annuncio con questi filtri. Prova ad allargare la ricerca.'**
  String get searchNoResults;

  /// No description provided for @searchLoadMore.
  ///
  /// In it, this message translates to:
  /// **'Carica altri'**
  String get searchLoadMore;

  /// No description provided for @searchShowInFeed.
  ///
  /// In it, this message translates to:
  /// **'Guarda nel feed'**
  String get searchShowInFeed;

  /// No description provided for @searchSave.
  ///
  /// In it, this message translates to:
  /// **'Salva ricerca'**
  String get searchSave;

  /// No description provided for @searchSavedTitle.
  ///
  /// In it, this message translates to:
  /// **'Ricerche salvate'**
  String get searchSavedTitle;

  /// No description provided for @searchNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome della ricerca'**
  String get searchNameLabel;

  /// No description provided for @searchNotify.
  ///
  /// In it, this message translates to:
  /// **'Avvisami quando arrivano annunci nuovi'**
  String get searchNotify;

  /// No description provided for @searchSavedDone.
  ///
  /// In it, this message translates to:
  /// **'Ricerca salvata'**
  String get searchSavedDone;

  /// No description provided for @searchDeleted.
  ///
  /// In it, this message translates to:
  /// **'Ricerca eliminata'**
  String get searchDeleted;

  /// No description provided for @searchDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get searchDelete;

  /// No description provided for @searchMore.
  ///
  /// In it, this message translates to:
  /// **'Altre azioni'**
  String get searchMore;

  /// No description provided for @searchNotifyOn.
  ///
  /// In it, this message translates to:
  /// **'Avvisi attivi'**
  String get searchNotifyOn;

  /// No description provided for @searchNotifyOff.
  ///
  /// In it, this message translates to:
  /// **'Avvisi spenti'**
  String get searchNotifyOff;

  /// No description provided for @searchError.
  ///
  /// In it, this message translates to:
  /// **'Operazione non riuscita, riprova.'**
  String get searchError;

  /// No description provided for @searchLoginTitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi per salvare la ricerca'**
  String get searchLoginTitle;

  /// No description provided for @searchLoginSubtitle.
  ///
  /// In it, this message translates to:
  /// **'La ritrovi qui con un tocco, su qualsiasi telefono.'**
  String get searchLoginSubtitle;

  /// No description provided for @searchAllVehicles.
  ///
  /// In it, this message translates to:
  /// **'Tutti i veicoli'**
  String get searchAllVehicles;
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
