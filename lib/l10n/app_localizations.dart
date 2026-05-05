import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('zh')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'ATM Academy'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get navCourses;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @languageScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageScreenTitle;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @levelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get levelBeginner;

  /// No description provided for @levelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get levelIntermediate;

  /// No description provided for @levelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get levelAdvanced;

  /// No description provided for @levelExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get levelExpert;

  /// No description provided for @btnStartLesson.
  ///
  /// In en, this message translates to:
  /// **'Start Lesson'**
  String get btnStartLesson;

  /// No description provided for @btnNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get btnNext;

  /// No description provided for @btnPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get btnPrevious;

  /// No description provided for @btnCheckAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check Answer'**
  String get btnCheckAnswer;

  /// No description provided for @btnTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get btnTryAgain;

  /// No description provided for @btnContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get btnContinue;

  /// No description provided for @quizTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quizTitle;

  /// No description provided for @quizCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get quizCorrect;

  /// No description provided for @quizIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get quizIncorrect;

  /// No description provided for @quizExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get quizExplanation;

  /// No description provided for @progressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressLabel;

  /// No description provided for @courseHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'ATM Courses'**
  String get courseHomeTitle;

  /// No description provided for @lesson1Title.
  ///
  /// In en, this message translates to:
  /// **'What is ATM?'**
  String get lesson1Title;

  /// No description provided for @lesson1Summary.
  ///
  /// In en, this message translates to:
  /// **'Air Traffic Management keeps aircraft moving safely and efficiently.'**
  String get lesson1Summary;

  /// No description provided for @lesson1Content1.
  ///
  /// In en, this message translates to:
  /// **'ATM means Air Traffic Management.'**
  String get lesson1Content1;

  /// No description provided for @lesson1Content2.
  ///
  /// In en, this message translates to:
  /// **'It includes air traffic control, airspace management, and traffic flow management.'**
  String get lesson1Content2;

  /// No description provided for @lesson1Content3.
  ///
  /// In en, this message translates to:
  /// **'The main goals are safety, efficiency, order, and capacity.'**
  String get lesson1Content3;

  /// No description provided for @lesson1Q1Question.
  ///
  /// In en, this message translates to:
  /// **'What is the main goal of ATM?'**
  String get lesson1Q1Question;

  /// No description provided for @lesson1Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Sell airline tickets'**
  String get lesson1Q1Option0;

  /// No description provided for @lesson1Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Keep aircraft safe and efficiently managed'**
  String get lesson1Q1Option1;

  /// No description provided for @lesson1Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Repair aircraft engines'**
  String get lesson1Q1Option2;

  /// No description provided for @lesson1Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'ATM focuses on safe, orderly, and efficient aircraft movement.'**
  String get lesson1Q1Explanation;

  /// No description provided for @lesson2Title.
  ///
  /// In en, this message translates to:
  /// **'Tower, Approach, and En-route'**
  String get lesson2Title;

  /// No description provided for @lesson2Summary.
  ///
  /// In en, this message translates to:
  /// **'Different controllers manage different phases of flight.'**
  String get lesson2Summary;

  /// No description provided for @lesson2Content1.
  ///
  /// In en, this message translates to:
  /// **'Tower controls runways, takeoff, landing, and ground movement near the airport.'**
  String get lesson2Content1;

  /// No description provided for @lesson2Content2.
  ///
  /// In en, this message translates to:
  /// **'Approach controls aircraft arriving to or leaving an airport area.'**
  String get lesson2Content2;

  /// No description provided for @lesson2Content3.
  ///
  /// In en, this message translates to:
  /// **'En-route controls aircraft during cruise between airports.'**
  String get lesson2Content3;

  /// No description provided for @lesson2Q1Question.
  ///
  /// In en, this message translates to:
  /// **'Which unit usually controls aircraft landing on the runway?'**
  String get lesson2Q1Question;

  /// No description provided for @lesson2Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Tower'**
  String get lesson2Q1Option0;

  /// No description provided for @lesson2Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Airline office'**
  String get lesson2Q1Option1;

  /// No description provided for @lesson2Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Baggage service'**
  String get lesson2Q1Option2;

  /// No description provided for @lesson2Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Tower manages runway operations including takeoff and landing.'**
  String get lesson2Q1Explanation;

  /// No description provided for @lesson3Title.
  ///
  /// In en, this message translates to:
  /// **'Runway, Taxiway, and Holding Point'**
  String get lesson3Title;

  /// No description provided for @lesson3Summary.
  ///
  /// In en, this message translates to:
  /// **'Airports have controlled movement areas.'**
  String get lesson3Summary;

  /// No description provided for @lesson3Content1.
  ///
  /// In en, this message translates to:
  /// **'A runway is used for takeoff and landing.'**
  String get lesson3Content1;

  /// No description provided for @lesson3Content2.
  ///
  /// In en, this message translates to:
  /// **'A taxiway is used for aircraft movement on the ground.'**
  String get lesson3Content2;

  /// No description provided for @lesson3Content3.
  ///
  /// In en, this message translates to:
  /// **'A holding point is where aircraft wait before entering a runway.'**
  String get lesson3Content3;

  /// No description provided for @lesson3Q1Question.
  ///
  /// In en, this message translates to:
  /// **'Where should an aircraft wait before entering a runway?'**
  String get lesson3Q1Question;

  /// No description provided for @lesson3Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Holding point'**
  String get lesson3Q1Option0;

  /// No description provided for @lesson3Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Passenger gate only'**
  String get lesson3Q1Option1;

  /// No description provided for @lesson3Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Cruise level'**
  String get lesson3Q1Option2;

  /// No description provided for @lesson3Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Holding points protect runway safety.'**
  String get lesson3Q1Explanation;

  /// No description provided for @lesson4Title.
  ///
  /// In en, this message translates to:
  /// **'Flight Plan Basics'**
  String get lesson4Title;

  /// No description provided for @lesson4Summary.
  ///
  /// In en, this message translates to:
  /// **'A flight plan tells the ATM system where an aircraft intends to fly.'**
  String get lesson4Summary;

  /// No description provided for @lesson4Content1.
  ///
  /// In en, this message translates to:
  /// **'A flight plan includes aircraft identity, route, departure, destination, and timing.'**
  String get lesson4Content1;

  /// No description provided for @lesson4Content2.
  ///
  /// In en, this message translates to:
  /// **'Controllers use flight plans to predict traffic.'**
  String get lesson4Content2;

  /// No description provided for @lesson4Content3.
  ///
  /// In en, this message translates to:
  /// **'Good planning helps reduce conflicts.'**
  String get lesson4Content3;

  /// No description provided for @lesson4Q1Question.
  ///
  /// In en, this message translates to:
  /// **'Why are flight plans important?'**
  String get lesson4Q1Question;

  /// No description provided for @lesson4Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'They help predict and manage traffic'**
  String get lesson4Q1Option0;

  /// No description provided for @lesson4Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'They replace pilots'**
  String get lesson4Q1Option1;

  /// No description provided for @lesson4Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'They control weather'**
  String get lesson4Q1Option2;

  /// No description provided for @lesson4Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Flight plans help controllers and systems understand intended aircraft movement.'**
  String get lesson4Q1Explanation;

  /// No description provided for @lesson5Title.
  ///
  /// In en, this message translates to:
  /// **'Separation Basics'**
  String get lesson5Title;

  /// No description provided for @lesson5Summary.
  ///
  /// In en, this message translates to:
  /// **'Separation keeps aircraft safely apart.'**
  String get lesson5Summary;

  /// No description provided for @lesson5Content1.
  ///
  /// In en, this message translates to:
  /// **'Separation means keeping enough distance between aircraft.'**
  String get lesson5Content1;

  /// No description provided for @lesson5Content2.
  ///
  /// In en, this message translates to:
  /// **'Separation can be vertical, lateral, or longitudinal.'**
  String get lesson5Content2;

  /// No description provided for @lesson5Content3.
  ///
  /// In en, this message translates to:
  /// **'Loss of separation is a serious safety risk.'**
  String get lesson5Content3;

  /// No description provided for @lesson5Q1Question.
  ///
  /// In en, this message translates to:
  /// **'What does separation mean in ATM?'**
  String get lesson5Q1Question;

  /// No description provided for @lesson5Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Keeping aircraft safely apart'**
  String get lesson5Q1Option0;

  /// No description provided for @lesson5Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Parking aircraft close together'**
  String get lesson5Q1Option1;

  /// No description provided for @lesson5Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Making aircraft fly faster'**
  String get lesson5Q1Option2;

  /// No description provided for @lesson5Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Separation is one of the core safety concepts in ATM.'**
  String get lesson5Q1Explanation;

  /// No description provided for @lesson6Title.
  ///
  /// In en, this message translates to:
  /// **'Sequencing and Spacing'**
  String get lesson6Title;

  /// No description provided for @lesson6Summary.
  ///
  /// In en, this message translates to:
  /// **'Controllers organise aircraft into a safe and efficient order.'**
  String get lesson6Summary;

  /// No description provided for @lesson6Content1.
  ///
  /// In en, this message translates to:
  /// **'Sequencing means deciding the order of aircraft.'**
  String get lesson6Content1;

  /// No description provided for @lesson6Content2.
  ///
  /// In en, this message translates to:
  /// **'Spacing means keeping suitable gaps between aircraft.'**
  String get lesson6Content2;

  /// No description provided for @lesson6Content3.
  ///
  /// In en, this message translates to:
  /// **'Good sequencing improves runway capacity and reduces delay.'**
  String get lesson6Content3;

  /// No description provided for @lesson6Q1Question.
  ///
  /// In en, this message translates to:
  /// **'What is sequencing?'**
  String get lesson6Q1Question;

  /// No description provided for @lesson6Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Choosing aircraft order'**
  String get lesson6Q1Option0;

  /// No description provided for @lesson6Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Painting runway numbers'**
  String get lesson6Q1Option1;

  /// No description provided for @lesson6Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Loading baggage'**
  String get lesson6Q1Option2;

  /// No description provided for @lesson6Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Sequencing determines the safe and efficient order of traffic.'**
  String get lesson6Q1Explanation;

  /// No description provided for @lesson7Title.
  ///
  /// In en, this message translates to:
  /// **'Weather Impact'**
  String get lesson7Title;

  /// No description provided for @lesson7Summary.
  ///
  /// In en, this message translates to:
  /// **'Weather can reduce capacity and increase workload.'**
  String get lesson7Summary;

  /// No description provided for @lesson7Content1.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorms, fog, wind, and low visibility affect ATM decisions.'**
  String get lesson7Content1;

  /// No description provided for @lesson7Content2.
  ///
  /// In en, this message translates to:
  /// **'Bad weather may reduce arrival and departure rates.'**
  String get lesson7Content2;

  /// No description provided for @lesson7Content3.
  ///
  /// In en, this message translates to:
  /// **'Controllers must balance safety and efficiency.'**
  String get lesson7Content3;

  /// No description provided for @lesson7Q1Question.
  ///
  /// In en, this message translates to:
  /// **'What can bad weather cause?'**
  String get lesson7Q1Question;

  /// No description provided for @lesson7Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Reduced airport capacity'**
  String get lesson7Q1Option0;

  /// No description provided for @lesson7Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Free fuel'**
  String get lesson7Q1Option1;

  /// No description provided for @lesson7Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'No need for separation'**
  String get lesson7Q1Option2;

  /// No description provided for @lesson7Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Weather often reduces capacity and increases delay.'**
  String get lesson7Q1Explanation;

  /// No description provided for @lesson8Title.
  ///
  /// In en, this message translates to:
  /// **'Emergency and Abnormal Situations'**
  String get lesson8Title;

  /// No description provided for @lesson8Summary.
  ///
  /// In en, this message translates to:
  /// **'Emergencies require priority, calm decisions, and coordination.'**
  String get lesson8Summary;

  /// No description provided for @lesson8Content1.
  ///
  /// In en, this message translates to:
  /// **'Emergencies may include low fuel, medical events, radio failure, or technical problems.'**
  String get lesson8Content1;

  /// No description provided for @lesson8Content2.
  ///
  /// In en, this message translates to:
  /// **'Controllers give priority and coordinate with other units.'**
  String get lesson8Content2;

  /// No description provided for @lesson8Content3.
  ///
  /// In en, this message translates to:
  /// **'Clear communication is critical.'**
  String get lesson8Content3;

  /// No description provided for @lesson8Q1Question.
  ///
  /// In en, this message translates to:
  /// **'What should ATM prioritise during an emergency?'**
  String get lesson8Q1Question;

  /// No description provided for @lesson8Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get lesson8Q1Option0;

  /// No description provided for @lesson8Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Advertising'**
  String get lesson8Q1Option1;

  /// No description provided for @lesson8Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get lesson8Q1Option2;

  /// No description provided for @lesson8Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Safety is always the first priority in emergency handling.'**
  String get lesson8Q1Explanation;

  /// No description provided for @lesson9Title.
  ///
  /// In en, this message translates to:
  /// **'ATFCM and Flow Management'**
  String get lesson9Title;

  /// No description provided for @lesson9Summary.
  ///
  /// In en, this message translates to:
  /// **'Flow management balances demand and capacity.'**
  String get lesson9Summary;

  /// No description provided for @lesson9Content1.
  ///
  /// In en, this message translates to:
  /// **'ATFCM means Air Traffic Flow and Capacity Management.'**
  String get lesson9Content1;

  /// No description provided for @lesson9Content2.
  ///
  /// In en, this message translates to:
  /// **'It helps avoid overload in airports, sectors, and routes.'**
  String get lesson9Content2;

  /// No description provided for @lesson9Content3.
  ///
  /// In en, this message translates to:
  /// **'Measures may include delay programs, rerouting, or capacity planning.'**
  String get lesson9Content3;

  /// No description provided for @lesson9Q1Question.
  ///
  /// In en, this message translates to:
  /// **'What is the purpose of ATFCM?'**
  String get lesson9Q1Question;

  /// No description provided for @lesson9Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Balance traffic demand and capacity'**
  String get lesson9Q1Option0;

  /// No description provided for @lesson9Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Sell aircraft'**
  String get lesson9Q1Option1;

  /// No description provided for @lesson9Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Replace airports'**
  String get lesson9Q1Option2;

  /// No description provided for @lesson9Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'ATFCM manages traffic flow so the system does not become overloaded.'**
  String get lesson9Q1Explanation;

  /// No description provided for @lesson10Title.
  ///
  /// In en, this message translates to:
  /// **'Human Factors and Workload'**
  String get lesson10Title;

  /// No description provided for @lesson10Summary.
  ///
  /// In en, this message translates to:
  /// **'ATM safety depends on people, systems, and good decision making.'**
  String get lesson10Summary;

  /// No description provided for @lesson10Content1.
  ///
  /// In en, this message translates to:
  /// **'Controllers need situational awareness.'**
  String get lesson10Content1;

  /// No description provided for @lesson10Content2.
  ///
  /// In en, this message translates to:
  /// **'High workload can increase error risk.'**
  String get lesson10Content2;

  /// No description provided for @lesson10Content3.
  ///
  /// In en, this message translates to:
  /// **'Good interface design, training, and teamwork improve safety.'**
  String get lesson10Content3;

  /// No description provided for @lesson10Q1Question.
  ///
  /// In en, this message translates to:
  /// **'What is situational awareness?'**
  String get lesson10Q1Question;

  /// No description provided for @lesson10Q1Option0.
  ///
  /// In en, this message translates to:
  /// **'Understanding what is happening now and what may happen next'**
  String get lesson10Q1Option0;

  /// No description provided for @lesson10Q1Option1.
  ///
  /// In en, this message translates to:
  /// **'Ignoring aircraft positions'**
  String get lesson10Q1Option1;

  /// No description provided for @lesson10Q1Option2.
  ///
  /// In en, this message translates to:
  /// **'Only looking at weather'**
  String get lesson10Q1Option2;

  /// No description provided for @lesson10Q1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Situational awareness helps controllers make safe decisions.'**
  String get lesson10Q1Explanation;
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
      <String>['en', 'fr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
