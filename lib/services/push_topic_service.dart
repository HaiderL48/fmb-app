import 'package:firebase_messaging/firebase_messaging.dart';

class PushTopicService {
  PushTopicService._();

  static final PushTopicService instance = PushTopicService._();
  static const String allUsersTopic = 'all_users';

  Future<void> subscribeAllUsersTopic() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(allUsersTopic);
      // debugPrint('[PushTopic] Subscribed to topic: $allUsersTopic');
    } catch (e) {
      // debugPrint('[PushTopic] Subscribe failed for $allUsersTopic: $e');
    }
  }

  Future<void> unsubscribeAllUsersTopic() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(allUsersTopic);
      // debugPrint('[PushTopic] Unsubscribed from topic: $allUsersTopic');
    } catch (e) {
      // debugPrint('[PushTopic] Unsubscribe failed for $allUsersTopic: $e');
    }
  }
}
