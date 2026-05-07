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

  /// No description provided for @homeAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'ATM ACADEMY'**
  String get homeAppBarTitle;

  /// No description provided for @systemOnline.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM ONLINE'**
  String get systemOnline;

  /// No description provided for @systemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Air Traffic Management Learning Platform'**
  String get systemSubtitle;

  /// No description provided for @modulesSection.
  ///
  /// In en, this message translates to:
  /// **'MODULES'**
  String get modulesSection;

  /// No description provided for @homeCardLearnAtm.
  ///
  /// In en, this message translates to:
  /// **'Learn ATM'**
  String get homeCardLearnAtm;

  /// No description provided for @homeCardLearnAtmSub.
  ///
  /// In en, this message translates to:
  /// **'10 lessons · Beginner to Expert'**
  String get homeCardLearnAtmSub;

  /// No description provided for @homeCardRadarSim.
  ///
  /// In en, this message translates to:
  /// **'Radar Practice'**
  String get homeCardRadarSim;

  /// No description provided for @homeCardRadarSimSub.
  ///
  /// In en, this message translates to:
  /// **'Build skill through 10 progressive levels'**
  String get homeCardRadarSimSub;

  /// No description provided for @homeCardRunwayOps.
  ///
  /// In en, this message translates to:
  /// **'Runway Ops'**
  String get homeCardRunwayOps;

  /// No description provided for @homeCardRunwayOpsSub.
  ///
  /// In en, this message translates to:
  /// **'Ground movement & sequencing'**
  String get homeCardRunwayOpsSub;

  /// No description provided for @homeCardQuizSub.
  ///
  /// In en, this message translates to:
  /// **'Test your knowledge'**
  String get homeCardQuizSub;

  /// No description provided for @homeContribute.
  ///
  /// In en, this message translates to:
  /// **'Contribute'**
  String get homeContribute;

  /// No description provided for @homeContributeSub.
  ///
  /// In en, this message translates to:
  /// **'Built by ATM engineers — join us'**
  String get homeContributeSub;

  /// No description provided for @homeAboutSafety.
  ///
  /// In en, this message translates to:
  /// **'About & Safety'**
  String get homeAboutSafety;

  /// No description provided for @homeAboutSafetySub.
  ///
  /// In en, this message translates to:
  /// **'Compliance info'**
  String get homeAboutSafetySub;

  /// No description provided for @dailyChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'DAILY CHALLENGE'**
  String get dailyChallengeTitle;

  /// No description provided for @dailyChallengeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete today\'s training mission'**
  String get dailyChallengeSubtitle;

  /// No description provided for @dailyChallengeTaskQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get dailyChallengeTaskQuiz;

  /// No description provided for @dailyChallengeTaskRadar.
  ///
  /// In en, this message translates to:
  /// **'Radar Scenario'**
  String get dailyChallengeTaskRadar;

  /// No description provided for @dailyChallengeScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S SCORE'**
  String get dailyChallengeScoreLabel;

  /// No description provided for @dailyChallengeRankLabel.
  ///
  /// In en, this message translates to:
  /// **'RANK'**
  String get dailyChallengeRankLabel;

  /// No description provided for @dailyChallengeCompletedToday.
  ///
  /// In en, this message translates to:
  /// **'Completed Today'**
  String get dailyChallengeCompletedToday;

  /// No description provided for @dailyChallengeStartQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get dailyChallengeStartQuiz;

  /// No description provided for @dailyChallengeStartRadar.
  ///
  /// In en, this message translates to:
  /// **'Start Radar Sim'**
  String get dailyChallengeStartRadar;

  /// No description provided for @rankCadet.
  ///
  /// In en, this message translates to:
  /// **'Cadet'**
  String get rankCadet;

  /// No description provided for @rankControllerTrainee.
  ///
  /// In en, this message translates to:
  /// **'Controller Trainee'**
  String get rankControllerTrainee;

  /// No description provided for @rankTowerReady.
  ///
  /// In en, this message translates to:
  /// **'Tower Ready'**
  String get rankTowerReady;

  /// No description provided for @rankMissionComplete.
  ///
  /// In en, this message translates to:
  /// **'Mission Complete'**
  String get rankMissionComplete;

  /// No description provided for @radarSimTitle.
  ///
  /// In en, this message translates to:
  /// **'RADAR PRACTICE'**
  String get radarSimTitle;

  /// No description provided for @radarStatusConflict.
  ///
  /// In en, this message translates to:
  /// **'⚠ CONFLICT'**
  String get radarStatusConflict;

  /// No description provided for @radarStatusNormal.
  ///
  /// In en, this message translates to:
  /// **'● NORMAL'**
  String get radarStatusNormal;

  /// No description provided for @radarConflictAlert.
  ///
  /// In en, this message translates to:
  /// **'CONFLICT ALERT — AIRCRAFT TOO CLOSE'**
  String get radarConflictAlert;

  /// No description provided for @radarTrafficNormal.
  ///
  /// In en, this message translates to:
  /// **'TRAFFIC NORMAL — {count} TRACKS'**
  String radarTrafficNormal(int count);

  /// No description provided for @cmdTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'◀ Left'**
  String get cmdTurnLeft;

  /// No description provided for @cmdTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Right ▶'**
  String get cmdTurnRight;

  /// No description provided for @cmdClimb.
  ///
  /// In en, this message translates to:
  /// **'▲ Climb'**
  String get cmdClimb;

  /// No description provided for @cmdDescend.
  ///
  /// In en, this message translates to:
  /// **'▼ Descend'**
  String get cmdDescend;

  /// No description provided for @cmdSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get cmdSlow;

  /// No description provided for @cmdFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get cmdFast;

  /// No description provided for @radarScenarioCompleted.
  ///
  /// In en, this message translates to:
  /// **'Scenario Completed  +100 pts'**
  String get radarScenarioCompleted;

  /// No description provided for @radarCompleteScenario.
  ///
  /// In en, this message translates to:
  /// **'Complete Scenario'**
  String get radarCompleteScenario;

  /// No description provided for @radarScenarioSnackbar.
  ///
  /// In en, this message translates to:
  /// **'✓ Scenario complete  +100 pts added'**
  String get radarScenarioSnackbar;

  /// No description provided for @quizQuestionProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String quizQuestionProgress(int current, int total);

  /// No description provided for @quizCorrectLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get quizCorrectLabel;

  /// No description provided for @quizIncorrectLabel.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get quizIncorrectLabel;

  /// No description provided for @quizNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get quizNextQuestion;

  /// No description provided for @quizSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See Results'**
  String get quizSeeResults;

  /// No description provided for @quizPerfectScore.
  ///
  /// In en, this message translates to:
  /// **'Perfect Score!'**
  String get quizPerfectScore;

  /// No description provided for @quizGoodWork.
  ///
  /// In en, this message translates to:
  /// **'Good Work!'**
  String get quizGoodWork;

  /// No description provided for @quizKeepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep Practicing!'**
  String get quizKeepPracticing;

  /// No description provided for @quizTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get quizTryAgain;

  /// No description provided for @quizBackToLesson.
  ///
  /// In en, this message translates to:
  /// **'Back to Lesson'**
  String get quizBackToLesson;

  /// No description provided for @quizAppBarSuffix.
  ///
  /// In en, this message translates to:
  /// **'— Quiz'**
  String get quizAppBarSuffix;

  /// No description provided for @lessonsTitle.
  ///
  /// In en, this message translates to:
  /// **'ATM Lessons'**
  String get lessonsTitle;

  /// No description provided for @lessonsSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Lesson'**
  String get lessonsSelectTitle;

  /// No description provided for @keyPointsSection.
  ///
  /// In en, this message translates to:
  /// **'KEY POINTS'**
  String get keyPointsSection;

  /// No description provided for @startQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get startQuiz;

  /// No description provided for @contributeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'CONTRIBUTE'**
  String get contributeScreenTitle;

  /// No description provided for @contributeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Built by ATM Engineers'**
  String get contributeHeadline;

  /// No description provided for @contributeDescription.
  ///
  /// In en, this message translates to:
  /// **'ATM Academy is an open educational project for the aviation and ATM community. If you work in ATM, ATC, or aviation — your knowledge can help others learn.'**
  String get contributeDescription;

  /// No description provided for @contributeHowToSection.
  ///
  /// In en, this message translates to:
  /// **'HOW TO CONTRIBUTE'**
  String get contributeHowToSection;

  /// No description provided for @contributeSuggestLesson.
  ///
  /// In en, this message translates to:
  /// **'Suggest a Lesson'**
  String get contributeSuggestLesson;

  /// No description provided for @contributeSuggestLessonDesc.
  ///
  /// In en, this message translates to:
  /// **'Propose a new topic, lesson outline, or learning objective.'**
  String get contributeSuggestLessonDesc;

  /// No description provided for @contributeImproveQuiz.
  ///
  /// In en, this message translates to:
  /// **'Improve a Quiz'**
  String get contributeImproveQuiz;

  /// No description provided for @contributeImproveQuizDesc.
  ///
  /// In en, this message translates to:
  /// **'Suggest better questions, correct inaccuracies, or add explanations.'**
  String get contributeImproveQuizDesc;

  /// No description provided for @contributeAddScenario.
  ///
  /// In en, this message translates to:
  /// **'Add a Simulation Scenario'**
  String get contributeAddScenario;

  /// No description provided for @contributeAddScenarioDesc.
  ///
  /// In en, this message translates to:
  /// **'Design a radar scenario, conflict situation, or runway exercise.'**
  String get contributeAddScenarioDesc;

  /// No description provided for @contributeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'GET STARTED'**
  String get contributeGetStarted;

  /// No description provided for @contributeGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get contributeGithub;

  /// No description provided for @contributeContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contributeContact;

  /// No description provided for @contributeDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'All contributions must use publicly available, generic ATM knowledge only.\nNo proprietary, confidential, or restricted information.'**
  String get contributeDisclaimer;

  /// No description provided for @aboutScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'ABOUT & SAFETY'**
  String get aboutScreenTitle;

  /// No description provided for @aboutSafetyDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety Disclaimer'**
  String get aboutSafetyDisclaimerTitle;

  /// No description provided for @aboutSafetyDisclaimerContent.
  ///
  /// In en, this message translates to:
  /// **'This application is designed for general aviation and ATM education only.\n\n• It is NOT an operational ATC system.\n• It must NOT be used for real-world operational decision-making.\n• All simulations are simplified and do not represent real ATM procedures.\n• No real aircraft, airspace, or operational data is used.'**
  String get aboutSafetyDisclaimerContent;

  /// No description provided for @aboutContentComplianceTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Compliance'**
  String get aboutContentComplianceTitle;

  /// No description provided for @aboutContentComplianceContent.
  ///
  /// In en, this message translates to:
  /// **'ATM Academy uses only publicly available, generic ATM/ATC knowledge.\n\n• No proprietary, confidential, or restricted information is included.\n• No information from any commercial ATM system vendor is used.\n• Content is based on publicly available ICAO, EUROCONTROL, and FAA materials.'**
  String get aboutContentComplianceContent;

  /// No description provided for @aboutAppSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'About ATM Academy'**
  String get aboutAppSectionTitle;

  /// No description provided for @aboutAppSectionContent.
  ///
  /// In en, this message translates to:
  /// **'ATM Academy is an open educational project created by ATM engineers for the aviation and ATM learning community.\n\nVersion: 1.0.0\nPlatform: Mobile app\n\nFor feedback and contributions, visit the project page.'**
  String get aboutAppSectionContent;

  /// No description provided for @aboutNoCertificationTitle.
  ///
  /// In en, this message translates to:
  /// **'No Official Certification'**
  String get aboutNoCertificationTitle;

  /// No description provided for @aboutNoCertificationContent.
  ///
  /// In en, this message translates to:
  /// **'This app does not provide, imply, or replace any form of official ATC training, licensing, or certification.\n\nFor official ATC training, consult your national aviation authority or an approved ATC training organisation.'**
  String get aboutNoCertificationContent;

  /// No description provided for @whatIsAtmTitle.
  ///
  /// In en, this message translates to:
  /// **'What is ATM?'**
  String get whatIsAtmTitle;

  /// No description provided for @whatIsAtmSummary.
  ///
  /// In en, this message translates to:
  /// **'Air Traffic Management keeps aircraft moving safely and efficiently across the world.'**
  String get whatIsAtmSummary;

  /// No description provided for @whatIsAtmPoint1.
  ///
  /// In en, this message translates to:
  /// **'ATM = Air Traffic Management: the dynamic, integrated management of air traffic.'**
  String get whatIsAtmPoint1;

  /// No description provided for @whatIsAtmPoint2.
  ///
  /// In en, this message translates to:
  /// **'Three pillars: Air Traffic Control (ATC), Airspace Management (ASM), Air Traffic Flow Management (ATFM).'**
  String get whatIsAtmPoint2;

  /// No description provided for @whatIsAtmPoint3.
  ///
  /// In en, this message translates to:
  /// **'Core goals: Safety, Efficiency, Order, and Capacity.'**
  String get whatIsAtmPoint3;

  /// No description provided for @whatIsAtmQ1Question.
  ///
  /// In en, this message translates to:
  /// **'What does ATM stand for?'**
  String get whatIsAtmQ1Question;

  /// No description provided for @whatIsAtmQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Automated Teller Machine'**
  String get whatIsAtmQ1O0;

  /// No description provided for @whatIsAtmQ1O1.
  ///
  /// In en, this message translates to:
  /// **'Air Traffic Management'**
  String get whatIsAtmQ1O1;

  /// No description provided for @whatIsAtmQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Aircraft Terminal Monitor'**
  String get whatIsAtmQ1O2;

  /// No description provided for @whatIsAtmQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'ATM stands for Air Traffic Management — the system that keeps all aircraft safe and efficient.'**
  String get whatIsAtmQ1Explanation;

  /// No description provided for @whatIsAtmQ2Question.
  ///
  /// In en, this message translates to:
  /// **'Which of these is NOT one of the three pillars of ATM?'**
  String get whatIsAtmQ2Question;

  /// No description provided for @whatIsAtmQ2O0.
  ///
  /// In en, this message translates to:
  /// **'Air Traffic Control'**
  String get whatIsAtmQ2O0;

  /// No description provided for @whatIsAtmQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Airline ticketing'**
  String get whatIsAtmQ2O1;

  /// No description provided for @whatIsAtmQ2O2.
  ///
  /// In en, this message translates to:
  /// **'Airspace Management'**
  String get whatIsAtmQ2O2;

  /// No description provided for @whatIsAtmQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'Airline ticketing is a commercial function, not part of ATM. The three pillars are ATC, ASM, and ATFM.'**
  String get whatIsAtmQ2Explanation;

  /// No description provided for @whatIsAtmQ3Question.
  ///
  /// In en, this message translates to:
  /// **'What is the primary goal of ATM?'**
  String get whatIsAtmQ3Question;

  /// No description provided for @whatIsAtmQ3O0.
  ///
  /// In en, this message translates to:
  /// **'Maximize airline profit'**
  String get whatIsAtmQ3O0;

  /// No description provided for @whatIsAtmQ3O1.
  ///
  /// In en, this message translates to:
  /// **'Safety and efficient movement of aircraft'**
  String get whatIsAtmQ3O1;

  /// No description provided for @whatIsAtmQ3O2.
  ///
  /// In en, this message translates to:
  /// **'Reduce fuel prices'**
  String get whatIsAtmQ3O2;

  /// No description provided for @whatIsAtmQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'Safety is always the first priority in ATM, followed by efficiency and order.'**
  String get whatIsAtmQ3Explanation;

  /// No description provided for @airspaceBasicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Airspace Basics'**
  String get airspaceBasicsTitle;

  /// No description provided for @airspaceBasicsSummary.
  ///
  /// In en, this message translates to:
  /// **'Airspace is divided into classes and regions to manage traffic safely.'**
  String get airspaceBasicsSummary;

  /// No description provided for @airspaceBasicsPoint1.
  ///
  /// In en, this message translates to:
  /// **'Airspace classes A–G define rules for who can fly there and what services they receive.'**
  String get airspaceBasicsPoint1;

  /// No description provided for @airspaceBasicsPoint2.
  ///
  /// In en, this message translates to:
  /// **'Controlled airspace requires ATC clearance. Uncontrolled airspace (Class G) does not.'**
  String get airspaceBasicsPoint2;

  /// No description provided for @airspaceBasicsPoint3.
  ///
  /// In en, this message translates to:
  /// **'A Flight Information Region (FIR) is a large volume of airspace managed by one centre.'**
  String get airspaceBasicsPoint3;

  /// No description provided for @airspaceBasicsQ1Question.
  ///
  /// In en, this message translates to:
  /// **'Class A airspace is:'**
  String get airspaceBasicsQ1Question;

  /// No description provided for @airspaceBasicsQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Fully controlled, IFR only'**
  String get airspaceBasicsQ1O0;

  /// No description provided for @airspaceBasicsQ1O1.
  ///
  /// In en, this message translates to:
  /// **'Uncontrolled, VFR only'**
  String get airspaceBasicsQ1O1;

  /// No description provided for @airspaceBasicsQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Open to all without clearance'**
  String get airspaceBasicsQ1O2;

  /// No description provided for @airspaceBasicsQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Class A is the most restrictive: only IFR flights with ATC clearance are allowed.'**
  String get airspaceBasicsQ1Explanation;

  /// No description provided for @airspaceBasicsQ2Question.
  ///
  /// In en, this message translates to:
  /// **'What is a FIR?'**
  String get airspaceBasicsQ2Question;

  /// No description provided for @airspaceBasicsQ2O0.
  ///
  /// In en, this message translates to:
  /// **'A type of aircraft radar'**
  String get airspaceBasicsQ2O0;

  /// No description provided for @airspaceBasicsQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Flight Information Region'**
  String get airspaceBasicsQ2O1;

  /// No description provided for @airspaceBasicsQ2O2.
  ///
  /// In en, this message translates to:
  /// **'A runway marking system'**
  String get airspaceBasicsQ2O2;

  /// No description provided for @airspaceBasicsQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'A FIR (Flight Information Region) is a defined volume of airspace managed by an air traffic services provider.'**
  String get airspaceBasicsQ2Explanation;

  /// No description provided for @airspaceBasicsQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Which class requires no ATC clearance?'**
  String get airspaceBasicsQ3Question;

  /// No description provided for @airspaceBasicsQ3O0.
  ///
  /// In en, this message translates to:
  /// **'Class A'**
  String get airspaceBasicsQ3O0;

  /// No description provided for @airspaceBasicsQ3O1.
  ///
  /// In en, this message translates to:
  /// **'Class C'**
  String get airspaceBasicsQ3O1;

  /// No description provided for @airspaceBasicsQ3O2.
  ///
  /// In en, this message translates to:
  /// **'Class G'**
  String get airspaceBasicsQ3O2;

  /// No description provided for @airspaceBasicsQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'Class G is uncontrolled airspace — flights operate without ATC clearance, though information services may exist.'**
  String get airspaceBasicsQ3Explanation;

  /// No description provided for @radarBasicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Radar Basics'**
  String get radarBasicsTitle;

  /// No description provided for @radarBasicsSummary.
  ///
  /// In en, this message translates to:
  /// **'Radar is the primary tool controllers use to see aircraft position and movement.'**
  String get radarBasicsSummary;

  /// No description provided for @radarBasicsPoint1.
  ///
  /// In en, this message translates to:
  /// **'Primary Surveillance Radar (PSR) detects reflections of radio waves off aircraft.'**
  String get radarBasicsPoint1;

  /// No description provided for @radarBasicsPoint2.
  ///
  /// In en, this message translates to:
  /// **'Secondary Surveillance Radar (SSR) interrogates transponders — giving callsign, altitude, and speed.'**
  String get radarBasicsPoint2;

  /// No description provided for @radarBasicsPoint3.
  ///
  /// In en, this message translates to:
  /// **'Aircraft appear as \"blips\" on the display, updated each radar rotation (typically 4–12 seconds).'**
  String get radarBasicsPoint3;

  /// No description provided for @radarBasicsQ1Question.
  ///
  /// In en, this message translates to:
  /// **'What does SSR stand for?'**
  String get radarBasicsQ1Question;

  /// No description provided for @radarBasicsQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Secondary Surveillance Radar'**
  String get radarBasicsQ1O0;

  /// No description provided for @radarBasicsQ1O1.
  ///
  /// In en, this message translates to:
  /// **'Speed and Separation Record'**
  String get radarBasicsQ1O1;

  /// No description provided for @radarBasicsQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Standard Separation Rule'**
  String get radarBasicsQ1O2;

  /// No description provided for @radarBasicsQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'SSR (Secondary Surveillance Radar) interrogates aircraft transponders to provide identification and altitude data.'**
  String get radarBasicsQ1Explanation;

  /// No description provided for @radarBasicsQ2Question.
  ///
  /// In en, this message translates to:
  /// **'What is an aircraft \"blip\" on radar?'**
  String get radarBasicsQ2Question;

  /// No description provided for @radarBasicsQ2O0.
  ///
  /// In en, this message translates to:
  /// **'A sound the controller hears'**
  String get radarBasicsQ2O0;

  /// No description provided for @radarBasicsQ2O1.
  ///
  /// In en, this message translates to:
  /// **'A visual indicator of the aircraft position'**
  String get radarBasicsQ2O1;

  /// No description provided for @radarBasicsQ2O2.
  ///
  /// In en, this message translates to:
  /// **'An error in the radar system'**
  String get radarBasicsQ2O2;

  /// No description provided for @radarBasicsQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'A blip is the return shown on the radar display representing the aircraft\'s detected position.'**
  String get radarBasicsQ2Explanation;

  /// No description provided for @radarBasicsQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Primary radar works by:'**
  String get radarBasicsQ3Question;

  /// No description provided for @radarBasicsQ3O0.
  ///
  /// In en, this message translates to:
  /// **'Asking aircraft to send their position'**
  String get radarBasicsQ3O0;

  /// No description provided for @radarBasicsQ3O1.
  ///
  /// In en, this message translates to:
  /// **'Detecting reflected radio waves off the aircraft'**
  String get radarBasicsQ3O1;

  /// No description provided for @radarBasicsQ3O2.
  ///
  /// In en, this message translates to:
  /// **'Using GPS satellite data'**
  String get radarBasicsQ3O2;

  /// No description provided for @radarBasicsQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'Primary radar emits radio pulses and detects the echo reflected back from aircraft.'**
  String get radarBasicsQ3Explanation;

  /// No description provided for @separationBasicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Separation Basics'**
  String get separationBasicsTitle;

  /// No description provided for @separationBasicsSummary.
  ///
  /// In en, this message translates to:
  /// **'Maintaining separation between aircraft is the core safety task of ATC.'**
  String get separationBasicsSummary;

  /// No description provided for @separationBasicsPoint1.
  ///
  /// In en, this message translates to:
  /// **'Vertical separation: aircraft at different altitudes (e.g., 1000 ft minimum below FL290).'**
  String get separationBasicsPoint1;

  /// No description provided for @separationBasicsPoint2.
  ///
  /// In en, this message translates to:
  /// **'Horizontal separation: lateral (side-by-side) and longitudinal (one behind another).'**
  String get separationBasicsPoint2;

  /// No description provided for @separationBasicsPoint3.
  ///
  /// In en, this message translates to:
  /// **'A Loss of Separation (LOS) is a serious incident and must be reported and investigated.'**
  String get separationBasicsPoint3;

  /// No description provided for @separationBasicsQ1Question.
  ///
  /// In en, this message translates to:
  /// **'What is vertical separation?'**
  String get separationBasicsQ1Question;

  /// No description provided for @separationBasicsQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Aircraft side by side at same altitude'**
  String get separationBasicsQ1O0;

  /// No description provided for @separationBasicsQ1O1.
  ///
  /// In en, this message translates to:
  /// **'Aircraft at different altitudes'**
  String get separationBasicsQ1O1;

  /// No description provided for @separationBasicsQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Aircraft separated by time only'**
  String get separationBasicsQ1O2;

  /// No description provided for @separationBasicsQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Vertical separation keeps aircraft at different flight levels to prevent collision.'**
  String get separationBasicsQ1Explanation;

  /// No description provided for @separationBasicsQ2Question.
  ///
  /// In en, this message translates to:
  /// **'A Loss of Separation means:'**
  String get separationBasicsQ2Question;

  /// No description provided for @separationBasicsQ2O0.
  ///
  /// In en, this message translates to:
  /// **'An aircraft changed frequency'**
  String get separationBasicsQ2O0;

  /// No description provided for @separationBasicsQ2O1.
  ///
  /// In en, this message translates to:
  /// **'The minimum required distance was not maintained'**
  String get separationBasicsQ2O1;

  /// No description provided for @separationBasicsQ2O2.
  ///
  /// In en, this message translates to:
  /// **'A pilot requested descent'**
  String get separationBasicsQ2O2;

  /// No description provided for @separationBasicsQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'Loss of separation occurs when aircraft come closer than the prescribed minimum, which is a serious safety event.'**
  String get separationBasicsQ2Explanation;

  /// No description provided for @separationBasicsQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Longitudinal separation refers to:'**
  String get separationBasicsQ3Question;

  /// No description provided for @separationBasicsQ3O0.
  ///
  /// In en, this message translates to:
  /// **'Aircraft at different altitudes'**
  String get separationBasicsQ3O0;

  /// No description provided for @separationBasicsQ3O1.
  ///
  /// In en, this message translates to:
  /// **'Aircraft separated in the direction of flight'**
  String get separationBasicsQ3O1;

  /// No description provided for @separationBasicsQ3O2.
  ///
  /// In en, this message translates to:
  /// **'Aircraft at different airports'**
  String get separationBasicsQ3O2;

  /// No description provided for @separationBasicsQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'Longitudinal separation maintains distance between aircraft flying one behind the other on the same route.'**
  String get separationBasicsQ3Explanation;

  /// No description provided for @runwayOperationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Runway Operations'**
  String get runwayOperationsTitle;

  /// No description provided for @runwayOperationsSummary.
  ///
  /// In en, this message translates to:
  /// **'Runway safety is the highest priority in airport operations.'**
  String get runwayOperationsSummary;

  /// No description provided for @runwayOperationsPoint1.
  ///
  /// In en, this message translates to:
  /// **'Runways are designated by magnetic heading (e.g., Runway 27L means 270° heading, left of parallel).'**
  String get runwayOperationsPoint1;

  /// No description provided for @runwayOperationsPoint2.
  ///
  /// In en, this message translates to:
  /// **'Runway incursion: an unauthorised presence on the runway — a top safety concern.'**
  String get runwayOperationsPoint2;

  /// No description provided for @runwayOperationsPoint3.
  ///
  /// In en, this message translates to:
  /// **'Tower sequencing: controllers manage arrivals and departures to maximise runway throughput safely.'**
  String get runwayOperationsPoint3;

  /// No description provided for @runwayOperationsQ1Question.
  ///
  /// In en, this message translates to:
  /// **'Runway 09 points towards which direction?'**
  String get runwayOperationsQ1Question;

  /// No description provided for @runwayOperationsQ1O0.
  ///
  /// In en, this message translates to:
  /// **'West (270°)'**
  String get runwayOperationsQ1O0;

  /// No description provided for @runwayOperationsQ1O1.
  ///
  /// In en, this message translates to:
  /// **'East (090°)'**
  String get runwayOperationsQ1O1;

  /// No description provided for @runwayOperationsQ1O2.
  ///
  /// In en, this message translates to:
  /// **'North (360°)'**
  String get runwayOperationsQ1O2;

  /// No description provided for @runwayOperationsQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Runway numbers indicate the magnetic heading in tens of degrees. Runway 09 = 090° = East.'**
  String get runwayOperationsQ1Explanation;

  /// No description provided for @runwayOperationsQ2Question.
  ///
  /// In en, this message translates to:
  /// **'What is a runway incursion?'**
  String get runwayOperationsQ2Question;

  /// No description provided for @runwayOperationsQ2O0.
  ///
  /// In en, this message translates to:
  /// **'A normal landing procedure'**
  String get runwayOperationsQ2O0;

  /// No description provided for @runwayOperationsQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Any unauthorised presence on an active runway'**
  String get runwayOperationsQ2O1;

  /// No description provided for @runwayOperationsQ2O2.
  ///
  /// In en, this message translates to:
  /// **'A runway lighting failure'**
  String get runwayOperationsQ2O2;

  /// No description provided for @runwayOperationsQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'A runway incursion is any occurrence where an aircraft, vehicle, or person is on a runway without clearance.'**
  String get runwayOperationsQ2Explanation;

  /// No description provided for @runwayOperationsQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Who is responsible for runway sequencing at an airport?'**
  String get runwayOperationsQ3Question;

  /// No description provided for @runwayOperationsQ3O0.
  ///
  /// In en, this message translates to:
  /// **'The airline operations centre'**
  String get runwayOperationsQ3O0;

  /// No description provided for @runwayOperationsQ3O1.
  ///
  /// In en, this message translates to:
  /// **'The Tower controller'**
  String get runwayOperationsQ3O1;

  /// No description provided for @runwayOperationsQ3O2.
  ///
  /// In en, this message translates to:
  /// **'The ground handling agent'**
  String get runwayOperationsQ3O2;

  /// No description provided for @runwayOperationsQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'The Tower controller manages all runway movements — takeoffs, landings, and crossing traffic.'**
  String get runwayOperationsQ3Explanation;

  /// No description provided for @atcPhraseologyTitle.
  ///
  /// In en, this message translates to:
  /// **'ATC Phraseology'**
  String get atcPhraseologyTitle;

  /// No description provided for @atcPhraseologySummary.
  ///
  /// In en, this message translates to:
  /// **'Standard phrases prevent misunderstandings and ensure clear, efficient communication.'**
  String get atcPhraseologySummary;

  /// No description provided for @atcPhraseologyPoint1.
  ///
  /// In en, this message translates to:
  /// **'\"Cleared\" means ATC authorises an action. Never act without a clearance.'**
  String get atcPhraseologyPoint1;

  /// No description provided for @atcPhraseologyPoint2.
  ///
  /// In en, this message translates to:
  /// **'Read-back required: pilots must repeat key instructions to confirm correct receipt.'**
  String get atcPhraseologyPoint2;

  /// No description provided for @atcPhraseologyPoint3.
  ///
  /// In en, this message translates to:
  /// **'ICAO standard phraseology is used globally to minimise language barrier errors.'**
  String get atcPhraseologyPoint3;

  /// No description provided for @atcPhraseologyQ1Question.
  ///
  /// In en, this message translates to:
  /// **'If a pilot does not read back a clearance, what should the controller do?'**
  String get atcPhraseologyQ1Question;

  /// No description provided for @atcPhraseologyQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Assume the pilot understood'**
  String get atcPhraseologyQ1O0;

  /// No description provided for @atcPhraseologyQ1O1.
  ///
  /// In en, this message translates to:
  /// **'Re-issue the clearance and request read-back'**
  String get atcPhraseologyQ1O1;

  /// No description provided for @atcPhraseologyQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Transfer to another frequency'**
  String get atcPhraseologyQ1O2;

  /// No description provided for @atcPhraseologyQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Read-back is essential for safety. The controller must ensure the clearance is correctly acknowledged.'**
  String get atcPhraseologyQ1Explanation;

  /// No description provided for @atcPhraseologyQ2Question.
  ///
  /// In en, this message translates to:
  /// **'The word \"CLEARED\" in ATC means:'**
  String get atcPhraseologyQ2Question;

  /// No description provided for @atcPhraseologyQ2O0.
  ///
  /// In en, this message translates to:
  /// **'Visibility is good'**
  String get atcPhraseologyQ2O0;

  /// No description provided for @atcPhraseologyQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Authorised to proceed as specified'**
  String get atcPhraseologyQ2O1;

  /// No description provided for @atcPhraseologyQ2O2.
  ///
  /// In en, this message translates to:
  /// **'The aircraft is clean (no flaps)'**
  String get atcPhraseologyQ2O2;

  /// No description provided for @atcPhraseologyQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'\"Cleared\" is an ATC authorisation for a specific action, such as takeoff, landing, or a route.'**
  String get atcPhraseologyQ2Explanation;

  /// No description provided for @atcPhraseologyQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Why is ICAO standard phraseology important?'**
  String get atcPhraseologyQ3Question;

  /// No description provided for @atcPhraseologyQ3O0.
  ///
  /// In en, this message translates to:
  /// **'It makes flights faster'**
  String get atcPhraseologyQ3O0;

  /// No description provided for @atcPhraseologyQ3O1.
  ///
  /// In en, this message translates to:
  /// **'It reduces misunderstandings across language barriers'**
  String get atcPhraseologyQ3O1;

  /// No description provided for @atcPhraseologyQ3O2.
  ///
  /// In en, this message translates to:
  /// **'It is only used in Europe'**
  String get atcPhraseologyQ3O2;

  /// No description provided for @atcPhraseologyQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'Standard phraseology gives controllers and pilots a shared language, reducing the risk of miscommunication.'**
  String get atcPhraseologyQ3Explanation;

  /// No description provided for @flightPhasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Flight Phases'**
  String get flightPhasesTitle;

  /// No description provided for @flightPhasesSummary.
  ///
  /// In en, this message translates to:
  /// **'Each phase of flight involves different controllers and procedures.'**
  String get flightPhasesSummary;

  /// No description provided for @flightPhasesPoint1.
  ///
  /// In en, this message translates to:
  /// **'Pre-departure → Clearance Delivery → Ground → Tower → Departure → En-route → Approach → Tower → Parking.'**
  String get flightPhasesPoint1;

  /// No description provided for @flightPhasesPoint2.
  ///
  /// In en, this message translates to:
  /// **'Each handoff between controllers must include position, altitude, and clearance information.'**
  String get flightPhasesPoint2;

  /// No description provided for @flightPhasesPoint3.
  ///
  /// In en, this message translates to:
  /// **'The en-route phase (cruise) covers the longest segment and is managed by Area Control Centres (ACC).'**
  String get flightPhasesPoint3;

  /// No description provided for @flightPhasesQ1Question.
  ///
  /// In en, this message translates to:
  /// **'Which controller handles an aircraft during cruise between airports?'**
  String get flightPhasesQ1Question;

  /// No description provided for @flightPhasesQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Tower controller'**
  String get flightPhasesQ1O0;

  /// No description provided for @flightPhasesQ1O1.
  ///
  /// In en, this message translates to:
  /// **'En-route (ACC) controller'**
  String get flightPhasesQ1O1;

  /// No description provided for @flightPhasesQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Ground controller'**
  String get flightPhasesQ1O2;

  /// No description provided for @flightPhasesQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'The en-route controller at an Area Control Centre (ACC) manages aircraft during the cruise phase.'**
  String get flightPhasesQ1Explanation;

  /// No description provided for @flightPhasesQ2Question.
  ///
  /// In en, this message translates to:
  /// **'What must be included in a controller handoff?'**
  String get flightPhasesQ2Question;

  /// No description provided for @flightPhasesQ2O0.
  ///
  /// In en, this message translates to:
  /// **'Passenger count only'**
  String get flightPhasesQ2O0;

  /// No description provided for @flightPhasesQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Position, altitude, and clearance information'**
  String get flightPhasesQ2O1;

  /// No description provided for @flightPhasesQ2O2.
  ///
  /// In en, this message translates to:
  /// **'Aircraft colour and type only'**
  String get flightPhasesQ2O2;

  /// No description provided for @flightPhasesQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'A proper handoff ensures the receiving controller has all information needed to maintain safe separation.'**
  String get flightPhasesQ2Explanation;

  /// No description provided for @flightPhasesQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Clearance Delivery is used to:'**
  String get flightPhasesQ3Question;

  /// No description provided for @flightPhasesQ3O0.
  ///
  /// In en, this message translates to:
  /// **'Approve the aircraft\'s route and flight plan before taxi'**
  String get flightPhasesQ3O0;

  /// No description provided for @flightPhasesQ3O1.
  ///
  /// In en, this message translates to:
  /// **'Load bags into the aircraft'**
  String get flightPhasesQ3O1;

  /// No description provided for @flightPhasesQ3O2.
  ///
  /// In en, this message translates to:
  /// **'Refuel the aircraft'**
  String get flightPhasesQ3O2;

  /// No description provided for @flightPhasesQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'Clearance Delivery is the first ATC contact for departing flights, issuing the route, squawk code, and departure instructions.'**
  String get flightPhasesQ3Explanation;

  /// No description provided for @conflictAwarenessTitle.
  ///
  /// In en, this message translates to:
  /// **'Conflict Awareness'**
  String get conflictAwarenessTitle;

  /// No description provided for @conflictAwarenessSummary.
  ///
  /// In en, this message translates to:
  /// **'Recognising and resolving conflicts early is a key controller skill.'**
  String get conflictAwarenessSummary;

  /// No description provided for @conflictAwarenessPoint1.
  ///
  /// In en, this message translates to:
  /// **'STCA (Short-Term Conflict Alert) warns controllers when aircraft are projected to come too close.'**
  String get conflictAwarenessPoint1;

  /// No description provided for @conflictAwarenessPoint2.
  ///
  /// In en, this message translates to:
  /// **'Resolution options: change heading, speed, or altitude of one or both aircraft.'**
  String get conflictAwarenessPoint2;

  /// No description provided for @conflictAwarenessPoint3.
  ///
  /// In en, this message translates to:
  /// **'Proactive planning — anticipating conflicts before they develop — reduces workload and risk.'**
  String get conflictAwarenessPoint3;

  /// No description provided for @conflictAwarenessQ1Question.
  ///
  /// In en, this message translates to:
  /// **'What does STCA stand for?'**
  String get conflictAwarenessQ1Question;

  /// No description provided for @conflictAwarenessQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Short-Term Conflict Alert'**
  String get conflictAwarenessQ1O0;

  /// No description provided for @conflictAwarenessQ1O1.
  ///
  /// In en, this message translates to:
  /// **'Standard Traffic Control Announcement'**
  String get conflictAwarenessQ1O1;

  /// No description provided for @conflictAwarenessQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Speed and Track Control Aid'**
  String get conflictAwarenessQ1O2;

  /// No description provided for @conflictAwarenessQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'STCA is a safety net tool that alerts controllers when aircraft are predicted to lose separation.'**
  String get conflictAwarenessQ1Explanation;

  /// No description provided for @conflictAwarenessQ2Question.
  ///
  /// In en, this message translates to:
  /// **'Which of these resolves a conflict between two aircraft at the same altitude and converging?'**
  String get conflictAwarenessQ2Question;

  /// No description provided for @conflictAwarenessQ2O0.
  ///
  /// In en, this message translates to:
  /// **'Asking both pilots to speed up'**
  String get conflictAwarenessQ2O0;

  /// No description provided for @conflictAwarenessQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Issuing a climb to one aircraft'**
  String get conflictAwarenessQ2O1;

  /// No description provided for @conflictAwarenessQ2O2.
  ///
  /// In en, this message translates to:
  /// **'Changing the callsign of one aircraft'**
  String get conflictAwarenessQ2O2;

  /// No description provided for @conflictAwarenessQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'Assigning a different altitude provides immediate vertical separation between conflicting aircraft.'**
  String get conflictAwarenessQ2Explanation;

  /// No description provided for @conflictAwarenessQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Proactive conflict management means:'**
  String get conflictAwarenessQ3Question;

  /// No description provided for @conflictAwarenessQ3O0.
  ///
  /// In en, this message translates to:
  /// **'Waiting until STCA triggers before acting'**
  String get conflictAwarenessQ3O0;

  /// No description provided for @conflictAwarenessQ3O1.
  ///
  /// In en, this message translates to:
  /// **'Anticipating conflicts and resolving them early'**
  String get conflictAwarenessQ3O1;

  /// No description provided for @conflictAwarenessQ3O2.
  ///
  /// In en, this message translates to:
  /// **'Relying on pilots to avoid each other'**
  String get conflictAwarenessQ3O2;

  /// No description provided for @conflictAwarenessQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'Good controllers anticipate conflicts from the traffic picture and resolve them before they become critical.'**
  String get conflictAwarenessQ3Explanation;

  /// No description provided for @towerApproachEnrouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Tower, Approach, and En-route'**
  String get towerApproachEnrouteTitle;

  /// No description provided for @towerApproachEnrouteSummary.
  ///
  /// In en, this message translates to:
  /// **'Three main ATC units each control a distinct phase and volume of airspace.'**
  String get towerApproachEnrouteSummary;

  /// No description provided for @towerApproachEnroutePoint1.
  ///
  /// In en, this message translates to:
  /// **'Tower (TWR): controls the manoeuvring area — runways, taxiways, and the airport circuit.'**
  String get towerApproachEnroutePoint1;

  /// No description provided for @towerApproachEnroutePoint2.
  ///
  /// In en, this message translates to:
  /// **'Approach (APP): manages arrivals and departures in the Terminal Manoeuvring Area (TMA), typically up to FL100–FL245.'**
  String get towerApproachEnroutePoint2;

  /// No description provided for @towerApproachEnroutePoint3.
  ///
  /// In en, this message translates to:
  /// **'En-route (ACC): controls cruise traffic in upper airspace, often from FL245 and above.'**
  String get towerApproachEnroutePoint3;

  /// No description provided for @towerApproachEnrouteQ1Question.
  ///
  /// In en, this message translates to:
  /// **'Which unit controls aircraft on the taxiway?'**
  String get towerApproachEnrouteQ1Question;

  /// No description provided for @towerApproachEnrouteQ1O0.
  ///
  /// In en, this message translates to:
  /// **'Area Control Centre (ACC)'**
  String get towerApproachEnrouteQ1O0;

  /// No description provided for @towerApproachEnrouteQ1O1.
  ///
  /// In en, this message translates to:
  /// **'Tower (TWR)'**
  String get towerApproachEnrouteQ1O1;

  /// No description provided for @towerApproachEnrouteQ1O2.
  ///
  /// In en, this message translates to:
  /// **'Approach (APP)'**
  String get towerApproachEnrouteQ1O2;

  /// No description provided for @towerApproachEnrouteQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'Tower (TWR) controls ground movement including taxiways, holding points, and the active runway.'**
  String get towerApproachEnrouteQ1Explanation;

  /// No description provided for @towerApproachEnrouteQ2Question.
  ///
  /// In en, this message translates to:
  /// **'TMA stands for:'**
  String get towerApproachEnrouteQ2Question;

  /// No description provided for @towerApproachEnrouteQ2O0.
  ///
  /// In en, this message translates to:
  /// **'Terminal Manoeuvring Area'**
  String get towerApproachEnrouteQ2O0;

  /// No description provided for @towerApproachEnrouteQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Traffic Management Authority'**
  String get towerApproachEnrouteQ2O1;

  /// No description provided for @towerApproachEnrouteQ2O2.
  ///
  /// In en, this message translates to:
  /// **'Tower Monitoring Area'**
  String get towerApproachEnrouteQ2O2;

  /// No description provided for @towerApproachEnrouteQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'TMA (Terminal Manoeuvring Area) is the controlled airspace around busy airports, managed by Approach control.'**
  String get towerApproachEnrouteQ2Explanation;

  /// No description provided for @towerApproachEnrouteQ3Question.
  ///
  /// In en, this message translates to:
  /// **'At what level does en-route control typically begin?'**
  String get towerApproachEnrouteQ3Question;

  /// No description provided for @towerApproachEnrouteQ3O0.
  ///
  /// In en, this message translates to:
  /// **'Ground level'**
  String get towerApproachEnrouteQ3O0;

  /// No description provided for @towerApproachEnrouteQ3O1.
  ///
  /// In en, this message translates to:
  /// **'Around FL245 and above'**
  String get towerApproachEnrouteQ3O1;

  /// No description provided for @towerApproachEnrouteQ3O2.
  ///
  /// In en, this message translates to:
  /// **'At exactly FL100'**
  String get towerApproachEnrouteQ3O2;

  /// No description provided for @towerApproachEnrouteQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'En-route (ACC) control typically begins around FL245, though this varies by country and airspace design.'**
  String get towerApproachEnrouteQ3Explanation;

  /// No description provided for @futureAtmTitle.
  ///
  /// In en, this message translates to:
  /// **'Future ATM & Automation'**
  String get futureAtmTitle;

  /// No description provided for @futureAtmSummary.
  ///
  /// In en, this message translates to:
  /// **'The future of ATM is digital, connected, and increasingly automated — but humans remain central.'**
  String get futureAtmSummary;

  /// No description provided for @futureAtmPoint1.
  ///
  /// In en, this message translates to:
  /// **'SESAR (Europe) and NextGen (USA) are programmes modernising ATM with digital data links and 4D trajectories.'**
  String get futureAtmPoint1;

  /// No description provided for @futureAtmPoint2.
  ///
  /// In en, this message translates to:
  /// **'Remote towers allow controllers to manage smaller airports from centralised facilities.'**
  String get futureAtmPoint2;

  /// No description provided for @futureAtmPoint3.
  ///
  /// In en, this message translates to:
  /// **'AI tools can assist with conflict detection, flow optimisation, and workload balancing — but require careful validation.'**
  String get futureAtmPoint3;

  /// No description provided for @futureAtmQ1Question.
  ///
  /// In en, this message translates to:
  /// **'What is SESAR?'**
  String get futureAtmQ1Question;

  /// No description provided for @futureAtmQ1O0.
  ///
  /// In en, this message translates to:
  /// **'A European ATM modernisation programme'**
  String get futureAtmQ1O0;

  /// No description provided for @futureAtmQ1O1.
  ///
  /// In en, this message translates to:
  /// **'A type of radar sensor'**
  String get futureAtmQ1O1;

  /// No description provided for @futureAtmQ1O2.
  ///
  /// In en, this message translates to:
  /// **'A pilot training standard'**
  String get futureAtmQ1O2;

  /// No description provided for @futureAtmQ1Explanation.
  ///
  /// In en, this message translates to:
  /// **'SESAR (Single European Sky ATM Research) is the European programme to modernise and harmonise ATM across Europe.'**
  String get futureAtmQ1Explanation;

  /// No description provided for @futureAtmQ2Question.
  ///
  /// In en, this message translates to:
  /// **'Remote towers allow:'**
  String get futureAtmQ2Question;

  /// No description provided for @futureAtmQ2O0.
  ///
  /// In en, this message translates to:
  /// **'Controlling airports without any human oversight'**
  String get futureAtmQ2O0;

  /// No description provided for @futureAtmQ2O1.
  ///
  /// In en, this message translates to:
  /// **'Managing smaller airports from a centralised facility'**
  String get futureAtmQ2O1;

  /// No description provided for @futureAtmQ2O2.
  ///
  /// In en, this message translates to:
  /// **'Removing the need for radar entirely'**
  String get futureAtmQ2O2;

  /// No description provided for @futureAtmQ2Explanation.
  ///
  /// In en, this message translates to:
  /// **'Remote towers use cameras and digital feeds to give controllers a full view of small airports from a remote location.'**
  String get futureAtmQ2Explanation;

  /// No description provided for @futureAtmQ3Question.
  ///
  /// In en, this message translates to:
  /// **'Regarding AI in ATM, which statement is most accurate?'**
  String get futureAtmQ3Question;

  /// No description provided for @futureAtmQ3O0.
  ///
  /// In en, this message translates to:
  /// **'AI will replace all controllers by 2030'**
  String get futureAtmQ3O0;

  /// No description provided for @futureAtmQ3O1.
  ///
  /// In en, this message translates to:
  /// **'AI can assist controllers but requires careful validation before operational use'**
  String get futureAtmQ3O1;

  /// No description provided for @futureAtmQ3O2.
  ///
  /// In en, this message translates to:
  /// **'AI is currently banned in ATM'**
  String get futureAtmQ3O2;

  /// No description provided for @futureAtmQ3Explanation.
  ///
  /// In en, this message translates to:
  /// **'AI tools show great promise for assisting controllers, but aviation safety standards require rigorous testing before deployment.'**
  String get futureAtmQ3Explanation;

  /// No description provided for @radarV2ScenarioTitle.
  ///
  /// In en, this message translates to:
  /// **'Crossing Conflict'**
  String get radarV2ScenarioTitle;

  /// No description provided for @radarV2ScenarioDesc.
  ///
  /// In en, this message translates to:
  /// **'Two aircraft are converging at the same altitude. Resolve the conflict before separation is lost.'**
  String get radarV2ScenarioDesc;

  /// No description provided for @radarV2SelectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an aircraft on the radar to select it'**
  String get radarV2SelectHint;

  /// No description provided for @radarV2ScenarioSuccess.
  ///
  /// In en, this message translates to:
  /// **'Conflict Resolved'**
  String get radarV2ScenarioSuccess;

  /// No description provided for @radarV2ScenarioFailed.
  ///
  /// In en, this message translates to:
  /// **'Scenario Failed'**
  String get radarV2ScenarioFailed;

  /// No description provided for @radarV2FinalScore.
  ///
  /// In en, this message translates to:
  /// **'Final Score'**
  String get radarV2FinalScore;

  /// No description provided for @radarV2TryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get radarV2TryAgain;

  /// No description provided for @radarV2Resolving.
  ///
  /// In en, this message translates to:
  /// **'RESOLVING'**
  String get radarV2Resolving;

  /// No description provided for @radarV2HowTo.
  ///
  /// In en, this message translates to:
  /// **'Tap an aircraft → issue heading or altitude command → hold separation 5 s'**
  String get radarV2HowTo;

  /// No description provided for @radarV2SuccessHint.
  ///
  /// In en, this message translates to:
  /// **'Separation restored by heading or altitude change'**
  String get radarV2SuccessHint;

  /// No description provided for @radarLevel1Name.
  ///
  /// In en, this message translates to:
  /// **'Basic Crossing'**
  String get radarLevel1Name;

  /// No description provided for @radarLevel2Name.
  ///
  /// In en, this message translates to:
  /// **'Altitude Separation'**
  String get radarLevel2Name;

  /// No description provided for @radarLevel3Name.
  ///
  /// In en, this message translates to:
  /// **'Speed Control'**
  String get radarLevel3Name;

  /// No description provided for @radarLevel4Name.
  ///
  /// In en, this message translates to:
  /// **'Mixed Conflict'**
  String get radarLevel4Name;

  /// No description provided for @radarLevel5Name.
  ///
  /// In en, this message translates to:
  /// **'Late Conflict'**
  String get radarLevel5Name;

  /// No description provided for @radarLevel6Name.
  ///
  /// In en, this message translates to:
  /// **'High Traffic'**
  String get radarLevel6Name;

  /// No description provided for @radarLevel7Name.
  ///
  /// In en, this message translates to:
  /// **'Climb / Descend'**
  String get radarLevel7Name;

  /// No description provided for @radarLevel8Name.
  ///
  /// In en, this message translates to:
  /// **'Holding Pattern'**
  String get radarLevel8Name;

  /// No description provided for @radarLevel9Name.
  ///
  /// In en, this message translates to:
  /// **'Approach Conflict'**
  String get radarLevel9Name;

  /// No description provided for @radarLevel10Name.
  ///
  /// In en, this message translates to:
  /// **'Priority Emergency'**
  String get radarLevel10Name;

  /// No description provided for @radarLevel1Tip.
  ///
  /// In en, this message translates to:
  /// **'Try turning one aircraft away — early heading change is easier than reacting late.'**
  String get radarLevel1Tip;

  /// No description provided for @radarLevel2Tip.
  ///
  /// In en, this message translates to:
  /// **'Heading change alone is slow here. Climb or descend one aircraft for instant vertical separation.'**
  String get radarLevel2Tip;

  /// No description provided for @radarLevel3Tip.
  ///
  /// In en, this message translates to:
  /// **'The trailing aircraft is catching up fast. Use Slow to restore longitudinal spacing.'**
  String get radarLevel3Tip;

  /// No description provided for @radarLevel4Tip.
  ///
  /// In en, this message translates to:
  /// **'Two conflicts at once. Resolve the closest pair first, then tackle the second.'**
  String get radarLevel4Tip;

  /// No description provided for @radarLevel5Tip.
  ///
  /// In en, this message translates to:
  /// **'Conflict develops fast. Issue a heading command immediately — don\'t wait.'**
  String get radarLevel5Tip;

  /// No description provided for @radarLevel6Tip.
  ///
  /// In en, this message translates to:
  /// **'Scan all aircraft before acting. Prioritise the pair with least separation.'**
  String get radarLevel6Tip;

  /// No description provided for @radarLevel7Tip.
  ///
  /// In en, this message translates to:
  /// **'Near-identical altitudes will conflict when aircraft converge. Climb or descend now.'**
  String get radarLevel7Tip;

  /// No description provided for @radarLevel8Tip.
  ///
  /// In en, this message translates to:
  /// **'Bunching aircraft need speed adjustment. Slow the faster one or speed up the slower.'**
  String get radarLevel8Tip;

  /// No description provided for @radarLevel9Tip.
  ///
  /// In en, this message translates to:
  /// **'Approach paths converge fast. Extend one aircraft with a heading or altitude change.'**
  String get radarLevel9Tip;

  /// No description provided for @radarLevel10Tip.
  ///
  /// In en, this message translates to:
  /// **'MAYDAY has priority. Move all surrounding aircraft away using heading and altitude.'**
  String get radarLevel10Tip;

  /// No description provided for @radarLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String radarLevelLabel(int level);

  /// No description provided for @radarLevelComplete.
  ///
  /// In en, this message translates to:
  /// **'Level {level} Complete!'**
  String radarLevelComplete(int level);

  /// No description provided for @radarXpEarned.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String radarXpEarned(int xp);

  /// No description provided for @radarTotalXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String radarTotalXp(int xp);

  /// No description provided for @radarNextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next → Level {level}'**
  String radarNextLevel(int level);

  /// No description provided for @radarAllLevelsComplete.
  ///
  /// In en, this message translates to:
  /// **'All Levels Complete!'**
  String get radarAllLevelsComplete;

  /// No description provided for @radarBestScore.
  ///
  /// In en, this message translates to:
  /// **'Best: {score}'**
  String radarBestScore(int score);

  /// No description provided for @radarShareText.
  ///
  /// In en, this message translates to:
  /// **'I completed Level {level} in ATM Academy ✈️  Score: {score}/120 — Can you beat me?'**
  String radarShareText(int level, int score);

  /// No description provided for @radarShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Score card copied — share with your team!'**
  String get radarShareCopied;

  /// No description provided for @radarTechnique.
  ///
  /// In en, this message translates to:
  /// **'Technique: {tech}'**
  String radarTechnique(String tech);

  /// No description provided for @radarTechHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get radarTechHeading;

  /// No description provided for @radarTechAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get radarTechAltitude;

  /// No description provided for @radarTechSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get radarTechSpeed;

  /// No description provided for @radarTechMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get radarTechMixed;

  /// No description provided for @progRankCadet.
  ///
  /// In en, this message translates to:
  /// **'Cadet'**
  String get progRankCadet;

  /// No description provided for @progRankTrainee.
  ///
  /// In en, this message translates to:
  /// **'Trainee'**
  String get progRankTrainee;

  /// No description provided for @progRankController.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get progRankController;

  /// No description provided for @progRankSenior.
  ///
  /// In en, this message translates to:
  /// **'Senior Controller'**
  String get progRankSenior;

  /// No description provided for @progRankMaster.
  ///
  /// In en, this message translates to:
  /// **'Tower Master'**
  String get progRankMaster;

  /// No description provided for @homeCardScenarioTraining.
  ///
  /// In en, this message translates to:
  /// **'Guided Scenarios'**
  String get homeCardScenarioTraining;

  /// No description provided for @homeCardScenarioTrainingSub.
  ///
  /// In en, this message translates to:
  /// **'Learn controller thinking with pressure, scoring, and explanation'**
  String get homeCardScenarioTrainingSub;

  /// No description provided for @alertNormal.
  ///
  /// In en, this message translates to:
  /// **'NORMAL'**
  String get alertNormal;

  /// No description provided for @alertAdvisory.
  ///
  /// In en, this message translates to:
  /// **'TRAFFIC ADVISORY'**
  String get alertAdvisory;

  /// No description provided for @alertWarning.
  ///
  /// In en, this message translates to:
  /// **'CONFLICT WARNING'**
  String get alertWarning;

  /// No description provided for @alertLOS.
  ///
  /// In en, this message translates to:
  /// **'LOSS OF SEPARATION'**
  String get alertLOS;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @ratingSafe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get ratingSafe;

  /// No description provided for @ratingNeedsImprovement.
  ///
  /// In en, this message translates to:
  /// **'Needs Improvement'**
  String get ratingNeedsImprovement;

  /// No description provided for @ratingUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Unsafe'**
  String get ratingUnsafe;

  /// No description provided for @scenarioResult.
  ///
  /// In en, this message translates to:
  /// **'Scenario Result'**
  String get scenarioResult;

  /// No description provided for @scenarioWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get scenarioWhatHappened;

  /// No description provided for @scenarioRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get scenarioRetry;

  /// No description provided for @scenarioNext.
  ///
  /// In en, this message translates to:
  /// **'Next Scenario'**
  String get scenarioNext;

  /// No description provided for @scenarioDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get scenarioDone;

  /// No description provided for @scenarioLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String scenarioLevelLabel(int n);

  /// No description provided for @feedbackGood.
  ///
  /// In en, this message translates to:
  /// **'Good — separation increasing'**
  String get feedbackGood;

  /// No description provided for @feedbackNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral — no clear change'**
  String get feedbackNeutral;

  /// No description provided for @feedbackBad.
  ///
  /// In en, this message translates to:
  /// **'Warning — still converging'**
  String get feedbackBad;

  /// No description provided for @skillSeparation.
  ///
  /// In en, this message translates to:
  /// **'Separation'**
  String get skillSeparation;

  /// No description provided for @skillAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get skillAltitude;

  /// No description provided for @skillSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get skillSpeed;

  /// No description provided for @skillMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get skillMixed;

  /// No description provided for @scoreRowGoodCommands.
  ///
  /// In en, this message translates to:
  /// **'Good commands'**
  String get scoreRowGoodCommands;

  /// No description provided for @scoreRowBadCommands.
  ///
  /// In en, this message translates to:
  /// **'Bad commands'**
  String get scoreRowBadCommands;

  /// No description provided for @scoreRowLOS.
  ///
  /// In en, this message translates to:
  /// **'Loss of separation'**
  String get scoreRowLOS;

  /// No description provided for @scoreRowResolvedEarly.
  ///
  /// In en, this message translates to:
  /// **'Resolved early'**
  String get scoreRowResolvedEarly;

  /// No description provided for @scoreRowSeparationMaintained.
  ///
  /// In en, this message translates to:
  /// **'Separation maintained'**
  String get scoreRowSeparationMaintained;

  /// No description provided for @scoreRowLateAction.
  ///
  /// In en, this message translates to:
  /// **'Late first action'**
  String get scoreRowLateAction;

  /// No description provided for @homeRecommendedPath.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED PATH'**
  String get homeRecommendedPath;

  /// No description provided for @homePathLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn Basics'**
  String get homePathLearn;

  /// No description provided for @homePathRadarPractice.
  ///
  /// In en, this message translates to:
  /// **'Radar · L1'**
  String get homePathRadarPractice;

  /// No description provided for @homePathGuidedScenario.
  ///
  /// In en, this message translates to:
  /// **'Scenario · 1'**
  String get homePathGuidedScenario;

  /// No description provided for @homePathQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get homePathQuiz;

  /// No description provided for @watchReplay3d.
  ///
  /// In en, this message translates to:
  /// **'Watch 3D Replay'**
  String get watchReplay3d;

  /// No description provided for @unityReplayTitle.
  ///
  /// In en, this message translates to:
  /// **'3D Scenario Replay'**
  String get unityReplayTitle;

  /// No description provided for @unityReplayComingSoon.
  ///
  /// In en, this message translates to:
  /// **'3D visualization coming in a future update'**
  String get unityReplayComingSoon;

  /// No description provided for @unityReplayBack.
  ///
  /// In en, this message translates to:
  /// **'← Back to Results'**
  String get unityReplayBack;

  /// No description provided for @scenarioConflictPair.
  ///
  /// In en, this message translates to:
  /// **'Conflict Pair'**
  String get scenarioConflictPair;

  /// No description provided for @scenarioMinHorizSep.
  ///
  /// In en, this message translates to:
  /// **'Min Horizontal Separation'**
  String get scenarioMinHorizSep;

  /// No description provided for @scenarioMinVertSep.
  ///
  /// In en, this message translates to:
  /// **'Min Vertical Separation'**
  String get scenarioMinVertSep;

  /// No description provided for @scenarioReactionTime.
  ///
  /// In en, this message translates to:
  /// **'Reaction Time'**
  String get scenarioReactionTime;

  /// No description provided for @scenarioPenalties.
  ///
  /// In en, this message translates to:
  /// **'Penalties'**
  String get scenarioPenalties;

  /// No description provided for @scenarioBonuses.
  ///
  /// In en, this message translates to:
  /// **'Bonuses'**
  String get scenarioBonuses;

  /// No description provided for @scenarioLOSResult.
  ///
  /// In en, this message translates to:
  /// **'LOSS OF SEPARATION'**
  String get scenarioLOSResult;

  /// No description provided for @scenarioSafeResult.
  ///
  /// In en, this message translates to:
  /// **'SEPARATION MAINTAINED'**
  String get scenarioSafeResult;
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
