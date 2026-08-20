import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _webVapidKey =
      'BOtU2_MfVl0hGM23lfJeCUWfdxfU61Dwa45SQZ545atZDdjx7_yYxtL6ebgVfgu9-HHHLUpvxwiEgK3s0l83E2I';

  static const String _channelId = 'le_capase_bookings_high';

  static const String _channelName = 'Nuove prenotazioni';

  static const String _channelDescription =
      'Notifiche importanti per nuove prenotazioni Le Capase';

  static const AndroidNotificationChannel _bookingChannel =
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

  static bool _initialized = false;

  static bool _listenersConfigured = false;

  // =========================================================
  // INIZIALIZZAZIONE GENERALE
  //
  // Sul web non chiede il permesso automaticamente:
  // il consenso deve partire dal tasto "Attiva notifiche".
  // =========================================================

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    try {
      if (!kIsWeb) {
        await _initializeNativeNotifications();
      }

      _configureFirebaseListeners();
    } catch (error) {
      _initialized = false;
      debugPrint('ERRORE INIZIALIZZAZIONE PUSH: $error');
    }
  }

  // =========================================================
  // ATTIVA NOTIFICHE WEB
  //
  // Da chiamare soltanto dopo il clic del responsabile
  // sul pulsante del Gestionale.
  // =========================================================

  static Future<bool> enableWebNotifications() async {
    try {
      await initialize();

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!authorized) {
        return false;
      }

      final token = await _messaging.getToken(vapidKey: _webVapidKey);

      if (token == null || token.trim().isEmpty) {
        return false;
      }

      await _saveToken(token);

      return true;
    } catch (error) {
      debugPrint('ERRORE ATTIVAZIONE PUSH WEB: $error');
      return false;
    }
  }

  // =========================================================
  // STATO PERMESSO NOTIFICHE
  // =========================================================

  static Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();

    return settings.authorizationStatus;
  }

  // =========================================================
  // NOTIFICHE NATIVE ANDROID
  // =========================================================

  static Future<void> _initializeNativeNotifications() async {
    const androidInitializationSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('NOTIFICA LOCALE APERTA: ${response.payload}');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_bookingChannel);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!authorized) {
      return;
    }

    await _saveCurrentToken();
  }

  // =========================================================
  // LISTENER FIREBASE
  // =========================================================

  static void _configureFirebaseListeners() {
    if (_listenersConfigured) {
      return;
    }

    _listenersConfigured = true;

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? 'Nuova prenotazione';

      final body =
          message.notification?.body ?? 'Hai ricevuto una nuova prenotazione.';

      debugPrint('PUSH RICEVUTA: $title - $body');

      if (!kIsWeb) {
        await _showForegroundNotification(
          title: title,
          body: body,
          message: message,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('NOTIFICA APERTA: ${message.messageId}');
    });
  }

  // =========================================================
  // NOTIFICA ANDROID CON APP APERTA
  // =========================================================

  static Future<void> _showForegroundNotification({
    required String title,
    required String body,
    required RemoteMessage message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: message.data['bookingId'],
    );
  }

  // =========================================================
  // TOKEN FCM
  // =========================================================

  static Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();

    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _saveToken(token);
  }

  // =========================================================
  // SALVA TOKEN DELL'AMMINISTRATORE
  // =========================================================

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    await _firestore.collection('admins').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
