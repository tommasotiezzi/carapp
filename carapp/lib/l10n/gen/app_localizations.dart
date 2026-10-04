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

  /// No description provided for @searchHint.
  ///
  /// In it, this message translates to:
  /// **'Es. golf diesel dal 2018 sotto 15mila'**
  String get searchHint;

  /// No description provided for @searchClear.
  ///
  /// In it, this message translates to:
  /// **'Cancella'**
  String get searchClear;

  /// No description provided for @searchRemoveChip.
  ///
  /// In it, this message translates to:
  /// **'Togli {label}'**
  String searchRemoveChip(String label);

  /// No description provided for @searchIgnored.
  ///
  /// In it, this message translates to:
  /// **'Parole non usate: {words}'**
  String searchIgnored(String words);

  /// No description provided for @searchRecent.
  ///
  /// In it, this message translates to:
  /// **'Ricerche recenti'**
  String get searchRecent;

  /// No description provided for @searchClearRecent.
  ///
  /// In it, this message translates to:
  /// **'Cancella tutto'**
  String get searchClearRecent;

  /// No description provided for @searchPopularBrands.
  ///
  /// In it, this message translates to:
  /// **'Marche popolari'**
  String get searchPopularBrands;

  /// No description provided for @searchZeroTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun annuncio trovato'**
  String get searchZeroTitle;

  /// No description provided for @searchTryWithout.
  ///
  /// In it, this message translates to:
  /// **'Prova senza «{label}»'**
  String searchTryWithout(String label);

  /// No description provided for @searchSaveAndNotify.
  ///
  /// In it, this message translates to:
  /// **'Salva ricerca e avvisami'**
  String get searchSaveAndNotify;

  /// No description provided for @searchTapHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca un annuncio per aprirlo, oppure guardali tutti nel feed.'**
  String get searchTapHint;

  /// No description provided for @priceUpTo.
  ///
  /// In it, this message translates to:
  /// **'Fino a {price}'**
  String priceUpTo(String price);

  /// No description provided for @priceFrom.
  ///
  /// In it, this message translates to:
  /// **'Da {price}'**
  String priceFrom(String price);

  /// No description provided for @yearUntil.
  ///
  /// In it, this message translates to:
  /// **'Fino al {year}'**
  String yearUntil(String year);

  /// No description provided for @filterModelCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 modello} other{{count} modelli}}'**
  String filterModelCount(int count);

  /// No description provided for @filterNovice.
  ///
  /// In it, this message translates to:
  /// **'Neopatentati'**
  String get filterNovice;

  /// No description provided for @filterNoviceNote.
  ///
  /// In it, this message translates to:
  /// **'Auto fino a {kw} kW, il limite di legge. Il rapporto peso/potenza va verificato: il peso non è tra i dati dell\'annuncio.'**
  String filterNoviceNote(int kw);

  /// No description provided for @legalTerms.
  ///
  /// In it, this message translates to:
  /// **'Termini e condizioni'**
  String get legalTerms;

  /// No description provided for @legalPrivacy.
  ///
  /// In it, this message translates to:
  /// **'Informativa privacy'**
  String get legalPrivacy;

  /// No description provided for @legalRead.
  ///
  /// In it, this message translates to:
  /// **'Leggi'**
  String get legalRead;

  /// No description provided for @legalOpenError.
  ///
  /// In it, this message translates to:
  /// **'Non riusciamo ad aprire il documento, riprova.'**
  String get legalOpenError;

  /// No description provided for @consentTermsAge.
  ///
  /// In it, this message translates to:
  /// **'Ho almeno {age} anni e accetto i Termini e condizioni'**
  String consentTermsAge(int age);

  /// No description provided for @consentPrivacy.
  ///
  /// In it, this message translates to:
  /// **'Ho letto l\'Informativa privacy'**
  String get consentPrivacy;

  /// No description provided for @consentMarketing.
  ///
  /// In it, this message translates to:
  /// **'Voglio ricevere email con novità e offerte'**
  String get consentMarketing;

  /// No description provided for @consentRequired.
  ///
  /// In it, this message translates to:
  /// **'Per creare l\'account servono le prime due spunte.'**
  String get consentRequired;

  /// No description provided for @consentTitle.
  ///
  /// In it, this message translates to:
  /// **'Prima di continuare'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In it, this message translates to:
  /// **'Per usare il tuo account conferma di aver letto Termini e Informativa privacy.'**
  String get consentBody;

  /// No description provided for @consentUpdatedTitle.
  ///
  /// In it, this message translates to:
  /// **'Abbiamo aggiornato i documenti'**
  String get consentUpdatedTitle;

  /// No description provided for @consentUpdatedBody.
  ///
  /// In it, this message translates to:
  /// **'Termini e Informativa privacy sono cambiati: dai un\'occhiata e conferma per continuare.'**
  String get consentUpdatedBody;

  /// No description provided for @consentAccept.
  ///
  /// In it, this message translates to:
  /// **'Accetta e continua'**
  String get consentAccept;

  /// No description provided for @settingsTitle.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTitle;

  /// No description provided for @settingsGuest.
  ///
  /// In it, this message translates to:
  /// **'Accedi per gestire account, notifiche ed email.'**
  String get settingsGuest;

  /// No description provided for @settingsAccount.
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsEmail.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// No description provided for @settingsChangeEmail.
  ///
  /// In it, this message translates to:
  /// **'Cambia email'**
  String get settingsChangeEmail;

  /// No description provided for @settingsNewEmail.
  ///
  /// In it, this message translates to:
  /// **'Nuova email'**
  String get settingsNewEmail;

  /// No description provided for @settingsCurrentPassword.
  ///
  /// In it, this message translates to:
  /// **'Password attuale'**
  String get settingsCurrentPassword;

  /// No description provided for @settingsEmailChanged.
  ///
  /// In it, this message translates to:
  /// **'Email aggiornata'**
  String get settingsEmailChanged;

  /// No description provided for @settingsEmailConfirm.
  ///
  /// In it, this message translates to:
  /// **'Ti abbiamo mandato un link per confermare la nuova email.'**
  String get settingsEmailConfirm;

  /// No description provided for @settingsChangePassword.
  ///
  /// In it, this message translates to:
  /// **'Cambia password'**
  String get settingsChangePassword;

  /// No description provided for @settingsNewPassword.
  ///
  /// In it, this message translates to:
  /// **'Nuova password'**
  String get settingsNewPassword;

  /// No description provided for @settingsPasswordChanged.
  ///
  /// In it, this message translates to:
  /// **'Password aggiornata'**
  String get settingsPasswordChanged;

  /// No description provided for @settingsAboutYou.
  ///
  /// In it, this message translates to:
  /// **'Su di te'**
  String get settingsAboutYou;

  /// No description provided for @settingsAboutYouNote.
  ///
  /// In it, this message translates to:
  /// **'Tutto facoltativo: puoi lasciarlo vuoto o toglierlo quando vuoi.'**
  String get settingsAboutYouNote;

  /// No description provided for @settingsDisplayName.
  ///
  /// In it, this message translates to:
  /// **'Nome visualizzato'**
  String get settingsDisplayName;

  /// No description provided for @settingsBirthDate.
  ///
  /// In it, this message translates to:
  /// **'Data di nascita'**
  String get settingsBirthDate;

  /// No description provided for @settingsGender.
  ///
  /// In it, this message translates to:
  /// **'Genere'**
  String get settingsGender;

  /// No description provided for @settingsOptional.
  ///
  /// In it, this message translates to:
  /// **'Facoltativo'**
  String get settingsOptional;

  /// No description provided for @settingsAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get settingsAdd;

  /// No description provided for @settingsRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get settingsRemove;

  /// No description provided for @genderFemale.
  ///
  /// In it, this message translates to:
  /// **'Donna'**
  String get genderFemale;

  /// No description provided for @genderMale.
  ///
  /// In it, this message translates to:
  /// **'Uomo'**
  String get genderMale;

  /// No description provided for @genderOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get genderOther;

  /// No description provided for @genderUndisclosed.
  ///
  /// In it, this message translates to:
  /// **'Preferisco non dirlo'**
  String get genderUndisclosed;

  /// No description provided for @settingsNotifications.
  ///
  /// In it, this message translates to:
  /// **'Notifiche'**
  String get settingsNotifications;

  /// No description provided for @settingsPush.
  ///
  /// In it, this message translates to:
  /// **'Notifiche push'**
  String get settingsPush;

  /// No description provided for @settingsPushOn.
  ///
  /// In it, this message translates to:
  /// **'Attive su questo telefono'**
  String get settingsPushOn;

  /// No description provided for @settingsPushSoon.
  ///
  /// In it, this message translates to:
  /// **'In arrivo: le scelte qui sotto sono già salvate.'**
  String get settingsPushSoon;

  /// No description provided for @settingsForBuyers.
  ///
  /// In it, this message translates to:
  /// **'Quando cerchi'**
  String get settingsForBuyers;

  /// No description provided for @settingsForSellers.
  ///
  /// In it, this message translates to:
  /// **'Quando vendi'**
  String get settingsForSellers;

  /// No description provided for @notifNewMessage.
  ///
  /// In it, this message translates to:
  /// **'Nuovi messaggi'**
  String get notifNewMessage;

  /// No description provided for @notifPriceDrop.
  ///
  /// In it, this message translates to:
  /// **'Calo di prezzo dei salvati'**
  String get notifPriceDrop;

  /// No description provided for @notifListingSold.
  ///
  /// In it, this message translates to:
  /// **'Un annuncio salvato è stato venduto'**
  String get notifListingSold;

  /// No description provided for @notifSavedSearch.
  ///
  /// In it, this message translates to:
  /// **'Nuovi annunci per le ricerche salvate'**
  String get notifSavedSearch;

  /// No description provided for @notifNewContact.
  ///
  /// In it, this message translates to:
  /// **'Nuovi contatti sui tuoi annunci'**
  String get notifNewContact;

  /// No description provided for @notifListingExpiring.
  ///
  /// In it, this message translates to:
  /// **'Annuncio in scadenza'**
  String get notifListingExpiring;

  /// No description provided for @settingsEmails.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get settingsEmails;

  /// No description provided for @settingsMarketingNote.
  ///
  /// In it, this message translates to:
  /// **'Al massimo qualche email al mese. Puoi cambiare idea quando vuoi.'**
  String get settingsMarketingNote;

  /// No description provided for @settingsLegal.
  ///
  /// In it, this message translates to:
  /// **'Documenti e aiuto'**
  String get settingsLegal;

  /// No description provided for @settingsAcceptedOn.
  ///
  /// In it, this message translates to:
  /// **'Accettati il {date}'**
  String settingsAcceptedOn(String date);

  /// No description provided for @settingsReadOn.
  ///
  /// In it, this message translates to:
  /// **'Letta il {date}'**
  String settingsReadOn(String date);

  /// No description provided for @settingsSupport.
  ///
  /// In it, this message translates to:
  /// **'Contatta il supporto'**
  String get settingsSupport;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In it, this message translates to:
  /// **'Elimina account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare l\'account?'**
  String get settingsDeleteTitle;

  /// No description provided for @settingsDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Cancelliamo il profilo, i salvati, le ricerche, i messaggi e i tuoi annunci. Non si può annullare.'**
  String get settingsDeleteBody;

  /// No description provided for @settingsDeleteCta.
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente'**
  String get settingsDeleteCta;

  /// No description provided for @settingsDeleted.
  ///
  /// In it, this message translates to:
  /// **'Account eliminato'**
  String get settingsDeleted;

  /// No description provided for @inboxTitle.
  ///
  /// In it, this message translates to:
  /// **'Messaggi'**
  String get inboxTitle;

  /// No description provided for @inboxGuestTitle.
  ///
  /// In it, this message translates to:
  /// **'I tuoi messaggi'**
  String get inboxGuestTitle;

  /// No description provided for @inboxGuestBody.
  ///
  /// In it, this message translates to:
  /// **'Accedi per scrivere ai venditori e ritrovare qui tutte le chat.'**
  String get inboxGuestBody;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun messaggio'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Quando scrivi a un venditore, la chat appare qui.'**
  String get inboxEmptyBody;

  /// No description provided for @inboxExplore.
  ///
  /// In it, this message translates to:
  /// **'Esplora annunci'**
  String get inboxExplore;

  /// No description provided for @inboxYourListing.
  ///
  /// In it, this message translates to:
  /// **'Il tuo annuncio'**
  String get inboxYourListing;

  /// No description provided for @inboxYou.
  ///
  /// In it, this message translates to:
  /// **'Tu: {text}'**
  String inboxYou(String text);

  /// No description provided for @chatPrivateSeller.
  ///
  /// In it, this message translates to:
  /// **'Venditore privato'**
  String get chatPrivateSeller;

  /// No description provided for @chatBuyer.
  ///
  /// In it, this message translates to:
  /// **'Acquirente'**
  String get chatBuyer;

  /// No description provided for @chatToday.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get chatYesterday;

  /// No description provided for @chatNotFoundTitle.
  ///
  /// In it, this message translates to:
  /// **'Chat non disponibile'**
  String get chatNotFoundTitle;

  /// No description provided for @chatNotFoundBody.
  ///
  /// In it, this message translates to:
  /// **'Questa chat non esiste più.'**
  String get chatNotFoundBody;

  /// No description provided for @chatInputHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un messaggio'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get chatSend;

  /// No description provided for @chatSending.
  ///
  /// In it, this message translates to:
  /// **'Invio…'**
  String get chatSending;

  /// No description provided for @chatFailed.
  ///
  /// In it, this message translates to:
  /// **'Non inviato · tocca per riprovare'**
  String get chatFailed;

  /// No description provided for @chatDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get chatDelete;

  /// No description provided for @chatNewTitle.
  ///
  /// In it, this message translates to:
  /// **'Scrivi a {name}'**
  String chatNewTitle(String name);

  /// No description provided for @chatNewBody.
  ///
  /// In it, this message translates to:
  /// **'Fai la tua domanda: la risposta arriva qui e in Inbox.'**
  String get chatNewBody;

  /// No description provided for @chatSafetyTip.
  ///
  /// In it, this message translates to:
  /// **'Non pagare anticipi o caparre prima di aver visto il veicolo di persona.'**
  String get chatSafetyTip;

  /// No description provided for @chatQuickAvailable.
  ///
  /// In it, this message translates to:
  /// **'È ancora disponibile?'**
  String get chatQuickAvailable;

  /// No description provided for @chatQuickVisit.
  ///
  /// In it, this message translates to:
  /// **'Posso vederlo dal vivo?'**
  String get chatQuickVisit;

  /// No description provided for @chatQuickPrice.
  ///
  /// In it, this message translates to:
  /// **'Il prezzo è trattabile?'**
  String get chatQuickPrice;

  /// No description provided for @chatQuickTradeIn.
  ///
  /// In it, this message translates to:
  /// **'Accetti permute?'**
  String get chatQuickTradeIn;

  /// No description provided for @chatListingSold.
  ///
  /// In it, this message translates to:
  /// **'Venduto'**
  String get chatListingSold;

  /// No description provided for @chatListingUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Non più disponibile'**
  String get chatListingUnavailable;

  /// No description provided for @chatSendError.
  ///
  /// In it, this message translates to:
  /// **'Messaggio non inviato, riprova.'**
  String get chatSendError;

  /// No description provided for @contactListingUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Questo annuncio non è più disponibile.'**
  String get contactListingUnavailable;

  /// No description provided for @contactOwnListing.
  ///
  /// In it, this message translates to:
  /// **'È un tuo annuncio.'**
  String get contactOwnListing;

  /// No description provided for @contactError.
  ///
  /// In it, this message translates to:
  /// **'Non riusciamo ad aprire la chat, riprova.'**
  String get contactError;

  /// No description provided for @whatsappLabel.
  ///
  /// In it, this message translates to:
  /// **'WhatsApp'**
  String get whatsappLabel;

  /// No description provided for @whatsappNoNumber.
  ///
  /// In it, this message translates to:
  /// **'Il venditore non ha un numero WhatsApp: scrivigli in chat.'**
  String get whatsappNoNumber;

  /// No description provided for @whatsappError.
  ///
  /// In it, this message translates to:
  /// **'Non riusciamo ad aprire WhatsApp.'**
  String get whatsappError;

  /// No description provided for @whatsappPrefill.
  ///
  /// In it, this message translates to:
  /// **'Ciao! Ti scrivo per {title} visto su {app}.'**
  String whatsappPrefill(String title, String app);

  /// No description provided for @shareText.
  ///
  /// In it, this message translates to:
  /// **'{summary}\nGuarda l\'annuncio su {app}: {link}'**
  String shareText(String summary, String app, String link);

  /// No description provided for @shareError.
  ///
  /// In it, this message translates to:
  /// **'Non riusciamo ad aprire la condivisione.'**
  String get shareError;

  /// No description provided for @sellTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa vuoi vendere?'**
  String get sellTitle;

  /// No description provided for @sellSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Ti guidiamo ripresa per ripresa: servono circa 5 minuti.'**
  String get sellSubtitle;

  /// No description provided for @sellCar.
  ///
  /// In it, this message translates to:
  /// **'Auto'**
  String get sellCar;

  /// No description provided for @sellCarHint.
  ///
  /// In it, this message translates to:
  /// **'anche furgoni'**
  String get sellCarHint;

  /// No description provided for @sellMoto.
  ///
  /// In it, this message translates to:
  /// **'Moto'**
  String get sellMoto;

  /// No description provided for @sellMotoHint.
  ///
  /// In it, this message translates to:
  /// **'anche scooter'**
  String get sellMotoHint;

  /// No description provided for @sellBeforeTitle.
  ///
  /// In it, this message translates to:
  /// **'Prima di iniziare'**
  String get sellBeforeTitle;

  /// No description provided for @sellBeforeCar.
  ///
  /// In it, this message translates to:
  /// **'Auto pulita e luce di giorno · motore pronto per l\'avviamento · se vuoi, copri la targa.'**
  String get sellBeforeCar;

  /// No description provided for @sellBeforeMoto.
  ///
  /// In it, this message translates to:
  /// **'Moto pulita e luce di giorno · motore pronto per l\'avviamento · se vuoi, copri la targa.'**
  String get sellBeforeMoto;

  /// No description provided for @sellStart.
  ///
  /// In it, this message translates to:
  /// **'Inizia le riprese'**
  String get sellStart;

  /// No description provided for @sellStartNote.
  ///
  /// In it, this message translates to:
  /// **'Puoi fermarti quando vuoi: salviamo la bozza'**
  String get sellStartNote;

  /// No description provided for @sellDraftTitle.
  ///
  /// In it, this message translates to:
  /// **'Hai un annuncio in corso'**
  String get sellDraftTitle;

  /// No description provided for @sellDraftBody.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna ripresa ancora} =1{1 ripresa fatta} other{{count} riprese fatte}}'**
  String sellDraftBody(int count);

  /// No description provided for @sellResume.
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get sellResume;

  /// No description provided for @sellRestart.
  ///
  /// In it, this message translates to:
  /// **'Ricomincia'**
  String get sellRestart;

  /// No description provided for @sellRestartTitle.
  ///
  /// In it, this message translates to:
  /// **'Ricominciare da capo?'**
  String get sellRestartTitle;

  /// No description provided for @sellRestartBody.
  ///
  /// In it, this message translates to:
  /// **'Le riprese e i dati di questa bozza verranno eliminati.'**
  String get sellRestartBody;

  /// No description provided for @captureStepOf.
  ///
  /// In it, this message translates to:
  /// **'Step {current} di {total}'**
  String captureStepOf(int current, int total);

  /// No description provided for @captureVideo.
  ///
  /// In it, this message translates to:
  /// **'Video {seconds} s'**
  String captureVideo(int seconds);

  /// No description provided for @capturePhoto.
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get capturePhoto;

  /// No description provided for @captureSkip.
  ///
  /// In it, this message translates to:
  /// **'Salta'**
  String get captureSkip;

  /// No description provided for @captureNext.
  ///
  /// In it, this message translates to:
  /// **'Prossimo: {step}'**
  String captureNext(String step);

  /// No description provided for @captureLast.
  ///
  /// In it, this message translates to:
  /// **'Ultima ripresa'**
  String get captureLast;

  /// No description provided for @capturePlateTip.
  ///
  /// In it, this message translates to:
  /// **'Se vuoi, copri la targa'**
  String get capturePlateTip;

  /// No description provided for @captureHoldStill.
  ///
  /// In it, this message translates to:
  /// **'Tieni fermo il telefono'**
  String get captureHoldStill;

  /// No description provided for @captureRecording.
  ///
  /// In it, this message translates to:
  /// **'Registrazione · {seconds} s'**
  String captureRecording(int seconds);

  /// No description provided for @captureAlignFront.
  ///
  /// In it, this message translates to:
  /// **'Mettiti davanti all\'auto e centrala nella sagoma, a circa 4 metri'**
  String get captureAlignFront;

  /// No description provided for @captureAlignCar.
  ///
  /// In it, this message translates to:
  /// **'Allinea l\'auto alla sagoma, a circa 4 metri'**
  String get captureAlignCar;

  /// No description provided for @captureAlignMoto.
  ///
  /// In it, this message translates to:
  /// **'Allinea la moto alla sagoma, a circa 3 metri'**
  String get captureAlignMoto;

  /// No description provided for @captureHintKm.
  ///
  /// In it, this message translates to:
  /// **'Motore acceso: inquadra il quadro con i km'**
  String get captureHintKm;

  /// No description provided for @captureHintEngineBay.
  ///
  /// In it, this message translates to:
  /// **'Apri il cofano e inquadra il motore'**
  String get captureHintEngineBay;

  /// No description provided for @captureHintDefects.
  ///
  /// In it, this message translates to:
  /// **'Inquadra da vicino graffi, ammaccature o usura'**
  String get captureHintDefects;

  /// No description provided for @captureHintChain.
  ///
  /// In it, this message translates to:
  /// **'Inquadra da vicino catena e battistrada'**
  String get captureHintChain;

  /// No description provided for @captureHintExhaust.
  ///
  /// In it, this message translates to:
  /// **'Inquadra lo scarico, meglio a motore acceso'**
  String get captureHintExhaust;

  /// No description provided for @captureTorch.
  ///
  /// In it, this message translates to:
  /// **'Torcia'**
  String get captureTorch;

  /// No description provided for @captureShots.
  ///
  /// In it, this message translates to:
  /// **'Le tue riprese'**
  String get captureShots;

  /// No description provided for @captureCameraDenied.
  ///
  /// In it, this message translates to:
  /// **'Per le riprese servono fotocamera e microfono. Attivali nelle impostazioni del telefono.'**
  String get captureCameraDenied;

  /// No description provided for @captureCameraError.
  ///
  /// In it, this message translates to:
  /// **'Non riusciamo ad aprire la fotocamera.'**
  String get captureCameraError;

  /// No description provided for @captureSaveError.
  ///
  /// In it, this message translates to:
  /// **'Ripresa non salvata, riprova.'**
  String get captureSaveError;

  /// No description provided for @sellStepFront.
  ///
  /// In it, this message translates to:
  /// **'Frontale'**
  String get sellStepFront;

  /// No description provided for @sellStepFront3q.
  ///
  /// In it, this message translates to:
  /// **'Fronte 3/4'**
  String get sellStepFront3q;

  /// No description provided for @sellStepRightSide.
  ///
  /// In it, this message translates to:
  /// **'Lato destro'**
  String get sellStepRightSide;

  /// No description provided for @sellStepLeftSide.
  ///
  /// In it, this message translates to:
  /// **'Lato sinistro'**
  String get sellStepLeftSide;

  /// No description provided for @sellStepRear.
  ///
  /// In it, this message translates to:
  /// **'Posteriore'**
  String get sellStepRear;

  /// No description provided for @sellStepInterior.
  ///
  /// In it, this message translates to:
  /// **'Interni e quadro km'**
  String get sellStepInterior;

  /// No description provided for @sellStepEngineBay.
  ///
  /// In it, this message translates to:
  /// **'Vano motore'**
  String get sellStepEngineBay;

  /// No description provided for @sellStepDefects.
  ///
  /// In it, this message translates to:
  /// **'Difetti visibili'**
  String get sellStepDefects;

  /// No description provided for @sellStepTank.
  ///
  /// In it, this message translates to:
  /// **'Serbatoio e quadro km'**
  String get sellStepTank;

  /// No description provided for @sellStepChain.
  ///
  /// In it, this message translates to:
  /// **'Catena e gomme'**
  String get sellStepChain;

  /// No description provided for @sellStepExhaust.
  ///
  /// In it, this message translates to:
  /// **'Scarico'**
  String get sellStepExhaust;

  /// No description provided for @shotsTitle.
  ///
  /// In it, this message translates to:
  /// **'Le tue riprese'**
  String get shotsTitle;

  /// No description provided for @shotsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'{done} di {total} completate. Al resto pensiamo noi: montiamo il video e creiamo il carosello.'**
  String shotsSubtitle(int done, int total);

  /// No description provided for @shotsVideo.
  ///
  /// In it, this message translates to:
  /// **'Video · {seconds} s'**
  String shotsVideo(int seconds);

  /// No description provided for @shotsPhoto.
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get shotsPhoto;

  /// No description provided for @shotsTodo.
  ///
  /// In it, this message translates to:
  /// **'Da fare'**
  String get shotsTodo;

  /// No description provided for @shotsOptional.
  ///
  /// In it, this message translates to:
  /// **'Facoltativo'**
  String get shotsOptional;

  /// No description provided for @shotsOptionalDefects.
  ///
  /// In it, this message translates to:
  /// **'Facoltativo · aumenta la fiducia'**
  String get shotsOptionalDefects;

  /// No description provided for @shotsEngineOn.
  ///
  /// In it, this message translates to:
  /// **'motore acceso'**
  String get shotsEngineOn;

  /// No description provided for @extraPhotosTitle.
  ///
  /// In it, this message translates to:
  /// **'Foto aggiuntive'**
  String get extraPhotosTitle;

  /// No description provided for @extraPhotosHint.
  ///
  /// In it, this message translates to:
  /// **'Facoltative, fino a {max}: dettagli, gomme, libretto dei tagliandi. Finiscono nel carosello dell\'annuncio.'**
  String extraPhotosHint(int max);

  /// No description provided for @extraPhotosAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get extraPhotosAdd;

  /// No description provided for @extraPhotosCamera.
  ///
  /// In it, this message translates to:
  /// **'Scatta una foto'**
  String get extraPhotosCamera;

  /// No description provided for @extraPhotosGallery.
  ///
  /// In it, this message translates to:
  /// **'Scegli dalla galleria'**
  String get extraPhotosGallery;

  /// No description provided for @extraPhotosLimit.
  ///
  /// In it, this message translates to:
  /// **'Al massimo {max} foto aggiuntive'**
  String extraPhotosLimit(int max);

  /// No description provided for @extraPhotosError.
  ///
  /// In it, this message translates to:
  /// **'Non riusciamo ad aggiungere la foto. Riprova.'**
  String get extraPhotosError;

  /// No description provided for @shotsDefectsTip.
  ///
  /// In it, this message translates to:
  /// **'Mostrare i difetti rende l\'annuncio più credibile: chi compra si fida di più.'**
  String get shotsDefectsTip;

  /// No description provided for @shotsCreate.
  ///
  /// In it, this message translates to:
  /// **'Crea il video'**
  String get shotsCreate;

  /// No description provided for @shotsCreateNote.
  ///
  /// In it, this message translates to:
  /// **'Poi aggiungi prezzo, dati e descrizione'**
  String get shotsCreateNote;

  /// No description provided for @shotsMissing.
  ///
  /// In it, this message translates to:
  /// **'Mancano: {steps}'**
  String shotsMissing(String steps);

  /// No description provided for @shotsNeedVideo.
  ///
  /// In it, this message translates to:
  /// **'Serve almeno una ripresa video'**
  String get shotsNeedVideo;

  /// No description provided for @shotsRetake.
  ///
  /// In it, this message translates to:
  /// **'Rifai'**
  String get shotsRetake;

  /// No description provided for @shotsDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get shotsDelete;

  /// No description provided for @detailsTitle.
  ///
  /// In it, this message translates to:
  /// **'Dati e prezzo'**
  String get detailsTitle;

  /// No description provided for @detailsPreparing.
  ///
  /// In it, this message translates to:
  /// **'Stiamo preparando il video · {percent}%'**
  String detailsPreparing(int percent);

  /// No description provided for @detailsReady.
  ///
  /// In it, this message translates to:
  /// **'Video pronto'**
  String get detailsReady;

  /// No description provided for @detailsFailed.
  ///
  /// In it, this message translates to:
  /// **'Video non pronto · tocca per riprovare'**
  String get detailsFailed;

  /// No description provided for @detailsMake.
  ///
  /// In it, this message translates to:
  /// **'Marca'**
  String get detailsMake;

  /// No description provided for @detailsModel.
  ///
  /// In it, this message translates to:
  /// **'Modello'**
  String get detailsModel;

  /// No description provided for @detailsYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get detailsYear;

  /// No description provided for @detailsKm.
  ///
  /// In it, this message translates to:
  /// **'Chilometri'**
  String get detailsKm;

  /// No description provided for @detailsFuel.
  ///
  /// In it, this message translates to:
  /// **'Alimentazione'**
  String get detailsFuel;

  /// No description provided for @detailsMore.
  ///
  /// In it, this message translates to:
  /// **'+ Altri dettagli (cambio, potenza, classe Euro, proprietari)'**
  String get detailsMore;

  /// No description provided for @detailsLess.
  ///
  /// In it, this message translates to:
  /// **'Meno dettagli'**
  String get detailsLess;

  /// No description provided for @detailsVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione'**
  String get detailsVersion;

  /// No description provided for @detailsVersionHint.
  ///
  /// In it, this message translates to:
  /// **'es. 1.6 TDI Life'**
  String get detailsVersionHint;

  /// No description provided for @detailsGearbox.
  ///
  /// In it, this message translates to:
  /// **'Cambio'**
  String get detailsGearbox;

  /// No description provided for @detailsPower.
  ///
  /// In it, this message translates to:
  /// **'Potenza (kW)'**
  String get detailsPower;

  /// No description provided for @detailsPowerCv.
  ///
  /// In it, this message translates to:
  /// **'≈ {cv} CV'**
  String detailsPowerCv(int cv);

  /// No description provided for @detailsEuro.
  ///
  /// In it, this message translates to:
  /// **'Classe Euro'**
  String get detailsEuro;

  /// No description provided for @detailsOwners.
  ///
  /// In it, this message translates to:
  /// **'Proprietari'**
  String get detailsOwners;

  /// No description provided for @detailsColor.
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get detailsColor;

  /// No description provided for @detailsServiceHistory.
  ///
  /// In it, this message translates to:
  /// **'Tagliandi documentati'**
  String get detailsServiceHistory;

  /// No description provided for @detailsBodyType.
  ///
  /// In it, this message translates to:
  /// **'Carrozzeria'**
  String get detailsBodyType;

  /// No description provided for @detailsNovice.
  ///
  /// In it, this message translates to:
  /// **'Adatta ai neopatentati'**
  String get detailsNovice;

  /// No description provided for @detailsMotoType.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get detailsMotoType;

  /// No description provided for @detailsDisplacement.
  ///
  /// In it, this message translates to:
  /// **'Cilindrata (cc)'**
  String get detailsDisplacement;

  /// No description provided for @detailsLicense.
  ///
  /// In it, this message translates to:
  /// **'Patente'**
  String get detailsLicense;

  /// No description provided for @detailsPrice.
  ///
  /// In it, this message translates to:
  /// **'Prezzo'**
  String get detailsPrice;

  /// No description provided for @detailsDescription.
  ///
  /// In it, this message translates to:
  /// **'Descrizione'**
  String get detailsDescription;

  /// No description provided for @detailsDescriptionHint.
  ///
  /// In it, this message translates to:
  /// **'Racconta lo stato, i tagliandi, gli extra…'**
  String get detailsDescriptionHint;

  /// No description provided for @detailsWhere.
  ///
  /// In it, this message translates to:
  /// **'Dove si trova'**
  String get detailsWhere;

  /// No description provided for @detailsCity.
  ///
  /// In it, this message translates to:
  /// **'Città'**
  String get detailsCity;

  /// No description provided for @detailsProvince.
  ///
  /// In it, this message translates to:
  /// **'Provincia'**
  String get detailsProvince;

  /// No description provided for @detailsWhatsapp.
  ///
  /// In it, this message translates to:
  /// **'Contatto su WhatsApp'**
  String get detailsWhatsapp;

  /// No description provided for @detailsWhatsappHint.
  ///
  /// In it, this message translates to:
  /// **'Mostra il tuo numero a chi è interessato'**
  String get detailsWhatsappHint;

  /// No description provided for @detailsWhatsappDealer.
  ///
  /// In it, this message translates to:
  /// **'Mostra il numero WhatsApp del concessionario'**
  String get detailsWhatsappDealer;

  /// No description provided for @detailsPhone.
  ///
  /// In it, this message translates to:
  /// **'Numero di telefono'**
  String get detailsPhone;

  /// No description provided for @detailsSellerAge.
  ///
  /// In it, this message translates to:
  /// **'Ho almeno 18 anni, oppure vendo con il consenso di un genitore'**
  String get detailsSellerAge;

  /// No description provided for @detailsPublish.
  ///
  /// In it, this message translates to:
  /// **'Pubblica annuncio'**
  String get detailsPublish;

  /// No description provided for @detailsPublishing.
  ///
  /// In it, this message translates to:
  /// **'Pubblicazione…'**
  String get detailsPublishing;

  /// No description provided for @detailsRequired.
  ///
  /// In it, this message translates to:
  /// **'Obbligatorio'**
  String get detailsRequired;

  /// No description provided for @detailsInvalidYear.
  ///
  /// In it, this message translates to:
  /// **'Tra 1950 e {max}'**
  String detailsInvalidYear(int max);

  /// No description provided for @detailsInvalidPhone.
  ///
  /// In it, this message translates to:
  /// **'Numero non valido'**
  String get detailsInvalidPhone;

  /// No description provided for @detailsChoose.
  ///
  /// In it, this message translates to:
  /// **'Scegli'**
  String get detailsChoose;

  /// No description provided for @detailsSearchMake.
  ///
  /// In it, this message translates to:
  /// **'Cerca marca'**
  String get detailsSearchMake;

  /// No description provided for @detailsSearchModel.
  ///
  /// In it, this message translates to:
  /// **'Cerca modello'**
  String get detailsSearchModel;

  /// No description provided for @detailsChooseMakeFirst.
  ///
  /// In it, this message translates to:
  /// **'Prima scegli la marca'**
  String get detailsChooseMakeFirst;

  /// No description provided for @detailsFixFields.
  ///
  /// In it, this message translates to:
  /// **'Completa i campi evidenziati'**
  String get detailsFixFields;

  /// No description provided for @publishErrorIncomplete.
  ///
  /// In it, this message translates to:
  /// **'Mancano alcuni dati obbligatori.'**
  String get publishErrorIncomplete;

  /// No description provided for @publishErrorMedia.
  ///
  /// In it, this message translates to:
  /// **'Il video non è ancora caricato: riprova tra poco.'**
  String get publishErrorMedia;

  /// No description provided for @publishErrorNetwork.
  ///
  /// In it, this message translates to:
  /// **'Connessione assente o lenta: riprova.'**
  String get publishErrorNetwork;

  /// No description provided for @publishError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a pubblicare, riprova.'**
  String get publishError;

  /// No description provided for @doneTitle.
  ///
  /// In it, this message translates to:
  /// **'La tua {model} è online'**
  String doneTitle(String model);

  /// No description provided for @doneTitleGeneric.
  ///
  /// In it, this message translates to:
  /// **'Il tuo annuncio è online'**
  String get doneTitleGeneric;

  /// No description provided for @doneBody.
  ///
  /// In it, this message translates to:
  /// **'Ti avvisiamo a ogni nuovo contatto. Tra {weeks} settimane ti chiederemo se è ancora disponibile.'**
  String doneBody(int weeks);

  /// No description provided for @doneShare.
  ///
  /// In it, this message translates to:
  /// **'Condividi il link'**
  String get doneShare;

  /// No description provided for @doneOpen.
  ///
  /// In it, this message translates to:
  /// **'Vedi l\'annuncio'**
  String get doneOpen;

  /// No description provided for @bodyCityCar.
  ///
  /// In it, this message translates to:
  /// **'Citycar'**
  String get bodyCityCar;

  /// No description provided for @bodyHatchback.
  ///
  /// In it, this message translates to:
  /// **'Due volumi'**
  String get bodyHatchback;

  /// No description provided for @bodySedan.
  ///
  /// In it, this message translates to:
  /// **'Berlina'**
  String get bodySedan;

  /// No description provided for @bodyStationWagon.
  ///
  /// In it, this message translates to:
  /// **'Station wagon'**
  String get bodyStationWagon;

  /// No description provided for @bodySuv.
  ///
  /// In it, this message translates to:
  /// **'SUV'**
  String get bodySuv;

  /// No description provided for @bodyCoupe.
  ///
  /// In it, this message translates to:
  /// **'Coupé'**
  String get bodyCoupe;

  /// No description provided for @bodyConvertible.
  ///
  /// In it, this message translates to:
  /// **'Cabrio'**
  String get bodyConvertible;

  /// No description provided for @bodyMinivan.
  ///
  /// In it, this message translates to:
  /// **'Monovolume'**
  String get bodyMinivan;

  /// No description provided for @bodyVan.
  ///
  /// In it, this message translates to:
  /// **'Furgone'**
  String get bodyVan;

  /// No description provided for @bodyPickup.
  ///
  /// In it, this message translates to:
  /// **'Pick-up'**
  String get bodyPickup;

  /// No description provided for @motoNaked.
  ///
  /// In it, this message translates to:
  /// **'Naked'**
  String get motoNaked;

  /// No description provided for @motoSport.
  ///
  /// In it, this message translates to:
  /// **'Sportiva'**
  String get motoSport;

  /// No description provided for @motoTouring.
  ///
  /// In it, this message translates to:
  /// **'Turismo'**
  String get motoTouring;

  /// No description provided for @motoAdventure.
  ///
  /// In it, this message translates to:
  /// **'Adventure'**
  String get motoAdventure;

  /// No description provided for @motoEnduro.
  ///
  /// In it, this message translates to:
  /// **'Enduro'**
  String get motoEnduro;

  /// No description provided for @motoCross.
  ///
  /// In it, this message translates to:
  /// **'Cross'**
  String get motoCross;

  /// No description provided for @motoCustom.
  ///
  /// In it, this message translates to:
  /// **'Custom'**
  String get motoCustom;

  /// No description provided for @motoScooter.
  ///
  /// In it, this message translates to:
  /// **'Scooter'**
  String get motoScooter;

  /// No description provided for @motoMotard.
  ///
  /// In it, this message translates to:
  /// **'Motard'**
  String get motoMotard;

  /// No description provided for @captureRecord.
  ///
  /// In it, this message translates to:
  /// **'Registra'**
  String get captureRecord;

  /// No description provided for @captureTakePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta'**
  String get captureTakePhoto;

  /// No description provided for @filterDistance.
  ///
  /// In it, this message translates to:
  /// **'Distanza'**
  String get filterDistance;

  /// No description provided for @distanceAll.
  ///
  /// In it, this message translates to:
  /// **'Tutta Italia'**
  String get distanceAll;

  /// No description provided for @distanceKm.
  ///
  /// In it, this message translates to:
  /// **'{km} km'**
  String distanceKm(int km);

  /// No description provided for @distanceWithin.
  ///
  /// In it, this message translates to:
  /// **'Entro {km} km'**
  String distanceWithin(int km);

  /// No description provided for @distanceWithinFrom.
  ///
  /// In it, this message translates to:
  /// **'Entro {km} km da {city}'**
  String distanceWithinFrom(int km, String city);

  /// No description provided for @distanceFrom.
  ///
  /// In it, this message translates to:
  /// **'Da'**
  String get distanceFrom;

  /// No description provided for @distancePickCenter.
  ///
  /// In it, this message translates to:
  /// **'Scegli il capoluogo'**
  String get distancePickCenter;

  /// No description provided for @distanceAway.
  ///
  /// In it, this message translates to:
  /// **'{km} km da te'**
  String distanceAway(int km);

  /// No description provided for @distanceHere.
  ///
  /// In it, this message translates to:
  /// **'Nella tua provincia'**
  String get distanceHere;

  /// No description provided for @capitalSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca il capoluogo più vicino a te'**
  String get capitalSearch;

  /// No description provided for @prefsWhere.
  ///
  /// In it, this message translates to:
  /// **'Dove sei?'**
  String get prefsWhere;

  /// No description provided for @prefsWhereHint.
  ///
  /// In it, this message translates to:
  /// **'Il capoluogo più vicino a te: così ti mostriamo gli annunci in zona.'**
  String get prefsWhereHint;

  /// No description provided for @prefsWhereNone.
  ///
  /// In it, this message translates to:
  /// **'Scegli il capoluogo'**
  String get prefsWhereNone;

  /// No description provided for @prefsDistance.
  ///
  /// In it, this message translates to:
  /// **'Fino a che distanza?'**
  String get prefsDistance;

  /// No description provided for @settingsPublicProfile.
  ///
  /// In it, this message translates to:
  /// **'Profilo pubblico'**
  String get settingsPublicProfile;

  /// No description provided for @settingsPublicProfileNote.
  ///
  /// In it, this message translates to:
  /// **'Chi guarda i tuoi annunci vede il tuo nome, il capoluogo e i contatti che scegli di mostrare. Il numero lo vede solo chi ha un account.'**
  String get settingsPublicProfileNote;

  /// No description provided for @settingsWhere.
  ///
  /// In it, this message translates to:
  /// **'Dove sei'**
  String get settingsWhere;

  /// No description provided for @settingsPhone.
  ///
  /// In it, this message translates to:
  /// **'Telefono'**
  String get settingsPhone;

  /// No description provided for @settingsPhonePublic.
  ///
  /// In it, this message translates to:
  /// **'Mostra il numero sul profilo'**
  String get settingsPhonePublic;

  /// No description provided for @settingsWhatsappPublic.
  ///
  /// In it, this message translates to:
  /// **'Contatto su WhatsApp'**
  String get settingsWhatsappPublic;

  /// No description provided for @settingsPhoneNeeded.
  ///
  /// In it, this message translates to:
  /// **'Prima aggiungi il numero'**
  String get settingsPhoneNeeded;

  /// No description provided for @sellerListingsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessun annuncio} =1{1 annuncio} other{{count} annunci}}'**
  String sellerListingsCount(int count);

  /// No description provided for @sellerMemberSince.
  ///
  /// In it, this message translates to:
  /// **'Su {app} da {date}'**
  String sellerMemberSince(String app, String date);

  /// No description provided for @sellerCall.
  ///
  /// In it, this message translates to:
  /// **'Chiama'**
  String get sellerCall;

  /// No description provided for @sellerWebsite.
  ///
  /// In it, this message translates to:
  /// **'Sito'**
  String get sellerWebsite;

  /// No description provided for @sellerTabListings.
  ///
  /// In it, this message translates to:
  /// **'Annunci'**
  String get sellerTabListings;

  /// No description provided for @sellerTabReviews.
  ///
  /// In it, this message translates to:
  /// **'Recensioni'**
  String get sellerTabReviews;

  /// No description provided for @sellerNotFoundTitle.
  ///
  /// In it, this message translates to:
  /// **'Profilo non disponibile'**
  String get sellerNotFoundTitle;

  /// No description provided for @sellerNotFoundBody.
  ///
  /// In it, this message translates to:
  /// **'Questo venditore non ha annunci online.'**
  String get sellerNotFoundBody;

  /// No description provided for @sellerNoListings.
  ///
  /// In it, this message translates to:
  /// **'Nessun annuncio online'**
  String get sellerNoListings;

  /// No description provided for @sellerNoMatches.
  ///
  /// In it, this message translates to:
  /// **'Nessun annuncio con questi filtri'**
  String get sellerNoMatches;

  /// No description provided for @sellerSeeAll.
  ///
  /// In it, this message translates to:
  /// **'Vedi tutti gli annunci'**
  String get sellerSeeAll;

  /// No description provided for @sellerLoginForContacts.
  ///
  /// In it, this message translates to:
  /// **'Accedi per vedere i contatti'**
  String get sellerLoginForContacts;

  /// No description provided for @sellerPrivateShort.
  ///
  /// In it, this message translates to:
  /// **'Privato'**
  String get sellerPrivateShort;

  /// No description provided for @sellerNoReviews.
  ///
  /// In it, this message translates to:
  /// **'Ancora nessuna recensione'**
  String get sellerNoReviews;

  /// No description provided for @settingsPhoto.
  ///
  /// In it, this message translates to:
  /// **'Foto profilo'**
  String get settingsPhoto;

  /// No description provided for @settingsPhotoChange.
  ///
  /// In it, this message translates to:
  /// **'La vede chi guarda i tuoi annunci'**
  String get settingsPhotoChange;

  /// No description provided for @settingsPhotoTake.
  ///
  /// In it, this message translates to:
  /// **'Scatta una foto'**
  String get settingsPhotoTake;

  /// No description provided for @settingsPhotoPick.
  ///
  /// In it, this message translates to:
  /// **'Scegli dalla galleria'**
  String get settingsPhotoPick;

  /// No description provided for @settingsPhotoRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi la foto'**
  String get settingsPhotoRemove;

  /// No description provided for @settingsPhotoError.
  ///
  /// In it, this message translates to:
  /// **'Non siamo riusciti a salvare la foto, riprova.'**
  String get settingsPhotoError;

  /// No description provided for @settingsDealerName.
  ///
  /// In it, this message translates to:
  /// **'Nome del concessionario'**
  String get settingsDealerName;

  /// No description provided for @settingsDealerDescription.
  ///
  /// In it, this message translates to:
  /// **'Descrizione'**
  String get settingsDealerDescription;

  /// No description provided for @settingsDealerWhere.
  ///
  /// In it, this message translates to:
  /// **'Dove si trova'**
  String get settingsDealerWhere;

  /// No description provided for @settingsDealerWebsite.
  ///
  /// In it, this message translates to:
  /// **'Sito web'**
  String get settingsDealerWebsite;

  /// No description provided for @settingsDealerNote.
  ///
  /// In it, this message translates to:
  /// **'Questi dati compaiono sulla pagina del concessionario, insieme ai tuoi annunci.'**
  String get settingsDealerNote;

  /// No description provided for @settingsDealerOwnerOnly.
  ///
  /// In it, this message translates to:
  /// **'Solo il titolare del concessionario può modificarli.'**
  String get settingsDealerOwnerOnly;

  /// No description provided for @capitalUseLocation.
  ///
  /// In it, this message translates to:
  /// **'Usa la mia posizione'**
  String get capitalUseLocation;

  /// No description provided for @capitalLocating.
  ///
  /// In it, this message translates to:
  /// **'Cerco il capoluogo più vicino…'**
  String get capitalLocating;

  /// No description provided for @capitalLocationOff.
  ///
  /// In it, this message translates to:
  /// **'La localizzazione del telefono è spenta: attivala o scegli dalla lista.'**
  String get capitalLocationOff;

  /// No description provided for @capitalLocationDenied.
  ///
  /// In it, this message translates to:
  /// **'Permesso posizione negato: scegli dalla lista.'**
  String get capitalLocationDenied;

  /// No description provided for @capitalLocationError.
  ///
  /// In it, this message translates to:
  /// **'Non riusciamo a trovare la tua posizione: scegli dalla lista.'**
  String get capitalLocationError;

  /// No description provided for @nearbyDealersTitle.
  ///
  /// In it, this message translates to:
  /// **'Concessionari vicino a te'**
  String get nearbyDealersTitle;

  /// No description provided for @nearbyDealersWithin.
  ///
  /// In it, this message translates to:
  /// **'Entro {km} km da {city}'**
  String nearbyDealersWithin(int km, String city);

  /// No description provided for @nearbyDealersSetPlace.
  ///
  /// In it, this message translates to:
  /// **'Dicci dove sei per vedere i concessionari in zona.'**
  String get nearbyDealersSetPlace;

  /// No description provided for @nearbyDealersNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun concessionario con annunci entro {km} km.'**
  String nearbyDealersNone(int km);
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
