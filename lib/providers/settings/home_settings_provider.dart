import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:driftfin/models/settings/home_settings_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';

final homeSettingsProvider = StateNotifierProvider<HomeSettingsNotifier, HomeSettingsModel>((ref) {
  return HomeSettingsNotifier(ref);
});

class HomeSettingsNotifier extends StateNotifier<HomeSettingsModel> {
  HomeSettingsNotifier(this.ref) : super(HomeSettingsModel.defaultModel());

  final Ref ref;

  @override
  set state(HomeSettingsModel value) {
    super.state = value;
    ref.read(sharedUtilityProvider).homeSettings = value;
  }

  HomeSettingsModel update(HomeSettingsModel Function(HomeSettingsModel currentState) value) => state = value(state);

  void setLayoutModes(Set<LayoutMode> set) => state = state.copyWith(screenLayouts: set);

  void setViewSize(Set<ViewSize> set) => state = state.copyWith(layoutStates: set);

  /// Pins/unpins a collection (boxset) so it renders as a row on the dashboard.
  void toggleHomeCollection(String collectionId) {
    final pinned = [...state.pinnedCollectionIds];
    if (pinned.contains(collectionId)) {
      pinned.remove(collectionId);
    } else {
      pinned.add(collectionId);
    }
    state = state.copyWith(pinnedCollectionIds: pinned);
  }

  /// Replaces the pinned-collection list (used to reorder/remove from the
  /// manage screen). Order is preserved on the dashboard.
  void setPinnedCollections(List<String> collectionIds) => state = state.copyWith(pinnedCollectionIds: collectionIds);
}
