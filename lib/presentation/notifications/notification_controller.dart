import 'package:flixquest/data/sources/push_messaging_client.dart';
import 'device_registration_controller.dart';
import 'in_app_message_controller.dart';

class NotificationController {
  const NotificationController(this.devices, this.messages, this.messaging);
  final DeviceRegistrationController devices;
  final InAppMessageController messages;
  final PushMessagingClient messaging;
  Future<void> boot() async => Future.wait([devices.boot(), messages.boot()]);
  Future<void> onResume() async =>
      Future.wait([devices.onResume(), messages.onResume()]);
  void dispose() {
    devices.dispose();
    messages.dispose();
  }
}
