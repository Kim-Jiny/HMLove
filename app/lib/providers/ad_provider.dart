import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';

final adProvider = NotifierProvider<AdNotifier, bool>(AdNotifier.new);

class AdNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box(AppConstants.settingsBox);
    return box.get(AppConstants.adsRemovedKey, defaultValue: false) as bool;
  }

  Future<void> removeAds() async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.adsRemovedKey, true);
    state = true;
  }

  Future<void> restoreAds() async {
    final box = Hive.box(AppConstants.settingsBox);
    await box.put(AppConstants.adsRemovedKey, false);
    state = false;
  }
}
