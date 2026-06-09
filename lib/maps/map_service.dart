import 'map_provider.dart';
import 'providers/open_free_map_provider.dart';

/// Singleton that holds the active map provider.
///
/// Call [switchProvider] at runtime (e.g. from a remote-config flag) to
/// hot-swap the underlying SDK without an App Store resubmission — as long as
/// both SDKs are compiled into the same binary.
class MapService {
  MapService._();
  static final MapService instance = MapService._();

  RrawiMapProvider _provider = OpenFreeMapProvider();

  RrawiMapProvider get currentProvider => _provider;

  /// Replace the active provider.
  /// The next call to [currentProvider.buildMap] will use the new one.
  void switchProvider(RrawiMapProvider provider) {
    _provider = provider;
  }
}
