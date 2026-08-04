// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '削除';

  @override
  String get commonNoRecordsYet => '記録がまだありません';

  @override
  String get commonDateLabel => '日付';

  @override
  String get commonTimeLabel => '時刻';

  @override
  String get healthRecordDeleteConfirmTitle => 'この記録を削除しますか？';

  @override
  String get healthRecordNoCommentPlaceholder => '(コメントなし)';

  @override
  String get healthRecordFormTitleNew => '新規健康記録';

  @override
  String get healthRecordFormTitleEdit => '健康記録を編集';

  @override
  String get healthRecordDateTimeLabel => '記録日時';

  @override
  String get healthRecordTagsSectionLabel => 'カテゴリタグ';

  @override
  String get healthRecordPhotosSectionLabel => '写真';

  @override
  String healthRecordPhotoCount(int count, int max) {
    return '$count/$max枚';
  }

  @override
  String get healthRecordCommentLabel => 'コメント';

  @override
  String get healthRecordTimelineTitle => '健康記録';

  @override
  String get healthRecordTagSkin => '皮膚';

  @override
  String get healthRecordTagAppetiteLoss => '食欲不振';

  @override
  String get healthRecordTagLowEnergy => '元気がない';

  @override
  String get healthRecordTagVomiting => '嘔吐';

  @override
  String get healthRecordTagDiarrhea => '下痢';

  @override
  String get healthRecordTagOther => 'その他';

  @override
  String get toiletFrequencyChartTitle => 'トイレ頻度';

  @override
  String get toiletUrineLabel => '排尿';

  @override
  String get toiletStoolLabel => '排便';

  @override
  String get toiletRecordStoolFormTitle => '排便を記録';

  @override
  String get toiletHardnessSectionLabel => '硬さ';

  @override
  String get toiletColorSectionLabel => '色';

  @override
  String get toiletPhotoAddLabel => '写真を追加（任意）';

  @override
  String get toiletPhotoChangeLabel => '写真を変更';

  @override
  String get toiletRecordTimelineTitle => 'トイレ記録';

  @override
  String get toiletConsultAiButtonLabel => 'AI相談する';

  @override
  String toiletUrineColorSubtitle(String color) {
    return '色: $color';
  }

  @override
  String toiletStoolConditionSubtitle(String hardness, String color) {
    return '硬さ: $hardness / 色: $color';
  }

  @override
  String get toiletRecordUrineDialogTitle => '排尿を記録';

  @override
  String get toiletUrineColorShadeLabel => '色の濃淡';

  @override
  String get toiletRecordSubmitButtonLabel => '記録する';

  @override
  String get toiletHardnessNormal => '正常';

  @override
  String get toiletHardnessSoft => '軟便';

  @override
  String get toiletHardnessDiarrhea => '下痢';

  @override
  String get toiletHardnessHard => '硬い';

  @override
  String get toiletColorNormal => '正常';

  @override
  String get toiletColorBloodSuspected => '血便疑い';

  @override
  String get toiletColorPale => '白っぽい';

  @override
  String get urineColorPale => '薄い（無色に近い）';

  @override
  String get urineColorNormal => '正常（淡黄色）';

  @override
  String get urineColorDark => '濃い（濃縮尿）';

  @override
  String get weightRecordTimelineTitle => '体重記録';

  @override
  String get weightShowChartTooltip => 'グラフ表示';

  @override
  String get weightShowTableTooltip => '表形式で表示';

  @override
  String get weightDuplicateDateDialogTitle => '同じ日の記録があります';

  @override
  String get weightDuplicateDateDialogContent =>
      '上書きしますか？それとも追加で記録しますか？（同日に複数回記録された場合の扱い、spec 3.4）';

  @override
  String get weightAddAsNewEntryButtonLabel => '追加する';

  @override
  String get weightOverwriteButtonLabel => '上書きする';

  @override
  String get weightPeriodOneMonth => '1ヶ月';

  @override
  String get weightPeriodThreeMonths => '3ヶ月';

  @override
  String get weightPeriodOneYear => '1年';

  @override
  String get weightDeltaVsPreviousLabel => '前回比';

  @override
  String get weightDeltaVsOneMonthAgoLabel => '1ヶ月前比';

  @override
  String get weightNoRecordsForPeriod => 'この期間の記録がありません';

  @override
  String get weightEntryDialogTitle => '体重を記録';

  @override
  String get weightKgFieldLabel => '体重 (kg)';
}
