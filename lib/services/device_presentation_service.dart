/// The presentation detected at startup, also used by deep links and banners.
/// Keep device routing independent of any advertising SDK.
class DevicePresentationService {
  DevicePresentationService._();
  static final instance = DevicePresentationService._();

  bool isTelevision = false;
}
