import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:driftfin/providers/calendar_provider.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/driftfin_image.dart';
import 'package:driftfin/util/localization_helper.dart';

enum _CalFilter { all, tv, movies }

/// Calendar of upcoming/airing episodes (Sonarr + Jellyfin) and movie releases
/// (Radarr), grouped by day, with an agenda or month-grid view and a type filter.
@RoutePage()
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _monthView = false;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  _CalFilter _filter = _CalFilter.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  Map<DateTime, List<CalendarEntry>> _applyFilter(Map<DateTime, List<CalendarEntry>> byDay) {
    if (_filter == _CalFilter.all) return byDay;
    final out = <DateTime, List<CalendarEntry>>{};
    byDay.forEach((day, list) {
      final filtered = list.where((e) => _filter == _CalFilter.movies ? e.isMovie : !e.isMovie).toList();
      if (filtered.isNotEmpty) out[day] = filtered;
    });
    return out;
  }

  String _dayLabel(BuildContext context, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return context.localized.calendarToday;
    if (diff == 1) return context.localized.calendarTomorrow;
    return DateFormat('EEEE, d MMM').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(calendarProvider);

    return Padding(
      padding: EdgeInsetsDirectional.only(start: AdaptiveLayout.of(context).sideBarWidth),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.localized.calendarTitle),
          actions: [
            PopupMenuButton<_CalFilter>(
              icon: const Icon(Icons.filter_list),
              initialValue: _filter,
              onSelected: (f) => setState(() => _filter = f),
              itemBuilder: (context) => [
                PopupMenuItem(value: _CalFilter.all, child: Text(context.localized.calendarFilterAll)),
                PopupMenuItem(value: _CalFilter.tv, child: Text(context.localized.calendarFilterTv)),
                PopupMenuItem(value: _CalFilter.movies, child: Text(context.localized.calendarFilterMovies)),
              ],
            ),
            IconButton(
              tooltip: _monthView ? 'Agenda' : 'Month',
              icon: Icon(_monthView ? Icons.view_agenda_outlined : Icons.calendar_view_month_outlined),
              onPressed: () => setState(() => _monthView = !_monthView),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            refreshCalendar();
            ref.invalidate(calendarProvider);
            await ref.read(calendarProvider.future);
          },
          child: calendar.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _empty(context),
            data: (raw) {
              final byDay = _applyFilter(raw);
              if (byDay.isEmpty) return _empty(context);
              return _monthView ? _buildMonth(context, byDay) : _buildAgenda(context, byDay);
            },
          ),
        ),
      ),
    );
  }

  /// Centres and width-constrains content so the page doesn't sprawl on wide
  /// desktop windows.
  Widget _constrained({required Widget child}) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: child,
        ),
      );

  Widget _empty(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.event_busy_outlined,
              size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Center(child: Text(context.localized.calendarEmpty)),
        ],
      );

  Widget _buildAgenda(BuildContext context, Map<DateTime, List<CalendarEntry>> byDay) {
    final days = byDay.keys.toList()..sort();
    return _constrained(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final entries = byDay[day]!;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayHeader(label: _dayLabel(context, day), date: day, count: entries.length),
                _EntryGroup(entries: entries),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonth(BuildContext context, Map<DateTime, List<CalendarEntry>> byDay) {
    final theme = Theme.of(context);
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final leadingBlanks = firstOfMonth.weekday - 1; // Monday-first
    final cellCount = leadingBlanks + daysInMonth;
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedEntries = byDay[_selectedDay] ?? const [];

    return _constrained(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () =>
                            setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
                      ),
                      Expanded(
                        child: Text(DateFormat('MMMM yyyy').format(_focusedMonth),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () =>
                            setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                        Expanded(
                          child: Center(
                            child: Text(d,
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, childAspectRatio: 1, mainAxisSpacing: 2, crossAxisSpacing: 2),
                    itemCount: cellCount,
                    itemBuilder: (context, index) {
                      if (index < leadingBlanks) return const SizedBox.shrink();
                      final dayNum = index - leadingBlanks + 1;
                      final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                      final count = byDay[day]?.length ?? 0;
                      final isSelected = DateUtils.isSameDay(day, _selectedDay);
                      final isToday = DateUtils.isSameDay(day, today);
                      final dayColor = isSelected
                          ? theme.colorScheme.onPrimary
                          : isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface;
                      return InkWell(
                        onTap: () => setState(() => _selectedDay = day),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : null,
                            borderRadius: BorderRadius.circular(10),
                            border: isToday && !isSelected
                                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$dayNum',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: dayColor,
                                      fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal)),
                              const SizedBox(height: 3),
                              if (count > 0)
                                Container(
                                  constraints: const BoxConstraints(minWidth: 16),
                                  height: 15,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.25)
                                        : theme.colorScheme.primary.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('$count',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                          height: 1)),
                                )
                              else
                                const SizedBox(height: 15),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DayHeader(label: _dayLabel(context, _selectedDay), date: _selectedDay, count: selectedEntries.length),
          if (selectedEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Text(context.localized.calendarEmpty,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            )
          else
            _EntryGroup(entries: selectedEntries),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Day section header: a leading date badge plus the human label and item count.
class _DayHeader extends StatelessWidget {
  final String label;
  final DateTime date;
  final int count;
  const _DayHeader({required this.label, required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final badgeColor = isToday ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final badgeFg = isToday ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(DateFormat('EEE').format(date).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: badgeFg.withValues(alpha: 0.8), height: 1)),
                Text('${date.day}',
                    style:
                        theme.textTheme.titleLarge?.copyWith(color: badgeFg, fontWeight: FontWeight.bold, height: 1.1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (count > 0)
            Text('$count', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// A rounded surface grouping a day's entries with dividers between them.
class _EntryGroup extends StatelessWidget {
  final List<CalendarEntry> entries;
  const _EntryGroup({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 100, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
            _CalendarTile(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  final CalendarEntry entry;
  const _CalendarTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = entry.hasFile ? Colors.green : theme.colorScheme.primary;
    final statusText = entry.hasFile ? '✓' : DateFormat.jm().format(entry.airDate);
    final subtitle = entry.isMovie
        ? context.localized.calendarFilterMovies
        : [entry.codeLabel, if (entry.episodeTitle.isNotEmpty) entry.episodeTitle]
            .where((s) => s.isNotEmpty)
            .join(' · ');

    final imagePlaceholder = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        entry.isMovie ? Icons.movie_outlined : Icons.live_tv_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return InkWell(
      onTap: entry.item == null ? null : () => entry.item!.navigateTo(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          spacing: 12,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 76,
                height: 48,
                child: DriftfinImage(
                  image: entry.image,
                  placeHolder: imagePlaceholder,
                  imageErrorBuilder: (context, error, stackTrace) => imagePlaceholder,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.seriesTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration:
                  BoxDecoration(color: statusColor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
              child: Text(statusText,
                  style: theme.textTheme.labelMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
