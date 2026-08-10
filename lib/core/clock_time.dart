/// 時刻（時・分）。
///
/// Flutter の TimeOfDay に依存させないことで、パーサ・通知の予約計算・
/// カードの判定を純粋な Dart として単体テストできるようにしている。
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;

  /// 時刻を進める。24時をまたぐ場合は巻き戻る。
  ClockTime add(Duration duration) {
    const minutesPerDay = 24 * 60;
    final total = (totalMinutes + duration.inMinutes) % minutesPerDay;
    final wrapped = total < 0 ? total + minutesPerDay : total;
    return ClockTime(wrapped ~/ 60, wrapped % 60);
  }

  /// 時刻を戻す。0時をまたぐ場合は巻き戻る。
  ///
  /// 「就寝の30分前」の算出に使う。就寝が0時15分なら通知は23時45分になる。
  /// （要件定義書 6.2）
  ClockTime subtract(Duration duration) => add(-duration);

  @override
  int compareTo(ClockTime other) => totalMinutes.compareTo(other.totalMinutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
