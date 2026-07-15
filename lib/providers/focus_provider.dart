import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/focus_session.dart';
import '../database/database_helper.dart';
import '../core/constants.dart';

/// 专注模式状态管理
class FocusSessionNotifier extends StateNotifier<FocusSessionState> {
  Timer? _timer;

  FocusSessionNotifier() : super(const FocusSessionState());

  /// 开始专注
  void start(FocusSessionConfig config) {
    final totalSec = config.durationMinutes * 60;
    state = FocusSessionState(
      status: FocusStatus.running,
      config: config,
      remainingSeconds: totalSec,
      totalSeconds: totalSec,
      startedAt: DateTime.now(),
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds <= 0) {
        _complete();
        return;
      }
      state = state.copyWith(
        remainingSeconds: state.remainingSeconds - 1,
      );
    });
  }

  /// 取消专注
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    if (state.startedAt != null && state.status == FocusStatus.running) {
      try {
        final durationMin =
            DateTime.now().difference(state.startedAt!).inMinutes.toDouble();
        await DatabaseHelper.insertFocusLog(FocusSessionLog(
          configId: state.config?.id,
          configName: state.config?.name ?? '专注',
          startedAt: state.startedAt!,
          endedAt: DateTime.now(),
          completed: false,
          durationMinutes: durationMin,
        ));
      } catch (_) {}
    }
    state = const FocusSessionState();
  }

  /// 重置状态（不写日志，用于完成后"再来一次"）
  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const FocusSessionState();
  }

  /// 完成专注
  Future<void> _complete() async {
    if (state.status != FocusStatus.running) return;
    _timer?.cancel();
    _timer = null;
    // 立即更新状态，防止 cancel() 在 await 期间竞态
    final savedState = state;
    state = state.copyWith(
      status: FocusStatus.completed,
      remainingSeconds: 0,
    );
    if (savedState.startedAt != null && savedState.config != null) {
      try {
        await DatabaseHelper.insertFocusLog(FocusSessionLog(
          configId: savedState.config!.id,
          configName: savedState.config!.name,
          startedAt: savedState.startedAt!,
          endedAt: DateTime.now(),
          completed: true,
          durationMinutes: savedState.config!.durationMinutes.toDouble(),
        ));
        await DatabaseHelper.addPoints(
          AppConstants.pointsFocusComplete,
          'focus_complete',
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 专注历史记录
class FocusHistoryNotifier extends StateNotifier<List<FocusSessionLog>> {
  FocusHistoryNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    try { await load(); } catch (_) {}
  }

  Future<void> load() async {
    state = await DatabaseHelper.getFocusLogs();
  }

  Future<double> getTotalMinutes() async {
    return await DatabaseHelper.getTotalFocusMinutes();
  }
}

final focusSessionProvider = StateNotifierProvider<FocusSessionNotifier,
    FocusSessionState>((ref) => FocusSessionNotifier());

final focusHistoryProvider =
    StateNotifierProvider<FocusHistoryNotifier, List<FocusSessionLog>>(
        (ref) => FocusHistoryNotifier());
