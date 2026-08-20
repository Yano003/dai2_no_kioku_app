import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_strings.dart';
import 'core/theme.dart';
import 'features/card/card_screen.dart';
import 'features/input/input_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: Dai2NoKiokuApp()));
}

/// アプリのルート。
class Dai2NoKiokuApp extends ConsumerStatefulWidget {
  const Dai2NoKiokuApp({super.key});

  @override
  ConsumerState<Dai2NoKiokuApp> createState() => _Dai2NoKiokuAppState();
}

class _Dai2NoKiokuAppState extends ConsumerState<Dai2NoKiokuApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// 通知タップで起動された場合に開くカードの日付。
  DateTime? _launchCardDate;

  /// 初回起動案内（S-01）が済んでいるか。
  bool _onboardingCompleted = false;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final notifications = ref.read(notificationServiceProvider);

    // アプリが動いている間に通知をタップした場合の遷移。
    notifications.onOpenCard = _openCard;

    await notifications.initialize();

    final settings = await ref.read(settingsProvider.future);

    // 通知は予約時点で文面が固定されるため、起動のたびに先の分を作り直す。
    // 長期間アプリを開かないと予約が尽きるため、起動時の再予約は必須。
    // 初回起動案内の途中では通知時刻がまだ決まっていないため行わない。
    if (settings.onboardingCompleted) {
      await notifications.rescheduleAll();
    }

    if (!mounted) return;
    setState(() {
      _launchCardDate = notifications.consumePendingCardDate();
      _onboardingCompleted = settings.onboardingCompleted;
      _ready = true;
    });

    // 端末によっては、通知タップの情報が初期化の直後ではなく最初のフレームの
    // 後に届く。ここで取りこぼすと通常の起動と見分けが付かず、明日のカードでは
    // なく今日のカードから始まってしまうため、もう一度だけ確かめる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = notifications.consumePendingCardDate();
      if (pending != null) _openCard(pending);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 日付をまたいだ場合にカードの表示パターンがずれるため、
    // 復帰のたびに組み立て直す。
    if (state == AppLifecycleState.resumed && _ready) {
      ref.read(cardsProvider.notifier).reload();
    }
  }

  /// 通知から対象の日のカードを開く。（要件定義書 6.3）
  ///
  /// 起動直後は Navigator がまだ構築されておらず、push しても黙って捨てられる。
  /// そこで日付を状態として持ち、表示の起点そのものをカードへ切り替える。
  /// Navigator があるときは加えて push し、その場で移動させる。
  /// どちらの経路でも必ず対象の日のカードから始まる。
  void _openCard(DateTime date) {
    if (!mounted) return;

    setState(() => _launchCardDate = date);

    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => CardScreen(initialDate: date)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: !_ready
          ? const _SplashScreen()
          // 初回起動時のみ案内を表示する。（要件定義書 4.1）
          : !_onboardingCompleted
              ? const OnboardingScreen()
              // 通知から起動された場合はカードを開く。（要件定義書 6.3）
              // 通常の起動は音声入力画面から始める。（要件定義書 4.2）
              : _launchCardDate != null
                  // 日付ごとに作り直す。[CardScreen] は起点の日付を initState で
                  // 1度だけ読むため、キーが同じだと State が使い回され、
                  // 前に開いた日付のまま表示されてしまう。
                  ? CardScreen(
                      key: ValueKey(_launchCardDate),
                      initialDate: _launchCardDate,
                    )
                  : const InputScreen(),
    );
  }
}

/// S-01 スプラッシュ。初期化の待ち時間に、名称とタグラインを見せる。
///
/// 初回起動案内はこの直後に表示される。
///
/// タグライン「思い出せる安心が、自信になる。」は起動時のここだけで使う。
/// 各画面に繰り返し出すと主張が強くなり、「1画面の情報量は少なく」という
/// 設計方針（要件定義書 1.3）に反するため。
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                AppStrings.appName,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  // 「キオクヲ」の語感を活かすため、字間をわずかに広げる。
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.tagline,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              const CircularProgressIndicator(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
