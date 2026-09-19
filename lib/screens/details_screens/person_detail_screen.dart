import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/providers/items/person_details_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/seerr/widgets/seerr_poster_row.dart';
import 'package:driftfin/screens/shared/detail_scaffold.dart';
import 'package:driftfin/screens/shared/media/external_urls.dart';
import 'package:driftfin/screens/shared/media/poster_row.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/driftfin_image.dart';
import 'package:driftfin/util/list_extensions.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/string_extensions.dart';
import 'package:driftfin/util/widget_extensions.dart';
import 'package:driftfin/widgets/shared/selectable_icon_button.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final Person person;
  const PersonDetailScreen({required this.person, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  late final providerID = personDetailsProvider(widget.person.id);

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(providerID);
    return DetailScaffold(
      label: details?.name ?? "",
      onRefresh: () async {
        await ref.read(providerID.notifier).fetchPerson(widget.person);
      },
      backDrops: [...?details?.movies, ...?details?.series].random().firstOrNull?.images,
      content: (context, padding) => Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height / 6),
          Padding(
            padding: padding,
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.spaceEvenly,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 32,
              spacing: 32,
              children: [
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  width: AdaptiveLayout.viewSizeOf(context) == ViewSize.phone
                      ? MediaQuery.of(context).size.width
                      : MediaQuery.of(context).size.width / 3.5,
                  child: AspectRatio(
                    aspectRatio: 0.70,
                    child: DriftfinImage(
                      fit: BoxFit.cover,
                      placeHolder: placeHolder(details?.name ?? ""),
                      image: details?.images?.primary,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(details?.name ?? "", style: Theme.of(context).textTheme.displaySmall)),
                          const SizedBox(width: 15),
                          SelectableIconButton(
                            onPressed: () async => await ref
                                .read(userProvider.notifier)
                                .setAsFavorite(!(details?.userData.isFavourite ?? false), details?.id ?? ""),
                            selected: (details?.userData.isFavourite ?? false),
                            selectedIcon: Icons.favorite_rounded,
                            icon: Icons.favorite_border_rounded,
                          ),
                        ],
                      ),
                    ),
                    if (details?.dateOfBirth != null)
                      Text(context.localized.personBirthday(
                          DateFormat.yMEd(context.localized.localeName).format(details!.dateOfBirth!).toString())),
                    if (details?.age != null) Text(context.localized.personAge(details!.age!)),
                    if (details?.birthPlace.isEmpty == false)
                      Text(context.localized.personBirthPlace(details!.birthPlace.join(", "))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (details?.movies.isNotEmpty ?? false)
            PosterRow(
              contentPadding: padding,
              posters: details?.movies ?? [],
              label: context.localized.mediaTypeMovie(details?.movies.length ?? 2),
            ),
          if (details?.series.isNotEmpty ?? false)
            PosterRow(
              contentPadding: padding,
              posters: details?.series ?? [],
              label: context.localized.mediaTypeSeries(details?.series.length ?? 2),
            ),
          if (details?.seerrMovies.isNotEmpty ?? false)
            SeerrPosterRow(
              contentPadding: padding,
              posters: details?.seerrMovies ?? [],
              label: context.localized.seerrMovies,
            ),
          if (details?.seerrSeries.isNotEmpty ?? false)
            SeerrPosterRow(
              contentPadding: padding,
              posters: details?.seerrSeries ?? [],
              label: context.localized.seerrSeries,
            ),
          if (details?.overview.externalUrls?.isNotEmpty ?? false)
            ExternalUrlsRow(
              urls: details?.overview.externalUrls,
            ).padding(padding),
        ],
      ),
    );
  }

  Widget placeHolder(String name) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: FractionallySizedBox(
        widthFactor: 0.4,
        child: Card(
          shape: const CircleBorder(),
          child: Center(
              child: Text(
            name.getInitials(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          )),
        ),
      ),
    );
  }
}
