import '../tv/platform/device_presentation.dart';

/// A user override of the presentation reported by the device's OS.
enum AppMode {
  automatic('automatic'),
  television('tv'),
  mobile('mobile');

  const AppMode(this.id);

  final String id;

  static AppMode fromId(String? id) => values.firstWhere(
        (mode) => mode.id == id,
        orElse: () => automatic,
      );

  DevicePresentation resolve(DevicePresentation detected) => switch (this) {
        automatic => detected,
        television => DevicePresentation.television,
        mobile => DevicePresentation.handheld,
      };
}
