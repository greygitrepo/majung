import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
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
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('ko')];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'마중'**
  String get appTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In ko, this message translates to:
  /// **'필요한 곳을 눌러 주세요'**
  String get homeGreeting;

  /// No description provided for @groupMeal.
  ///
  /// In ko, this message translates to:
  /// **'밥 먹을 곳'**
  String get groupMeal;

  /// No description provided for @groupMealSub.
  ///
  /// In ko, this message translates to:
  /// **'무료 급식'**
  String get groupMealSub;

  /// No description provided for @groupSleep.
  ///
  /// In ko, this message translates to:
  /// **'잘 곳'**
  String get groupSleep;

  /// No description provided for @groupSleepSub.
  ///
  /// In ko, this message translates to:
  /// **'쉼터 · 잠자리'**
  String get groupSleepSub;

  /// No description provided for @groupWash.
  ///
  /// In ko, this message translates to:
  /// **'씻을 곳 · 빨래'**
  String get groupWash;

  /// No description provided for @groupWashSub.
  ///
  /// In ko, this message translates to:
  /// **'샤워 · 세탁'**
  String get groupWashSub;

  /// No description provided for @groupClinic.
  ///
  /// In ko, this message translates to:
  /// **'아플 때'**
  String get groupClinic;

  /// No description provided for @groupClinicSub.
  ///
  /// In ko, this message translates to:
  /// **'무료 진료'**
  String get groupClinicSub;

  /// No description provided for @groupGroceries.
  ///
  /// In ko, this message translates to:
  /// **'먹을거리 받기'**
  String get groupGroceries;

  /// No description provided for @groupGroceriesSub.
  ///
  /// In ko, this message translates to:
  /// **'푸드뱅크 · 푸드마켓'**
  String get groupGroceriesSub;

  /// No description provided for @openCount.
  ///
  /// In ko, this message translates to:
  /// **'모두 {total}곳 · 지금 열림 {open}곳'**
  String openCount(int open, int total);

  /// No description provided for @originNone.
  ///
  /// In ko, this message translates to:
  /// **'가까운 순으로 보려면 위치를 정해 주세요'**
  String get originNone;

  /// No description provided for @originGps.
  ///
  /// In ko, this message translates to:
  /// **'내 위치 기준'**
  String get originGps;

  /// No description provided for @originLandmark.
  ///
  /// In ko, this message translates to:
  /// **'{place} 근처 기준'**
  String originLandmark(String place);

  /// No description provided for @originChange.
  ///
  /// In ko, this message translates to:
  /// **'바꾸기'**
  String get originChange;

  /// No description provided for @originSet.
  ///
  /// In ko, this message translates to:
  /// **'위치 정하기'**
  String get originSet;

  /// No description provided for @pickerTitle.
  ///
  /// In ko, this message translates to:
  /// **'어디 근처에서 찾을까요?'**
  String get pickerTitle;

  /// No description provided for @pickerUseGps.
  ///
  /// In ko, this message translates to:
  /// **'지금 내 위치 쓰기'**
  String get pickerUseGps;

  /// No description provided for @pickerGpsWhy.
  ///
  /// In ko, this message translates to:
  /// **'가까운 곳부터 보여 드리려고 위치를 써요.\n위치는 휴대폰 밖으로 보내지 않아요.'**
  String get pickerGpsWhy;

  /// No description provided for @pickerOr.
  ///
  /// In ko, this message translates to:
  /// **'또는 가까운 곳을 고르세요'**
  String get pickerOr;

  /// No description provided for @pickerLocating.
  ///
  /// In ko, this message translates to:
  /// **'위치를 찾고 있어요…'**
  String get pickerLocating;

  /// No description provided for @landmarkSeoulStation.
  ///
  /// In ko, this message translates to:
  /// **'서울역'**
  String get landmarkSeoulStation;

  /// No description provided for @landmarkEuljiro.
  ///
  /// In ko, this message translates to:
  /// **'을지로입구역'**
  String get landmarkEuljiro;

  /// No description provided for @landmarkYeongdeungpo.
  ///
  /// In ko, this message translates to:
  /// **'영등포역'**
  String get landmarkYeongdeungpo;

  /// No description provided for @landmarkYongsan.
  ///
  /// In ko, this message translates to:
  /// **'용산역'**
  String get landmarkYongsan;

  /// No description provided for @locDenied.
  ///
  /// In ko, this message translates to:
  /// **'위치를 쓸 수 없어요. 아래에서 가까운 곳을 골라 주세요.'**
  String get locDenied;

  /// No description provided for @locDeniedForever.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 꺼져 있어요. 휴대폰 설정에서 켜거나, 아래에서 가까운 곳을 골라 주세요.'**
  String get locDeniedForever;

  /// No description provided for @locServiceOff.
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 위치(GPS)가 꺼져 있어요. 켜거나, 아래에서 가까운 곳을 골라 주세요.'**
  String get locServiceOff;

  /// No description provided for @locError.
  ///
  /// In ko, this message translates to:
  /// **'위치를 찾지 못했어요. 아래에서 가까운 곳을 골라 주세요.'**
  String get locError;

  /// No description provided for @openSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get openSettings;

  /// No description provided for @statusOpen.
  ///
  /// In ko, this message translates to:
  /// **'지금 열려 있어요'**
  String get statusOpen;

  /// No description provided for @statusClosingSoon.
  ///
  /// In ko, this message translates to:
  /// **'곧 닫아요'**
  String get statusClosingSoon;

  /// No description provided for @statusClosed.
  ///
  /// In ko, this message translates to:
  /// **'지금은 닫혀 있어요'**
  String get statusClosed;

  /// No description provided for @statusUnknown.
  ///
  /// In ko, this message translates to:
  /// **'운영 시간 확인 필요'**
  String get statusUnknown;

  /// No description provided for @statusUntil.
  ///
  /// In ko, this message translates to:
  /// **'{time}까지'**
  String statusUntil(String time);

  /// No description provided for @statusOpensAt.
  ///
  /// In ko, this message translates to:
  /// **'{time}에 열어요'**
  String statusOpensAt(String time);

  /// No description provided for @statusNoNextOpen.
  ///
  /// In ko, this message translates to:
  /// **'다음 운영일은 전화로 확인하세요'**
  String get statusNoNextOpen;

  /// No description provided for @statusCallFirst.
  ///
  /// In ko, this message translates to:
  /// **'가기 전에 전화해 보세요'**
  String get statusCallFirst;

  /// No description provided for @holidayWarning.
  ///
  /// In ko, this message translates to:
  /// **'오늘은 공휴일이라 운영이 다를 수 있어요'**
  String get holidayWarning;

  /// No description provided for @today.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In ko, this message translates to:
  /// **'내일'**
  String get tomorrow;

  /// No description provided for @am.
  ///
  /// In ko, this message translates to:
  /// **'오전'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In ko, this message translates to:
  /// **'오후'**
  String get pm;

  /// No description provided for @noon.
  ///
  /// In ko, this message translates to:
  /// **'낮'**
  String get noon;

  /// No description provided for @everyDay.
  ///
  /// In ko, this message translates to:
  /// **'매일'**
  String get everyDay;

  /// No description provided for @hourOnly.
  ///
  /// In ko, this message translates to:
  /// **'{period} {hour}시'**
  String hourOnly(String period, int hour);

  /// No description provided for @hourMinute.
  ///
  /// In ko, this message translates to:
  /// **'{period} {hour}시 {minute}분'**
  String hourMinute(String period, int hour, int minute);

  /// No description provided for @midnight.
  ///
  /// In ko, this message translates to:
  /// **'밤 12시'**
  String get midnight;

  /// No description provided for @allDay.
  ///
  /// In ko, this message translates to:
  /// **'24시간'**
  String get allDay;

  /// No description provided for @walk.
  ///
  /// In ko, this message translates to:
  /// **'걸어서 약 {minutes}분 ({distance})'**
  String walk(int minutes, String distance);

  /// No description provided for @whoCanUse.
  ///
  /// In ko, this message translates to:
  /// **'이용: {who}'**
  String whoCanUse(String who);

  /// No description provided for @call.
  ///
  /// In ko, this message translates to:
  /// **'전화'**
  String get call;

  /// No description provided for @callLong.
  ///
  /// In ko, this message translates to:
  /// **'전화 걸기'**
  String get callLong;

  /// No description provided for @directions.
  ///
  /// In ko, this message translates to:
  /// **'길찾기'**
  String get directions;

  /// No description provided for @details.
  ///
  /// In ko, this message translates to:
  /// **'자세히'**
  String get details;

  /// No description provided for @noPhone.
  ///
  /// In ko, this message translates to:
  /// **'전화번호 없음'**
  String get noPhone;

  /// No description provided for @viewMap.
  ///
  /// In ko, this message translates to:
  /// **'지도로 보기'**
  String get viewMap;

  /// No description provided for @viewList.
  ///
  /// In ko, this message translates to:
  /// **'목록으로 보기'**
  String get viewList;

  /// No description provided for @listCallFirstBanner.
  ///
  /// In ko, this message translates to:
  /// **'운영 시간은 바뀔 수 있어요. 가기 전에 전화로 꼭 확인하세요.'**
  String get listCallFirstBanner;

  /// No description provided for @listEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 등록된 곳이 없어요.'**
  String get listEmpty;

  /// No description provided for @listEmptyHelp.
  ///
  /// In ko, this message translates to:
  /// **'급하면 아래 번호로 전화하세요.'**
  String get listEmptyHelp;

  /// No description provided for @detailHours.
  ///
  /// In ko, this message translates to:
  /// **'운영 시간'**
  String get detailHours;

  /// No description provided for @detailNoHours.
  ///
  /// In ko, this message translates to:
  /// **'운영 시간 정보가 없어요. 전화로 확인하세요.'**
  String get detailNoHours;

  /// No description provided for @detailWho.
  ///
  /// In ko, this message translates to:
  /// **'누가 이용할 수 있나요'**
  String get detailWho;

  /// No description provided for @detailRequirements.
  ///
  /// In ko, this message translates to:
  /// **'준비할 것 · 조건'**
  String get detailRequirements;

  /// No description provided for @detailAddress.
  ///
  /// In ko, this message translates to:
  /// **'주소'**
  String get detailAddress;

  /// No description provided for @detailCopyAddress.
  ///
  /// In ko, this message translates to:
  /// **'주소 복사'**
  String get detailCopyAddress;

  /// No description provided for @detailCopied.
  ///
  /// In ko, this message translates to:
  /// **'주소를 복사했어요'**
  String get detailCopied;

  /// No description provided for @detailNote.
  ///
  /// In ko, this message translates to:
  /// **'참고'**
  String get detailNote;

  /// No description provided for @detailUnknownField.
  ///
  /// In ko, this message translates to:
  /// **'확인 필요'**
  String get detailUnknownField;

  /// No description provided for @detailVerified.
  ///
  /// In ko, this message translates to:
  /// **'마지막 확인: {date}'**
  String detailVerified(String date);

  /// No description provided for @detailSource.
  ///
  /// In ko, this message translates to:
  /// **'출처: {source}'**
  String detailSource(String source);

  /// No description provided for @detailReport.
  ///
  /// In ko, this message translates to:
  /// **'정보가 틀렸어요'**
  String get detailReport;

  /// No description provided for @staleWarning.
  ///
  /// In ko, this message translates to:
  /// **'정보가 오래됐을 수 있어요. 가기 전에 전화로 확인하세요.'**
  String get staleWarning;

  /// No description provided for @expiredWarning.
  ///
  /// In ko, this message translates to:
  /// **'오랫동안 확인하지 못한 정보예요. 꼭 전화로 확인하세요.'**
  String get expiredWarning;

  /// No description provided for @weekdayMon.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In ko, this message translates to:
  /// **'화'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In ko, this message translates to:
  /// **'수'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In ko, this message translates to:
  /// **'목'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In ko, this message translates to:
  /// **'금'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In ko, this message translates to:
  /// **'토'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get weekdaySun;

  /// No description provided for @weekdayFull.
  ///
  /// In ko, this message translates to:
  /// **'{day}요일'**
  String weekdayFull(String day);

  /// No description provided for @closedDay.
  ///
  /// In ko, this message translates to:
  /// **'쉬어요'**
  String get closedDay;

  /// No description provided for @emergencyButton.
  ///
  /// In ko, this message translates to:
  /// **'급할 때 전화하기'**
  String get emergencyButton;

  /// No description provided for @emergencyTitle.
  ///
  /// In ko, this message translates to:
  /// **'급할 때 전화하세요'**
  String get emergencyTitle;

  /// No description provided for @emergencyHomeless.
  ///
  /// In ko, this message translates to:
  /// **'노숙인 위기대응콜'**
  String get emergencyHomeless;

  /// No description provided for @emergencyHomelessSub.
  ///
  /// In ko, this message translates to:
  /// **'잘 곳이 없거나 위험할 때 · 서울 · 24시간'**
  String get emergencyHomelessSub;

  /// No description provided for @emergencyWelfare.
  ///
  /// In ko, this message translates to:
  /// **'보건복지상담센터'**
  String get emergencyWelfare;

  /// No description provided for @emergencyWelfareSub.
  ///
  /// In ko, this message translates to:
  /// **'생계가 막막할 때 · 위기 상담 24시간'**
  String get emergencyWelfareSub;

  /// No description provided for @emergencySuicide.
  ///
  /// In ko, this message translates to:
  /// **'자살예방 상담전화'**
  String get emergencySuicide;

  /// No description provided for @emergencySuicideSub.
  ///
  /// In ko, this message translates to:
  /// **'너무 힘들고 지칠 때, 24시간'**
  String get emergencySuicideSub;

  /// No description provided for @emergencyDasan.
  ///
  /// In ko, this message translates to:
  /// **'다산콜센터'**
  String get emergencyDasan;

  /// No description provided for @emergencyDasanSub.
  ///
  /// In ko, this message translates to:
  /// **'서울시 생활 · 복지 안내'**
  String get emergencyDasanSub;

  /// No description provided for @emergencyPolice.
  ///
  /// In ko, this message translates to:
  /// **'경찰'**
  String get emergencyPolice;

  /// No description provided for @emergencyPoliceSub.
  ///
  /// In ko, this message translates to:
  /// **'위험하거나 범죄를 당했을 때'**
  String get emergencyPoliceSub;

  /// No description provided for @emergencyFire.
  ///
  /// In ko, this message translates to:
  /// **'구급차 · 소방'**
  String get emergencyFire;

  /// No description provided for @emergencyFireSub.
  ///
  /// In ko, this message translates to:
  /// **'다치거나 아플 때, 너무 춥거나 더울 때'**
  String get emergencyFireSub;

  /// No description provided for @info.
  ///
  /// In ko, this message translates to:
  /// **'앱 정보'**
  String get info;

  /// No description provided for @infoAbout.
  ///
  /// In ko, this message translates to:
  /// **'마중은 무료 급식소와 쉼터를 한곳에서 찾는 앱이에요. 정부나 구청이 만든 앱이 아니고, 공공데이터를 바탕으로 만든 민간 앱이에요.'**
  String get infoAbout;

  /// No description provided for @infoPrivacy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보'**
  String get infoPrivacy;

  /// No description provided for @infoPrivacyBody.
  ///
  /// In ko, this message translates to:
  /// **'가입이 없고, 이름·전화번호를 받지 않아요. 위치는 가까운 순서를 계산할 때 휴대폰 안에서만 쓰고 저장하거나 보내지 않아요.'**
  String get infoPrivacyBody;

  /// No description provided for @infoSources.
  ///
  /// In ko, this message translates to:
  /// **'데이터 출처'**
  String get infoSources;

  /// No description provided for @infoDataVersion.
  ///
  /// In ko, this message translates to:
  /// **'데이터 기준일: {date}'**
  String infoDataVersion(String date);

  /// No description provided for @infoMapCredit.
  ///
  /// In ko, this message translates to:
  /// **'지도: © OpenStreetMap 기여자'**
  String get infoMapCredit;

  /// No description provided for @infoContact.
  ///
  /// In ko, this message translates to:
  /// **'문의 · 오류 신고'**
  String get infoContact;

  /// No description provided for @mapAttribution.
  ///
  /// In ko, this message translates to:
  /// **'© OpenStreetMap'**
  String get mapAttribution;

  /// No description provided for @mapHint.
  ///
  /// In ko, this message translates to:
  /// **'핀을 누르면 정보가 나와요'**
  String get mapHint;

  /// No description provided for @mapUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'지도를 불러올 수 없어요. 목록으로 보세요.'**
  String get mapUnavailable;

  /// No description provided for @launchFailed.
  ///
  /// In ko, this message translates to:
  /// **'열 수 있는 앱이 없어요'**
  String get launchFailed;

  /// No description provided for @updated.
  ///
  /// In ko, this message translates to:
  /// **'새 정보로 바꿨어요'**
  String get updated;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ko':
      return L10nKo();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
