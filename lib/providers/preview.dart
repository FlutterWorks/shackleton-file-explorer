import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/preview_settings.dart';

part 'preview.g.dart';

@riverpod
class Preview extends _$Preview {
  @override
  PreviewSettings build() {
    return const PreviewSettings();
  }

  void changeHeight(double delta) {
    if (state.height + delta > 250) {
      state = state.copyWith(height: state.height + delta);
    }
  }
}
