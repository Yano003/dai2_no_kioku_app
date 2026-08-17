/// アプリ内で利用者の目に触れる文言をすべて集約したファイル。
///
/// ■ 重要
/// ここに書かれている文言はすべて「仮」である。確定文言はヒトコト株式会社様より
/// ご提供いただき、実装完了時に一括で差し替える。（要件定義書 4.5 / 10章 前提5・6）
/// 差し替え作業がこの1ファイルで完結するよう、UI 側に文字列リテラルを
/// 直接書かないこと。
///
/// ■ 文字数の目安（レビュー追加提起 No.16）
/// 確定文言が想定より長いとレイアウトが崩れ、差し替え1回の枠に収まらなくなる。
/// 各定数のコメントに上限の目安を記載する。
///
/// ■ 用語の禁止事項（要件定義書 8章 デザイン方針）
/// 「シニア向け」「物忘れ対策」「認知症予防」等、高齢者向けを想起させる
/// 表現は使用しない。専門用語も使わない。（要件定義書 4.1）
///
/// ■ UI で使わない語（要件定義書 第2.0版 2.1）
/// 「履歴」は UI 上では使わない。将来この機能に名前を付ける必要が生じた場合は
/// 「今日のあしあと」を用いる。
library;

import 'app_identity.dart';

class AppStrings {
  const AppStrings._();

  // ---------------------------------------------------------------------------
  // アプリ共通
  // ---------------------------------------------------------------------------

  /// アプリ名。変更は [AppIdentity] 側で行う。
  static const appName = AppIdentity.displayName;

  /// ブランドタグライン。起動時に一度だけ見せる。
  static const tagline = AppIdentity.tagline;

  // ---------------------------------------------------------------------------
  // S-01 初回起動案内
  // 各許可の前に、なぜ必要かを1文で平易に説明する。（要件定義書 4.1）
  // ---------------------------------------------------------------------------

  /// 全角20文字以内。
  static const onboardingWelcomeTitle = 'ようこそ';

  /// 全角40文字以内。
  static const onboardingWelcomeBody = '予定を声や文字で簡潔に「今日の安心カード」に残して、思い出しやすくします。';

  /// 全角20文字以内。
  static const onboardingMicTitle = '声で登録するために';

  /// 全角40文字以内。専門用語を使わないこと。
  static const onboardingMicBody = '予定を声で登録するために、スマートフォン内蔵のマイクを使います。';

  static const onboardingSpeechTitle = '話した言葉を文字にするために';
  static const onboardingSpeechBody = '話した内容を文字にして、「今日の安心カード」に残します。';

  static const onboardingNotificationTitle = 'お知らせを届けるために';
  static const onboardingNotificationBody = '前の日の夜と当日の朝に、そっとお知らせします。';

  /// 許可しなくても使えることを添える。（要件定義書 4.1）
  /// 全角30文字以内。
  static const onboardingSpeechOptional = '許可しなくても、文字で入力してお使いいただけます。';
  static const onboardingNotificationOptional = '許可しなくても、アプリを開けば「今日の安心カード」を見られます。';

  /// あとから設定画面で有効にできることの案内。
  static const onboardingLaterNote = 'あとから設定で変えられます。';

  /// 起床・就寝時刻のヒアリング。（要件定義書 6.2）
  ///
  /// 伺った時刻そのものではなく、その30分前にお知らせすることを本文で添える。
  /// 何のために時刻を尋ねられているのかが分からないまま操作させないため。
  /// 「30分」は AppConfig.notificationOffsetBeforeSleep ／
  /// AppConfig.notificationOffsetBeforeWake と対で変更すること。
  static const onboardingSleepQuestion = 'いつも何時ごろお休みになりますか？';
  static const onboardingSleepBody = 'お知らせの時刻を決めるために伺います。\n'
      '設定した時刻のおよそ30分前に、そっとお知らせします。';
  static const onboardingWakeQuestion = 'いつも何時ごろお起きになりますか？';
  static const onboardingWakeBody = 'お知らせの時刻を決めるために伺います。\n'
      'およそ30分前にそっとお知らせします。';

  /// 時刻を選ぶボタンの補助ラベル。
  static const onboardingTapToChange = 'タップして変える';

  static const onboardingNext = '次へ';
  static const onboardingAllow = '許可する';
  static const onboardingSkip = 'あとで';
  static const onboardingStart = 'はじめる';

  // ---------------------------------------------------------------------------
  // S-02 TOP（音声入力）
  // ---------------------------------------------------------------------------

  /// S-02・S-03 共通の画面見出し。（画面イメージ）
  static const registerScreenTitle = '「今日の安心カード」登録';

  /// 全角30文字以内。
  ///
  /// 画面イメージでは「下のアイコンを押しながら…」だが、入力方式は
  /// 「タップで録音」に確定したため（要件定義書 11.1 No.1）、
  /// 押しながらではなくタップである旨に合わせている。
  static const inputPrompt = '下のアイコンを押して\nいつ・何をするか\n話しかけてください。';

  /// 録音中の表示。
  static const inputListening = '聞いています。';

  /// 全角20文字以内。
  static const inputStop = '話し終わりました';

  /// 文字入力への切り替え。（要件定義書 4.2）
  static const inputSwitchToText = '文字で入力する';

  /// 画面下部のボタン。（要件定義書 4.2）
  static const inputOpenCard = '今日の安心カードを見る';

  /// 音声入力の例示。対応する話し方を自然に伝える。（要件定義書 5章）
  static const inputExamples = [
    '「明日15時に歯医者」',
    '「毎朝、薬を飲む」',
    '「水曜はゴミの日」',
  ];

  // ---------------------------------------------------------------------------
  // テキスト入力画面
  // ---------------------------------------------------------------------------

  static const textInputTitle = '文字で入力する';
  static const textInputHint = '予定を入力してください';
  static const textInputConfirm = '確認する';

  // ---------------------------------------------------------------------------
  // S-03 登録確認画面
  // 音声認識は100%正確ではないため、登録前に必ず内容を確認させる。（要件定義書 4.3）
  // ---------------------------------------------------------------------------

  /// 全角20文字以内。
  static const confirmTitle = 'この内容でよろしいですか';

  static const confirmRegister = '登録する';
  static const confirmEdit = '修正する';

  /// 日付が聞き取れなかった場合の案内。（要件定義書 4.9）
  static const confirmDateMissing = '日付を選んでください';

  /// 予定名が空の場合の案内。
  static const confirmTitleMissing = '予定を入力してください';

  /// 1日の上限に達している場合の案内。（要件定義書 2.2）
  ///
  /// 「登録できません」と突き放さず、覚えやすさのための上限であることを
  /// 穏やかに伝え、別の日への登録は妨げないことを添える。
  /// {max} に上限件数、{date} に対象日が入る。全角60文字以内。
  static const confirmLimitReached =
      '{date}はすでに{max}つの予定があります。覚えておくことが多くなりすぎないよう、'
      '1日{max}つまでにしています。別の日でしたら登録できます。';

  /// 上限に達している日を示す短い表示。
  static const confirmLimitBadge = 'この日はいっぱいです';

  /// 上限までの残り件数。{count} に残数が入る。
  static const confirmRemaining = 'この日はあと{count}つ登録できます';

  /// 終日の予定の時刻表示。
  static const confirmAllDay = '時刻の指定なし';

  static const confirmRepeatDaily = '毎日';
  static const confirmRepeatWeeklyPrefix = '毎週';

  // ---------------------------------------------------------------------------
  // S-04 通知時刻設定
  // ---------------------------------------------------------------------------

  static const notifySetupTitle = 'お知らせの時刻';

  /// 逆算した初期値を提示していることの説明。全角40文字以内。（要件定義書 6.2）
  static const notifySetupDescription = 'お休みになる時刻とお起きになる時刻から、お知らせの時刻を下記に設定します。';

  static const notifySetupNightLabel = '前の日の夜';
  static const notifySetupNightHint = '明日の予定をお知らせします';
  static const notifySetupMorningLabel = '当日の朝';
  static const notifySetupMorningHint = '今日の予定をお知らせします';
  static const notifySetupSave = 'この時刻にする';

  /// 一度設定すれば以降は引き継がれることの説明。（要件定義書 4.4）
  static const notifySetupNote = 'あとから変えられます。毎回設定する必要はありません。';

  /// 通知が拒否されている場合の注意書き。
  static const notifySetupPermissionDenied = 'お知らせが許可されていないため、今は届きません。';

  // ---------------------------------------------------------------------------
  // S-05 安心カード
  // 要件定義書 4.5「カードの表示パターン」に対応する。
  // すべて仮文言。◯には件数が入る。
  // ---------------------------------------------------------------------------

  // ---- カードの名前（見出し行）----
  // 画面イメージでは、カードの名前と日付を別の行に分けて表示している。

  static const cardTitleToday = '今日の安心カード';
  static const cardTitleTomorrow = '明日の安心カード';
  static const cardTitleYesterday = '昨日の安心カード';

  /// 一昨日以前・明後日以降のカードの名前。{date} に「7月20日」が入る。
  static const cardTitleOther = '{date}の安心カード';

  // ---- カード本文 ----

  /// 前日夜。全角25文字以内。
  static const cardPreviousNight = '明日はこれだけ覚えておけば大丈夫です。';

  /// 当日朝。{count} に件数が入る。全角25文字以内。
  static const cardMorning = '今日は{count}つ覚えておけば大丈夫です。';

  /// 前日夜のカードの締め。
  static const cardPreviousNightClosing = 'また明日の朝にお会いしましょう。';

  /// 明後日以降のカード。
  static const cardFuture = 'この日はこれだけ覚えておけば大丈夫です。';

  /// 過去のカード。UI では「履歴」という語を使わない。（要件定義書 2.1）
  static const cardPast = 'この日の記録です。';

  /// その日の予定をすべて完了したときに、一覧の下へ添える労いの言葉。
  /// （お客様ご指摘 2026/08/17）
  ///
  /// 最後の1つにチェックが付いた時点でその場に現れる。画面を切り替えたり
  /// 専用のカードを出したりはしない。全角30文字以内。
  static const cardAllDone = '予定を、すべてクリアできました。';

  /// [cardAllDone] に続けて、その日のうちだけ添える一言。
  ///
  /// 翌日以降は [cardAllDone] の1行だけを記録として残す。過去のカードは
  /// 読み返すためのもので、その日をねぎらう言葉まで残すと場違いになるため。
  static const cardAllDoneRelax = '安心してお過ごしください。';

  /// 予定がない日。不安を与えない穏やかな表現にする。（要件定義書 4.9）
  ///
  /// {day} に「今日」「明日」「昨日」または「8月4日」が入る。
  /// 上下スクロールで日付を行き来する画面のため、本文だけを見ても
  /// どの日のことか分かるようにする。（お客様ご指摘 2026/08/17）
  static const cardEmpty = '{day}の予定はありません。';

  /// 前日夜のボタン。
  static const cardGoodNight = 'おやすみなさい';

  /// 当日朝のボタン。
  static const cardHaveANiceDay = 'いってらっしゃい';

  // 当日日中の「確認しました」ボタンは第2.0版で廃止された。（要件定義書 4.5）
  // 実質的にアプリを閉じるだけの操作のため不要と判断されたもの。
  // 完了チェックは各予定のチェックボックスで行う。

  // 「おやすみなさい」「いってらっしゃい」を押した後は、押した言葉を
  // そのまま静かな文字で残す。専用の文言は持たない。（お客様ご指摘 2026/08/17）
  // 別の一文（「また見にきてください」）に差し替えると、押した操作と
  // 表示がつながらず、押せたのかどうかが分からなくなるため。

  static const cardToday = '今日';
  static const cardTomorrow = '明日';
  static const cardYesterday = '昨日';

  static const cardOpenCalendar = 'カレンダー';

  /// 画面イメージでは S-05 下部の登録ボタンは「登録する」。
  static const cardOpenInput = '登録する';

  // ---------------------------------------------------------------------------
  // S-06 カレンダー
  // ---------------------------------------------------------------------------

  static const calendarTitle = 'カレンダー';

  /// 月の見出し。{year} と {month} を置き換える。
  static const calendarMonthTitle = '{year}年{month}月';

  static const calendarPreviousMonth = '前の月';
  static const calendarNextMonth = '次の月';
  static const calendarBackToToday = '今日へ';

  /// 予定がある日の印の読み上げラベル。（要件定義書 4.6）
  static const calendarHasSchedule = '予定あり';

  /// 曜日の見出し。日曜始まり。
  static const calendarWeekdayHeaders = ['日', '月', '火', '水', '木', '金', '土'];

  // ---------------------------------------------------------------------------
  // S-07 修正画面
  // ---------------------------------------------------------------------------

  static const editTitle = '予定を修正する';
  static const editNameLabel = '予定';
  static const editDateLabel = '日付';
  static const editTimeLabel = '時刻';
  static const editRepeatLabel = '繰り返し';
  static const editSave = '保存する';
  static const editDelete = '削除する';

  /// 音声での言い直し。（要件定義書 4.7）
  static const editReRecord = '話して直す';
  static const editListening = '聞いています。';

  /// 削除確認。
  static const editDeleteConfirm = 'この予定を削除しますか';
  static const editDeleteConfirmYes = '削除する';
  static const editDeleteConfirmNo = 'やめる';

  static const editRepeatNone = '繰り返さない';
  static const editRepeatDaily = '毎日';
  static const editRepeatWeekly = '毎週';

  /// 時刻を指定しない状態に戻す。
  static const editClearTime = '時刻を決めない';

  /// 繰り返し予定の変更が今後すべてに及ぶことの説明。（レビュー追加提起 No.13）
  /// 全角30文字以内。
  static const editRepeatScopeNote = 'この変更は、これからの分すべてに反映されます。';

  /// カードの各行から修正画面を開くボタンの読み上げラベル。
  static const editOpenLabel = 'この予定を修正する';

  // ---------------------------------------------------------------------------
  // S-08 設定
  // ---------------------------------------------------------------------------

  static const settingsTitle = '設定';

  static const settingsNotifySection = 'お知らせの時刻';

  static const settingsSleepSection = 'いつもの時刻';
  static const settingsSleepLabel = 'お休みになる時刻';
  static const settingsWakeLabel = 'お起きになる時刻';

  /// 起床・就寝を変えると通知時刻も追随することの説明。全角40文字以内。
  static const settingsSleepNote =
      'ここを変えると、お知らせの時刻も30分前に合わせて変わります。';

  static const settingsPermissionSection = '利用の許可';
  static const settingsPermissionSpeech = '声での登録';
  static const settingsPermissionNotification = 'お知らせ';
  static const settingsPermissionGranted = '許可されています';
  static const settingsPermissionDenied = '許可されていません';

  /// 許可が無くても使えることの補足。
  static const settingsPermissionNote = '許可がなくても、文字で入力してお使いいただけます。';

  static const settingsOpenOsSettings = '端末の設定を開く';

  // ---------------------------------------------------------------------------
  // S-09 通知
  // 通知は一文で届き、タップするとカードが開く。（要件定義書 6.3）
  // ---------------------------------------------------------------------------

  /// 前日夜の通知。全角30文字以内。
  ///
  /// 予定がある日も無い日も同じ文面にする。（お客様ご指摘 2026/08/17）
  /// 通知は挨拶とカードへの誘導だけを担い、中身はカードで伝える。
  /// 予定の有無で文面が変わると、ロック画面の一文だけで判断させることになり、
  /// カードを開かないまま済ませてしまうため。
  static const notificationNightTitle = 'こんばんは';
  static const notificationNightBody = '明日の安心カードを確かめましょう';

  /// 当日朝の通知。全角30文字以内。前日夜と同じ考え方で件数を含めない。
  static const notificationMorningTitle = 'おはようございます';
  static const notificationMorningBody = '今日の安心カードを確かめましょう';

  /// 事前に予約した通知が尽きた場合のフォールバック。件数を含められない。
  static const notificationFallbackBody = '安心カードをご確認ください';

  // ---------------------------------------------------------------------------
  // S-10 空・エラー表示
  // ---------------------------------------------------------------------------

  /// 聞き取れなかった場合。「聞き取れませんでした」で終わらせない。（要件定義書 4.9）
  static const errorSpeechEmpty = 'もう一度、お願いします。';

  /// 一部だけ聞き取れた場合の案内。
  static const errorSpeechPartial = '聞き取れた分を残しました。日付をお選びください。';

  /// 音声認識が使えない端末・許可されていない場合。
  static const errorSpeechUnavailable = '文字で入力してください';

  static const errorRetry = 'もう一度話す';

  // ---------------------------------------------------------------------------
  // 置換ヘルパー
  // ---------------------------------------------------------------------------

  /// 「今日は{count}つ〜」の {count} を実際の件数に置き換える。
  static String withCount(String template, int count) =>
      template.replaceAll('{count}', '$count');

  /// 文言中の {キー} を値に置き換える。
  ///
  /// 例: fill(confirmLimitReached, {'date': '8月5日', 'max': '5'})
  static String fill(String template, Map<String, String> values) {
    var result = template;
    values.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
