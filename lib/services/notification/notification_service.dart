import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();

  Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _logger.i('Notification permission: ${settings.authorizationStatus}');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpened(initialMessage);
    }
  }

  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    _logger.d('FCM Token: $token');
    return token;
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _logger.i('Foreground message: ${message.notification?.title}');
    _showLocalNotification(
      title: message.notification?.title ?? 'NearKart',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  void _handleNotificationOpened(RemoteMessage message) {
    _logger.i('Notification opened: ${message.data}');
    final type = message.data['type'];
    switch (type) {
      case 'order_update':
      case 'new_order':
      case 'promotion':
        break;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('Local notification tapped: ${response.payload}');
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'nearkart_orders',
      'Order Updates',
      channelDescription: 'Notifications for order status updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  Future<void> notifyVendorNewOrder({
    required String storeName,
    required String orderId,
    required double amount,
  }) async {
    await _showLocalNotification(
      title: 'New Order!',
      body: 'Order #$orderId - ₹${amount.toStringAsFixed(0)} received',
      payload: 'order:$orderId',
    );
  }

  Future<void> notifyCustomerOrderUpdate({
    required String orderId,
    required String status,
    required String storeName,
  }) async {
    final messages = {
      'confirmed': 'Your order from $storeName is confirmed!',
      'preparing': '$storeName is preparing your order',
      'ready': 'Your order from $storeName is ready!',
      'out_for_delivery': 'Your order is on the way!',
      'delivered': 'Order delivered! Enjoy your purchase from $storeName',
    };

    await _showLocalNotification(
      title: 'Order Update',
      body: messages[status] ?? 'Your order status has been updated',
      payload: 'order:$orderId',
    );
  }
}
