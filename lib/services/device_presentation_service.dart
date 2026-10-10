/// The active presentation, including the user's override, used by deep links
/// and banners.
/// Keep device routing independent of any advertising SDK.
class DevicePresentationService {
  DevicePresentationService._();
  static final instance = DevicePresentationService._();

  bool isTelevision = false;
}
