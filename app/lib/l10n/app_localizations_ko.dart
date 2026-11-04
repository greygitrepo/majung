// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class L10nKo extends L10n {
  L10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '마중';

  @override
  String get homeGreeting => '어디로 갈까요?';

  @override
  String get homeGreetingSub => '가까운 곳부터 보여 드릴게요';

  @override
  String get groupMeal => '밥 먹을 곳';

  @override
  String get groupMealSub => '무료 급식';

  @override
  String get groupSleep => '잘 곳';

  @override
  String get groupSleepSub => '쉼터 · 잠자리';

  @override
  String get groupWash => '씻을 곳 · 빨래';

  @override
  String get groupWashSub => '샤워 · 세탁';

  @override
  String get groupClinic => '아플 때';

  @override
  String get groupClinicSub => '무료 진료소 · 보건소';

  @override
  String get groupGroceries => '먹을거리 받기';

  @override
  String get groupGroceriesSub => '푸드뱅크 · 푸드마켓';

  @override
  String openCount(int open, int total) {
    return '지금 열림 $open곳 · 모두 $total곳';
  }

  @override
  String get originNone => '어디 근처에서 찾을지 먼저 정해 주세요';

  @override
  String get originGps => '내 위치 기준';

  @override
  String originRegion(String place) {
    return '$place 기준';
  }

  @override
  String get originChange => '바꾸기';

  @override
  String get originSet => '위치 정하기';

  @override
  String get pickerTitle => '어디 근처에서 찾을까요?';

  @override
  String get pickerUseGps => '지금 내 위치 쓰기';

  @override
  String get pickerGpsWhy => '가까운 곳부터 보여 드리려고 위치를 써요.\n위치는 휴대폰 밖으로 보내지 않아요.';

  @override
  String get pickerOr => '또는 지역을 고르세요';

  @override
  String pickerSigungu(String sido) {
    return '$sido에서 고르세요';
  }

  @override
  String get pickerBack => '다른 시·도 고르기';

  @override
  String get pickerNoRegions => '지역 목록을 불러오지 못했어요. 위치 쓰기를 눌러 주세요.';

  @override
  String get pickerLocating => '위치를 찾고 있어요…';

  @override
  String get locDenied => '위치를 쓸 수 없어요. 아래에서 지역을 골라 주세요.';

  @override
  String get locDeniedForever =>
      '위치 권한이 꺼져 있어요. 휴대폰 설정에서 켜거나, 아래에서 지역을 골라 주세요.';

  @override
  String get locServiceOff => '휴대폰 위치(GPS)가 꺼져 있어요. 켜거나, 아래에서 지역을 골라 주세요.';

  @override
  String get locError => '위치를 찾지 못했어요. 아래에서 지역을 골라 주세요.';

  @override
  String get openSettings => '설정 열기';

  @override
  String get statusOpen => '지금 열려 있어요';

  @override
  String get statusClosingSoon => '곧 닫아요';

  @override
  String get statusClosed => '지금은 닫혀 있어요';

  @override
  String get statusUnknown => '운영 시간 확인 필요';

  @override
  String statusUntil(String time) {
    return '$time까지';
  }

  @override
  String statusOpensAt(String time) {
    return '$time에 열어요';
  }

  @override
  String get statusNoNextOpen => '다음 운영일은 전화로 확인하세요';

  @override
  String get statusCallFirst => '가기 전에 전화해 보세요';

  @override
  String get holidayWarning => '오늘은 공휴일이라 운영이 다를 수 있어요';

  @override
  String get today => '오늘';

  @override
  String get tomorrow => '내일';

  @override
  String get am => '오전';

  @override
  String get pm => '오후';

  @override
  String get noon => '낮';

  @override
  String get everyDay => '매일';

  @override
  String hourOnly(String period, int hour) {
    return '$period $hour시';
  }

  @override
  String hourMinute(String period, int hour, int minute) {
    return '$period $hour시 $minute분';
  }

  @override
  String get midnight => '밤 12시';

  @override
  String get allDay => '24시간';

  @override
  String walk(int minutes, String distance) {
    return '걸어서 약 $minutes분 ($distance)';
  }

  @override
  String distanceOnly(String distance) {
    return '여기서 $distance';
  }

  @override
  String whoCanUse(String who) {
    return '이용: $who';
  }

  @override
  String get call => '전화';

  @override
  String get callLong => '전화 걸기';

  @override
  String get directions => '길찾기';

  @override
  String get details => '자세히';

  @override
  String get noPhone => '전화번호 없음';

  @override
  String get viewMap => '지도로 보기';

  @override
  String get viewList => '목록으로 보기';

  @override
  String get listCallFirstBanner => '시간이 바뀔 수 있어요. 가기 전에 전화로 한 번 확인해 주세요.';

  @override
  String get listEmpty => '아직 등록된 곳이 없어요.';

  @override
  String get listEmptyHelp => '급하면 아래 번호로 전화하세요.';

  @override
  String get listNeedOrigin => '어디 근처에서 찾을지 먼저 정해 주세요';

  @override
  String get listNeedOriginHelp => '전국의 시설 중 가까운 곳만 보여 드려요.';

  @override
  String get homeNeedOrigin => '위치를 정하면 가까운 곳을 보여 드려요';

  @override
  String get seniorSectionTitle => '어르신 경로식당';

  @override
  String get seniorSectionSub =>
      '그 동네에 사는 어르신이 미리 등록해야 먹을 수 있는 곳이에요. 처음이면 전화로 물어보세요.';

  @override
  String get clinicFree => '무료 진료소';

  @override
  String get clinicHealthCenter => '보건소 · 진료비가 싸요 (무료 아님)';

  @override
  String get clinicHospitalSupport => '입원·수술비 지원 병원';

  @override
  String get clinicInfoTitle => '노숙인 의료급여증이 있으면 병원비가 거의 들지 않아요';

  @override
  String get clinicInfoBody =>
      '노숙한 지 1개월이 넘고, 건강보험이 없거나 3개월 넘게 못 냈다면 받을 수 있어요. 쉼터나 노숙인 종합지원센터에 신청해요. 일부 검사·치료는 돈을 낼 수 있어요. 잘 모르면 129에 전화해 물어보세요.';

  @override
  String get detailHours => '언제 가면 되나요';

  @override
  String get detailNoHours => '운영 시간 정보가 없어요. 전화로 확인하세요.';

  @override
  String get detailUnverifiedHours =>
      '아래는 공공데이터에 적힌 내용이에요. 실제와 다른 경우가 많아요. 가기 전에 꼭 전화해 보세요.';

  @override
  String get detailWho => '누가 갈 수 있나요';

  @override
  String get detailRequirements => '준비할 것 · 조건';

  @override
  String get detailAddress => '주소';

  @override
  String get detailCopyAddress => '주소 복사';

  @override
  String get detailCopied => '주소를 복사했어요';

  @override
  String get detailGeocoded => '지도 위치는 주소로 찾은 대략적인 위치예요.';

  @override
  String get detailNote => '참고';

  @override
  String get detailUnknownField => '확인 필요';

  @override
  String detailVerified(String date) {
    return '마지막 확인: $date';
  }

  @override
  String detailSource(String source) {
    return '출처: $source';
  }

  @override
  String get detailReport => '정보가 틀렸어요';

  @override
  String get staleWarning => '정보가 오래됐을 수 있어요. 가기 전에 전화로 확인하세요.';

  @override
  String get expiredWarning => '오랫동안 확인하지 못한 정보예요. 꼭 전화로 확인하세요.';

  @override
  String get weekdayMon => '월';

  @override
  String get weekdayTue => '화';

  @override
  String get weekdayWed => '수';

  @override
  String get weekdayThu => '목';

  @override
  String get weekdayFri => '금';

  @override
  String get weekdaySat => '토';

  @override
  String get weekdaySun => '일';

  @override
  String weekdayFull(String day) {
    return '$day요일';
  }

  @override
  String get closedDay => '쉬어요';

  @override
  String get emergencyButton => '급할 때 전화하기';

  @override
  String get emergencyHint => '혼자 힘들 땐 언제든 전화하세요';

  @override
  String get emergencyTitle => '급할 때 전화하세요';

  @override
  String get emergencyHomeless => '노숙인 위기대응콜';

  @override
  String get emergencyHomelessSub => '잘 곳이 없거나 위험할 때 · 서울 · 24시간';

  @override
  String get emergencyWelfare => '보건복지상담센터';

  @override
  String get emergencyWelfareSub => '생계가 막막할 때 · 긴급 복지 상담 24시간';

  @override
  String get emergencySuicide => '자살예방 상담전화';

  @override
  String get emergencySuicideSub => '너무 힘들고 지칠 때, 24시간';

  @override
  String get emergencyDasan => '다산콜센터';

  @override
  String get emergencyDasanSub => '서울시 생활 · 복지 안내';

  @override
  String get emergencyMental => '정신건강 위기상담';

  @override
  String get emergencyMentalSub => '마음이 너무 힘들 때 · 24시간';

  @override
  String get emergencyGyeonggi => '경기도 콜센터';

  @override
  String get emergencyGyeonggiSub => '24시간 · 0번을 누르면 긴급 복지 위기 상담';

  @override
  String emergencyRegion(String sido) {
    return '$sido 지역 번호와 전국 어디서나 되는 번호예요.';
  }

  @override
  String get emergencyRegionUnknown =>
      '전국 어디서나 걸 수 있는 번호예요. 위치를 정하면 지역 번호도 보여 드려요.';

  @override
  String get emergencyPolice => '경찰';

  @override
  String get emergencyPoliceSub => '위험하거나 범죄를 당했을 때';

  @override
  String get emergencyFire => '구급차 · 소방';

  @override
  String get emergencyFireSub => '다치거나 아플 때, 너무 춥거나 더울 때';

  @override
  String get info => '앱 정보';

  @override
  String get infoAbout =>
      '마중은 무료 급식소, 쉼터, 무료 진료소를 전국에서 찾는 앱이에요. 정부나 구청이 만든 앱이 아니고, 공공데이터를 바탕으로 만든 민간 앱이에요.';

  @override
  String get infoPrivacy => '개인정보';

  @override
  String get infoPrivacyBody =>
      '가입이 없고, 이름·전화번호를 받지 않아요. 위치는 가까운 순서를 계산할 때 휴대폰 안에서만 쓰고 저장하거나 보내지 않아요.';

  @override
  String get infoSources => '데이터 출처';

  @override
  String infoDataVersion(String date) {
    return '데이터 기준일: $date';
  }

  @override
  String get infoMapCredit => '지도: © OpenStreetMap 기여자';

  @override
  String get infoFontCredit => '글꼴: 고운돋움 (SIL Open Font License 1.1)';

  @override
  String get infoContact => '문의 · 오류 신고';

  @override
  String get mapAttribution => '© OpenStreetMap';

  @override
  String get mapHint => '핀을 누르면 정보가 나와요';

  @override
  String get mapRecenterGps => '내 위치로';

  @override
  String get mapRecenterRegion => '처음 위치로';

  @override
  String get mapLocateFailed => '지금 위치를 찾지 못했어요. 전에 찾은 위치로 보여 드려요.';

  @override
  String get mapUnavailable => '지도를 불러올 수 없어요. 목록으로 보세요.';

  @override
  String get launchFailed => '열 수 있는 앱이 없어요';

  @override
  String get updated => '새 정보로 바꿨어요';
}
