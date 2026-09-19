import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/providers/tonight_provider.dart';
import 'package:driftfin/screens/shared/media/poster_list_item.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/tonight_picker.dart';

const List<Duration?> _timeBudgets = [null, Duration(minutes: 30), Duration(minutes: 60), Duration(minutes: 120)];

@RoutePage()
class TonightScreen extends ConsumerStatefulWidget {
  const TonightScreen({super.key});

  @override
  ConsumerState<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends ConsumerState<TonightScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tonightProvider.notifier).fetchTonightPicks();
    });
  }

  String _timeBudgetLabel(Duration? duration) {
    if (duration == null) return context.localized.tonightAnyLength;
    return context.localized.tonightMinutesOrLess(duration.inMinutes);
  }

  String _moodLabel(TonightMood mood) => switch (mood) {
    TonightMood.any => context.localized.tonightMoodAny,
    TonightMood.cozy => context.localized.tonightMoodCozy,
    TonightMood.thrilling => context.localized.tonightMoodThrilling,
    TonightMood.funny => context.localized.tonightMoodFunny,
    TonightMood.uplifting => context.localized.tonightMoodUplifting,
  };

  @override
  Widget build(BuildContext context) {
    final tonight = ref.watch(tonightProvider);
    final notifier = ref.read(tonightProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AdaptiveLayout.adaptivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 4),
                  Expanded(child: Text(context.localized.tonight, style: Theme.of(context).textTheme.headlineSmall)),
                  IconButton(
                    tooltip: context.localized.refresh,
                    icon: const Icon(IconsaxPlusLinear.refresh),
                    onPressed: tonight.loading
                        ? null
                        : () => notifier.fetchTonightPicks(timeAvailable: tonight.timeAvailable, mood: tonight.mood),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _timeBudgets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final duration = _timeBudgets[index];
                    return ChoiceChip(
                      label: Text(_timeBudgetLabel(duration)),
                      selected: tonight.timeAvailable == duration,
                      onSelected: (_) => notifier.fetchTonightPicks(timeAvailable: duration, mood: tonight.mood),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: TonightMood.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final mood = TonightMood.values[index];
                    return ChoiceChip(
                      label: Text(_moodLabel(mood)),
                      selected: tonight.mood == mood,
                      onSelected: (_) => notifier.fetchTonightPicks(timeAvailable: tonight.timeAvailable, mood: mood),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: tonight.loading
                    ? const Center(child: CircularProgressIndicator())
                    : !tonight.hasPicks
                    ? Center(child: Text(context.localized.tonightEmpty))
                    : ListView.builder(
                        itemCount: tonight.picks.length,
                        itemBuilder: (context, index) => PosterListItem(poster: tonight.picks[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
