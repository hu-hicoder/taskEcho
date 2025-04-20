/// 音声認識テキストから抽出した
/// スケジュール候補を表すモデル
class ScheduleCandidate {
  final DateTime time;
  final String summary;

  ScheduleCandidate({
    required this.time,
    required this.summary,
  });

  @override
  String toString() => '$summary @ $time';
}