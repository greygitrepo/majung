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
  /// **'어디로 갈까요?'**
  String get homeGreeting;

  /// No description provided for @homeGreetingSub.
  ///
  /// In ko, this message translates to:
  /// **'가까운 곳부터 보여 드릴게요'**
  String get homeGreetingSub;

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
  /// **'무료 진료소 · 보건소'**
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
  /// **'지금 열림 {open}곳 · 모두 {total}곳'**
  String openCount(int open, int total);

  /// No description provided for @originNone.
  ///
  /// In ko, this message translates to:
  /// **'어디 근처에서 찾을지 먼저 정해 주세요'**
  String get originNone;

  /// No description provided for @originGps.
  ///
  /// In ko, this message translates to:
  /// **'내 위치 기준'**
  String get originGps;

  /// No description provided for @originRegion.
  ///
  /// In ko, this message translates to:
  /// **'{place} 기준'**
  String originRegion(String place);

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
  /// **'또는 지역을 고르세요'**
  String get pickerOr;

  /// No description provided for @pickerSigungu.
  ///
  /// In ko, this message translates to:
  /// **'{sido}에서 고르세요'**
  String pickerSigungu(String sido);

  /// No description provided for @pickerBack.
  ///
  /// In ko, this message translates to:
  /// **'다른 시·도 고르기'**
  String get pickerBack;

  /// No description provided for @pickerNoRegions.
  ///
  /// In ko, this message translates to:
  /// **'지역 목록을 불러오지 못했어요. 위치 쓰기를 눌러 주세요.'**
  String get pickerNoRegions;

  /// No description provided for @pickerLocating.
  ///
  /// In ko, this message translates to:
  /// **'위치를 찾고 있어요…'**
  String get pickerLocating;

  /// No description provided for @locDenied.
  ///
  /// In ko, this message translates to:
  /// **'위치를 쓸 수 없어요. 아래에서 지역을 골라 주세요.'**
  String get locDenied;

  /// No description provided for @locDeniedForever.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 꺼져 있어요. 휴대폰 설정에서 켜거나, 아래에서 지역을 골라 주세요.'**
  String get locDeniedForever;

  /// No description provided for @locServiceOff.
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 위치(GPS)가 꺼져 있어요. 켜거나, 아래에서 지역을 골라 주세요.'**
  String get locServiceOff;

  /// No description provided for @locError.
  ///
  /// In ko, this message translates to:
  /// **'위치를 찾지 못했어요. 아래에서 지역을 골라 주세요.'**
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

  /// No description provided for @distanceOnly.
  ///
  /// In ko, this message translates to:
  /// **'여기서 {distance}'**
  String distanceOnly(String distance);

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
  /// **'시간이 바뀔 수 있어요. 가기 전에 전화로 한 번 확인해 주세요.'**
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

  /// No description provided for @listNeedOrigin.
  ///
  /// In ko, this message translates to:
  /// **'어디 근처에서 찾을지 먼저 정해 주세요'**
  String get listNeedOrigin;

  /// No description provided for @listNeedOriginHelp.
  ///
  /// In ko, this message translates to:
  /// **'전국의 시설 중 가까운 곳만 보여 드려요.'**
  String get listNeedOriginHelp;

  /// No description provided for @homeNeedOrigin.
  ///
  /// In ko, this message translates to:
  /// **'위치를 정하면 가까운 곳을 보여 드려요'**
  String get homeNeedOrigin;

  /// No description provided for @seniorSectionTitle.
  ///
  /// In ko, this message translates to:
  /// **'어르신 경로식당'**
  String get seniorSectionTitle;

  /// No description provided for @seniorSectionSub.
  ///
  /// In ko, this message translates to:
  /// **'그 동네에 사는 어르신이 미리 등록해야 먹을 수 있는 곳이에요. 처음이면 전화로 물어보세요.'**
  String get seniorSectionSub;

  /// No description provided for @clinicFree.
  ///
  /// In ko, this message translates to:
  /// **'무료 진료소'**
  String get clinicFree;

  /// No description provided for @clinicHealthCenter.
  ///
  /// In ko, this message translates to:
  /// **'보건소 · 진료비가 싸요 (무료 아님)'**
  String get clinicHealthCenter;

  /// No description provided for @clinicHospitalSupport.
  ///
  /// In ko, this message translates to:
  /// **'입원·수술비 지원 병원'**
  String get clinicHospitalSupport;

  /// No description provided for @clinicInfoTitle.
  ///
  /// In ko, this message translates to:
  /// **'노숙인 의료급여증이 있으면 병원비가 거의 들지 않아요'**
  String get clinicInfoTitle;

  /// No description provided for @clinicInfoBody.
  ///
  /// In ko, this message translates to:
  /// **'노숙한 지 1개월이 넘고, 건강보험이 없거나 3개월 넘게 못 냈다면 받을 수 있어요. 쉼터나 노숙인 종합지원센터에 신청해요. 일부 검사·치료는 돈을 낼 수 있어요. 잘 모르면 129에 전화해 물어보세요.'**
  String get clinicInfoBody;

  /// No description provided for @detailHours.
  ///
  /// In ko, this message translates to:
  /// **'언제 가면 되나요'**
  String get detailHours;

  /// No description provided for @detailNoHours.
  ///
  /// In ko, this message translates to:
  /// **'운영 시간 정보가 없어요. 전화로 확인하세요.'**
  String get detailNoHours;

  /// No description provided for @detailUnverifiedHours.
  ///
  /// In ko, this message translates to:
  /// **'아래는 공공데이터에 적힌 내용이에요. 실제와 다른 경우가 많아요. 가기 전에 꼭 전화해 보세요.'**
  String get detailUnverifiedHours;

  /// No description provided for @detailWho.
  ///
  /// In ko, this message translates to:
  /// **'누가 갈 수 있나요'**
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

  /// No description provided for @detailGeocoded.
  ///
  /// In ko, this message translates to:
  /// **'지도 위치는 주소로 찾은 대략적인 위치예요.'**
  String get detailGeocoded;

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

  /// No description provided for @emergencyHint.
  ///
  /// In ko, this message translates to:
  /// **'혼자 힘들 땐 언제든 전화하세요'**
  String get emergencyHint;

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
  /// **'생계가 막막할 때 · 긴급 복지 상담 24시간'**
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

  /// No description provided for @emergencyMental.
  ///
  /// In ko, this message translates to:
  /// **'정신건강 위기상담'**
  String get emergencyMental;

  /// No description provided for @emergencyMentalSub.
  ///
  /// In ko, this message translates to:
  /// **'마음이 너무 힘들 때 · 24시간'**
  String get emergencyMentalSub;

  /// No description provided for @emergencyGyeonggi.
  ///
  /// In ko, this message translates to:
  /// **'경기도 콜센터'**
  String get emergencyGyeonggi;

  /// No description provided for @emergencyGyeonggiSub.
  ///
  /// In ko, this message translates to:
  /// **'24시간 · 0번을 누르면 긴급 복지 위기 상담'**
  String get emergencyGyeonggiSub;

  /// No description provided for @emergencyRegion.
  ///
  /// In ko, this message translates to:
  /// **'{sido} 지역 번호와 전국 어디서나 되는 번호예요.'**
  String emergencyRegion(String sido);

  /// No description provided for @emergencyRegionUnknown.
  ///
  /// In ko, this message translates to:
  /// **'전국 어디서나 걸 수 있는 번호예요. 위치를 정하면 지역 번호도 보여 드려요.'**
  String get emergencyRegionUnknown;

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
  /// **'마중은 무료 급식소, 쉼터, 무료 진료소를 전국에서 찾는 앱이에요. 정부나 구청이 만든 앱이 아니고, 공공데이터를 바탕으로 만든 민간 앱이에요.'**
  String get infoAbout;

  /// No description provided for @infoPrivacy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보'**
  String get infoPrivacy;

  /// No description provided for @infoPrivacyBody.
  ///
  /// In ko, this message translates to:
  /// **'가입이 없고, 이름·전화번호를 받지 않아요. 위치는 가까운 순서를 계산할 때 휴대폰 안에서만 쓰고 저장하거나 보내지 않아요. 다만 지도를 볼 때는 지도 그림을 받으려고, 보고 있는 동네가 지도 서버에 전해져요.'**
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

  /// No description provided for @infoFontCredit.
  ///
  /// In ko, this message translates to:
  /// **'글꼴: 고운돋움 (SIL Open Font License 1.1)'**
  String get infoFontCredit;

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

  /// No description provided for @mapRecenterGps.
  ///
  /// In ko, this message translates to:
  /// **'내 위치로'**
  String get mapRecenterGps;

  /// No description provided for @mapRecenterRegion.
  ///
  /// In ko, this message translates to:
  /// **'처음 위치로'**
  String get mapRecenterRegion;

  /// No description provided for @mapLocateFailed.
  ///
  /// In ko, this message translates to:
  /// **'지금 위치를 찾지 못했어요. 전에 찾은 위치로 보여 드려요.'**
  String get mapLocateFailed;

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

  /// No description provided for @homeSavedTitle.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳'**
  String get homeSavedTitle;

  /// No description provided for @homeSavedSub.
  ///
  /// In ko, this message translates to:
  /// **'자주 가는 곳을 모아 뒀어요'**
  String get homeSavedSub;

  /// No description provided for @placeCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}곳'**
  String placeCount(int count);

  /// No description provided for @savedGroupHeader.
  ///
  /// In ko, this message translates to:
  /// **'{group}, 저장한 곳 {count}곳'**
  String savedGroupHeader(String group, int count);

  /// No description provided for @savedEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 저장한 곳이 없어요.\n시설을 열고 \'저장하기\'를 누르면 여기에 모여요.'**
  String get savedEmpty;

  /// No description provided for @savedMissing.
  ///
  /// In ko, this message translates to:
  /// **'정보가 바뀌었거나 목록에서 빠졌어요'**
  String get savedMissing;

  /// No description provided for @savedOldPhone.
  ///
  /// In ko, this message translates to:
  /// **'예전 전화번호 {phone} (바뀌었을 수 있어요)'**
  String savedOldPhone(String phone);

  /// No description provided for @savedCallOld.
  ///
  /// In ko, this message translates to:
  /// **'예전 번호로 전화'**
  String get savedCallOld;

  /// No description provided for @savedRemove.
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get savedRemove;

  /// No description provided for @savedSimilar.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 곳 보기: {name}'**
  String savedSimilar(String name);

  /// No description provided for @detailSave.
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get detailSave;

  /// No description provided for @detailUnsave.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳에서 빼기'**
  String get detailUnsave;

  /// No description provided for @savedAdded.
  ///
  /// In ko, this message translates to:
  /// **'저장했어요. 첫 화면에서 바로 볼 수 있어요'**
  String get savedAdded;

  /// No description provided for @savedRemoved.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳에서 뺐어요'**
  String get savedRemoved;

  /// No description provided for @infoSaved.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳'**
  String get infoSaved;

  /// No description provided for @infoSavedBody.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳은 이 휴대폰에만 있어요. 다른 곳으로 보내거나 백업하지 않아서, 휴대폰을 바꾸면 옮겨지지 않아요.'**
  String get infoSavedBody;

  /// No description provided for @infoClearSaved.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳 모두 지우기'**
  String get infoClearSaved;

  /// No description provided for @clearSavedTitle.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳을 모두 지울까요?'**
  String get clearSavedTitle;

  /// No description provided for @clearSavedBody.
  ///
  /// In ko, this message translates to:
  /// **'지우면 되돌릴 수 없어요.'**
  String get clearSavedBody;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @clearSavedConfirm.
  ///
  /// In ko, this message translates to:
  /// **'모두 지우기'**
  String get clearSavedConfirm;

  /// No description provided for @savedCleared.
  ///
  /// In ko, this message translates to:
  /// **'저장한 곳을 모두 지웠어요'**
  String get savedCleared;
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
