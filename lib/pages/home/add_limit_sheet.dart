import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../../models/app_limit.dart';
import '../../models/category.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/app_limits_provider.dart';

class AddLimitSheet extends ConsumerStatefulWidget {
  const AddLimitSheet({super.key});

  @override
  ConsumerState<AddLimitSheet> createState() => _AddLimitSheetState();
}

class _AddLimitSheetState extends ConsumerState<AddLimitSheet> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  bool _loading = true;
  String _searchQuery = '';

  AppInfo? _selectedApp;
  double _dailyLimitMinutes = 60;
  bool _showPeriodLimits = false;
  double _morningLimit = 30;
  double _afternoonLimit = 30;
  double _eveningLimit = 30;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await InstalledApps.getInstalledApps(false, true);
      // 过滤掉系统应用和自身
      final filtered = apps.where((app) {
        return !app.packageName!.startsWith('com.android.') &&
            !app.packageName!.contains('timeguard') &&
            app.name != null &&
            app.name!.isNotEmpty;
      }).toList();
      filtered.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      if (!mounted) return;
      setState(() {
        _apps = filtered;
        _filteredApps = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredApps = _apps;
      } else {
        _filteredApps = _apps
            .where((app) =>
                (app.name ?? '').toLowerCase().contains(query.toLowerCase()) ||
                (app.packageName ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  _selectedApp != null ? '设定限额' : '选择应用',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (_selectedApp != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedApp = null),
                    child: const Text('重新选择'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 内容
          Expanded(
            child: _selectedApp != null
                ? _buildLimitConfig(context, categories)
                : _buildAppSelector(context),
          ),
        ],
      ),
    );
  }

  /// 应用选择器
  Widget _buildAppSelector(BuildContext context) {
    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索应用...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _onSearch(''),
                    )
                  : null,
            ),
            onChanged: _onSearch,
          ),
        ),

        // 应用列表
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredApps.isEmpty
                  ? const Center(child: Text('未找到应用'))
                  : ListView.builder(
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        return ListTile(
                          leading: app.icon != null
                              ? Image.memory(app.icon!, width: 40, height: 40)
                              : const Icon(Icons.apps, size: 40),
                          title: Text(app.name ?? ''),
                          subtitle: Text(
                            app.packageName ?? '',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => setState(() => _selectedApp = app),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// 限额配置
  Widget _buildLimitConfig(BuildContext context, List<AppCategory> categories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 选中的应用
          Card(
            child: ListTile(
              leading: _selectedApp!.icon != null
                  ? Image.memory(_selectedApp!.icon!, width: 48, height: 48)
                  : const Icon(Icons.apps, size: 48),
              title: Text(
                _selectedApp!.name ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_selectedApp!.packageName ?? ''),
            ),
          ),

          const SizedBox(height: 24),

          // 每日限额
          Text(
            '每日限额',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildTimeSlider(
            value: _dailyLimitMinutes,
            onChanged: (v) => setState(() => _dailyLimitMinutes = v),
            label: '每日总时长',
          ),

          const SizedBox(height: 24),

          // 时段限额开关
          Row(
            children: [
              Text(
                '分时段限额',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Switch(
                value: _showPeriodLimits,
                onChanged: (v) => setState(() => _showPeriodLimits = v),
              ),
            ],
          ),

          // 时段限额详情
          if (_showPeriodLimits) ...[
            const SizedBox(height: 12),
            _buildTimeSlider(
              value: _morningLimit,
              onChanged: (v) => setState(() => _morningLimit = v),
              label: '上午 (06:00-12:00)',
            ),
            const SizedBox(height: 8),
            _buildTimeSlider(
              value: _afternoonLimit,
              onChanged: (v) => setState(() => _afternoonLimit = v),
              label: '下午 (12:00-18:00)',
            ),
            const SizedBox(height: 8),
            _buildTimeSlider(
              value: _eveningLimit,
              onChanged: (v) => setState(() => _eveningLimit = v),
              label: '晚上 (18:00-24:00)',
            ),
          ],

          const SizedBox(height: 24),

          // 分类选择
          Text(
            '分类（可选）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map<Widget>((c) {
              final isSelected = _selectedCategoryId == c.id;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(c.iconName),
                      size: 16,
                      color: isSelected ? Colors.white : c.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      c.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                selectedColor: c.color,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategoryId = selected ? c.id : null;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saveLimit,
              child: const Text(
                '保存限额',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 时间滑动选择器
  Widget _buildTimeSlider({
    required double value,
    required ValueChanged<double> onChanged,
    required String label,
  }) {
    final hours = value ~/ 60;
    final minutes = (value % 60).toInt();
    final display = hours > 0
        ? '$hours 小时${minutes > 0 ? " $minutes 分钟" : ""}'
        : '$minutes 分钟';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              display,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 15,
          max: 480,
          divisions: 31, // 每 15 分钟一格
          onChanged: onChanged,
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String iconName) {
    const icons = {
      'chat': Icons.chat_bubble,
      'play_circle': Icons.play_circle,
      'school': Icons.school,
      'shopping_bag': Icons.shopping_bag,
      'build': Icons.build,
      'folder': Icons.folder,
    };
    return icons[iconName] ?? Icons.folder;
  }

  void _saveLimit() {
    if (_selectedApp == null) return;

    // 自动匹配分类
    int? categoryId = _selectedCategoryId;
    if (categoryId == null) {
      final mappedCategoryName =
          AppConstants.packageCategoryMap[_selectedApp!.packageName];
      if (mappedCategoryName != null) {
        final categories = ref.read(categoriesProvider);
        for (final cat in categories) {
          if (cat.name == mappedCategoryName) {
            categoryId = cat.id;
            break;
          }
        }
      }
    }

    final limit = AppLimit(
      packageName: _selectedApp!.packageName ?? '',
      appName: _selectedApp!.name ?? '',
      categoryId: categoryId,
      dailyLimitMinutes: _dailyLimitMinutes.toInt(),
      morningLimitMinutes:
          _showPeriodLimits ? _morningLimit.toInt() : null,
      afternoonLimitMinutes:
          _showPeriodLimits ? _afternoonLimit.toInt() : null,
      eveningLimitMinutes:
          _showPeriodLimits ? _eveningLimit.toInt() : null,
    );

    ref.read(appLimitsProvider.notifier).addLimit(limit);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedApp!.name} 限额已设置'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
