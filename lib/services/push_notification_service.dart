import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final FlutterLocalNotificationsPlugin
      _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId =
      'le_capase_bookings_high';

  static const String _channelName =
      'Nuove prenotazioni';

  static const String _channelDescription =
      'Notifiche importanti per nuove prenotazioni Le Capase';

  static const AndroidNotificationChannel
      _bookingChannel =
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

  // =========================================================
  // INIZIALIZZAZIONE
  // =========================================================

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      return;
    }

    _initialized = true;

    try {
      // =====================================================
      // 1. INIZIALIZZA NOTIFICHE LOCALI
      // =====================================================

      const androidInitializationSettings =
          AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const initializationSettings =
          InitializationSettings(
        android: androidInitializationSettings,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) {
          debugPrint(
            'NOTIFICA LOCALE APERTA: ${response.payload}',
          );
        },
      );

      // =====================================================
      // 2. CREA CANALE ANDROID
      // =====================================================

      final androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin
          ?.createNotificationChannel(
        _bookingChannel,
      );

      // =====================================================
      // 3. PERMESSO NOTIFICHE
      // =====================================================

      final settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus ==
              AuthorizationStatus.denied ||
          settings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        return;
      }

      // =====================================================
      // 4. TOKEN FCM
      // =====================================================

      await _saveCurrentToken();

      // =====================================================
      // 5. TOKEN RINNOVATO
      // =====================================================

      _messaging.onTokenRefresh.listen(
        (token) async {
          await _saveToken(
            token,
          );
        },
      );

      // =====================================================
      // 6. NOTIFICA CON APP APERTA
      // =====================================================

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          final title =
              message.notification?.title ??
                  'Nuova prenotazione';

          final body =
              message.notification?.body ??
                  'Hai ricevuto una nuova prenotazione.';

          debugPrint(
            'PUSH RICEVUTA: $title - $body',
          );

          await _showForegroundNotification(
            title: title,
            body: body,
            message: message,
          );
        },
      );

      // =====================================================
      // 7. TAP NOTIFICA DA BACKGROUND
      // =====================================================

      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          debugPrint(
            'NOTIFICA APERTA: ${message.messageId}',
          );
        },
      );

      // =====================================================
      // 8. APP APERTA DA NOTIFICA
      // =====================================================

      final initialMessage =
          await _messaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint(
          'APP APERTA DA PUSH: '
          '${initialMessage.messageId}',
        );
      }
    } catch (error) {
      _initialized = false;

      debugPrint(
        'ERRORE INIZIALIZZAZIONE PUSH: $error',
      );

      rethrow;
    }
  }

  // =========================================================
  // MOSTRA NOTIFICA IN FOREGROUND
  // =========================================================

  static Future<void>
      _showForegroundNotification({
    required String title,
    required String body,
    required RemoteMessage message,
  }) async {
    const androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription:
          _channelDescription,
      importance:
          Importance.max,
      priority:
          Priority.high,
      playSound:
          true,
      enableVibration:
          true,
      visibility:
          NotificationVisibility.public,
    );

    const notificationDetails =
        NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .remainder(100000),
      title: title,
      body: body,
      notificationDetails:
          notificationDetails,
      payload:
          message.data['bookingId'],
    );
  }

  // =========================================================
  // TOKEN FCM
  // =========================================================

  static Future<void>
      _saveCurrentToken() async {
    final token =
        await _messaging.getToken();

    if (token == null ||
        token.trim().isEmpty) {
      return;
    }

    await _saveToken(
      token,
    );
  }

  // =========================================================
  // SALVA TOKEN NELL'ADMIN
  // =========================================================

  static Future<void> _saveToken(
    String token,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    await _firestore
        .collection('admins')
        .doc(user.uid)
        .set(
      {
        'fcmTokens':
            FieldValue.arrayUnion(
          [
            token,
          ],
        ),
        'lastTokenUpdate':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }
}