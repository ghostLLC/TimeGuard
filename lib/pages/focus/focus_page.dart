import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/focus_session.dart';
import '../../providers/focus_provider.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  int _selectedDuration = 45; // 默认 45 分钟
  final TextEditingController _nameController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _nameController.text = '专注';
    // 定时刷新 UI（每秒更新倒计时）
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(focusSessionProvider).status == FocusStatus.running) {
        setState(() {}); // 触发 UI 更新
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusState = ref.watch(focusSessionProvider);
    final history = ref.watch(focusHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('专注模式')),
      body: focusState.status == FocusStatus.running ||
              focusState.status == FocusStatus.completed
          ? _buildTimerView(context, focusState)
          : _buildSetupView(context, history),
    );
  }

  /// 计时器视图
  Widget _buildTimerView(BuildContext context, FocusSessionState state) {
    final isCompleted = state.status == FocusStatus.completed;
    final remaining = state.remainingSeconds;
    final progress = state.progress;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 大圆环倒计时
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 背景圆环
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12,
                      color: Colors.grey.shade100,
                    ),
                  ),
                  // 进度圆环
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: isCompleted ? 1.0 : progress,
                      strokeWidth: 12,
                      color: isCompleted
                          ? AppTheme.secondaryColor
                          : AppTheme.primaryColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // 中心内容
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCompleted)
                        const Icon(
                          Icons.check_circle,
                          size: 48,
                          color: AppTheme.secondaryColor,
                        )
                      else
                        Text(
                          remaining > 3600
                              ? AppUtils.formatCountdownLong(remaining)
                              : AppUtils.formatCountdown(remaining),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        state.config?.name ?? '专注',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            if (isCompleted) ...[
              Text(
                '专注完成！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+${AppConstants.pointsFocusComplete} 积分',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // 重置状态
                  ref.read(focusSessionProvider.notifier).cancel();
                  ref.read(focusHistoryProvider.notifier).load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                ),
                child: const Text('再来一次'),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () async {
                  await ref.read(focusSessionProvider.notifier).cancel();
                  ref.read(focusHistoryProvider.notifier).load();
                },
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('结束专注'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 设置视图
  Widget _buildSetupView(BuildContext context, List<FocusSessionLog> history) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 专注名称
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '专注方案名称',
              hintText: '例如：考研自习、深度阅读',
            ),
          ),

          const SizedBox(height: 24),

          // 时长选择
          Text(
            '专注时长',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppConstants.focusPresets.map((min) {
              final isSelected = _selectedDuration == min;
              return ChoiceChip(
                label: Text('$min 分钟'),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedDuration = min);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // 开始按钮
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _startFocus(),
              icon: const Icon(Icons.play_arrow, size: 28),
              label: Text(
                '开始专注 $_selectedDuration 分钟',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 专注历史
          Text(
            '专注记录',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.self_improvement,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    '还没有专注记录',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ...history.take(10).map((log) => Card(
                  child: ListTile(
                    leading: Icon(
                      log.completed
                          ? Icons.check_circle
                          : Icons.cancel_outlined,
                      color:
                          log.completed ? AppTheme.secondaryColor : Colors.red,
                    ),
                    title: Text(log.configName),
                    subtitle: Text(
                      '${_formatDate(log.startedAt)} · '
                      '${AppUtils.formatMinutes(log.durationMinutes)}',
                    ),
                    trailing: log.completed
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '完成',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '中断',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                )),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _startFocus() {
    final config = FocusSessionConfig(
      name: _nameController.text.isNotEmpty ? _nameController.text : '专注',
      durationMinutes: _selectedDuration,
    );
    ref.read(focusSessionProvider.notifier).start(config);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
