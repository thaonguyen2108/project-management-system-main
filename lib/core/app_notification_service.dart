import 'dart:async';
import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/models/notification.dart';
import 'package:todo/services/notificationService.dart';

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  static const String channelId = 'todo_high_importance_channel';
  static const String channelName = 'Thông báo quan trọng';
  static const String channelDescription =
      'Thông báo công việc, dự án, tin nhắn và bạn bè';
  static const String _androidPackageName = 'com.example.todo';
  static const int _maxStoredShownIds = 200;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();
  final ValueNotifier<int> openNotificationsTabSignal = ValueNotifier<int>(0);

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  String? _currentUid;
  bool _isInitialized = false;
  bool _hasNotificationBaseline = false;
  bool _pendingOpenNotificationsTab = false;
  Set<String> _shownLocalNotificationIds = <String>{};

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _initLocalNotifications();
    await _createAndroidNotificationChannel();
    await _handleLaunchDetails();
    _listenToFirebaseMessaging();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => _handleAuthUser(user),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[AppNotification] auth listener error: $error\n$stackTrace',
        );
      },
    );

    await _handleAuthUser(FirebaseAuth.instance.currentUser);
    debugPrint('[AppNotification] initialized');
  }

  Future<bool> configureCurrentUserDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[AppNotification] configure skipped: no current user');
      return false;
    }

    final permissionGranted = await requestNotificationPermission();
    await saveCurrentFcmToken(user.uid);
    return permissionGranted;
  }

  Future<bool> requestNotificationPermission() async {
    bool granted = false;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      debugPrint(
        '[AppNotification] FCM permission status='
        '${settings.authorizationStatus.name}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[AppNotification] FCM requestPermission failed: '
        '$error\n$stackTrace',
      );
    }

    try {
      final androidGranted = await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      if (androidGranted == true) granted = true;
      debugPrint(
        '[AppNotification] Android notification permission=$androidGranted',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[AppNotification] Android requestNotificationsPermission failed: '
        '$error\n$stackTrace',
      );
    }

    return granted;
  }

  Future<void> saveCurrentFcmToken(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[AppNotification] FCM token is empty');
        return;
      }

      await _saveFcmToken(normalizedUid, token.trim());
    } catch (error, stackTrace) {
      debugPrint(
        '[AppNotification] get/save FCM token failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('[AppNotification] battery settings skipped: not Android');
      return;
    }

    final intents = [
      const AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_androidPackageName',
      ),
      const AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      ),
      const AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$_androidPackageName',
      ),
    ];

    for (final intent in intents) {
      try {
        await intent.launch();
        debugPrint('[AppNotification] opened battery/settings intent');
        return;
      } catch (error, stackTrace) {
        debugPrint(
          '[AppNotification] battery/settings intent failed: '
          '$error\n$stackTrace',
        );
      }
    }
  }

  bool consumeOpenNotificationsTabRequest() {
    final pending = _pendingOpenNotificationsTab;
    _pendingOpenNotificationsTab = false;
    return pending;
  }

  void requestOpenNotificationsTab() {
    _pendingOpenNotificationsTab = true;
    openNotificationsTabSignal.value++;
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _notificationSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload, source: 'local');
      },
    );
  }

  Future<void> _createAndroidNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      debugPrint('[AppNotification] Android notification channel ready');
    } catch (error, stackTrace) {
      debugPrint(
        '[AppNotification] create notification channel failed: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _handleLaunchDetails() async {
    try {
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _handleNotificationTap(
          launchDetails?.notificationResponse?.payload,
          source: 'local_launch',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[AppNotification] read local launch details failed: '
        '$error\n$stackTrace',
      );
    }
  }

  void _listenToFirebaseMessaging() {
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _handleForegroundFcmMessage(message),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[AppNotification] FCM onMessage error: $error\n$stackTrace',
        );
      },
    );

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        debugPrint(
          '[AppNotification] FCM opened app messageId=${message.messageId}',
        );
        requestOpenNotificationsTab();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[AppNotification] FCM onMessageOpenedApp error: '
          '$error\n$stackTrace',
        );
      },
    );

    _messaging
        .getInitialMessage()
        .then((message) {
          if (message == null) return;
          debugPrint(
            '[AppNotification] FCM initial messageId=${message.messageId}',
          );
          requestOpenNotificationsTab();
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            '[AppNotification] getInitialMessage failed: $error\n$stackTrace',
          );
        });
  }

  Future<void> _handleAuthUser(User? user) async {
    final uid = user?.uid.trim();
    if (uid == null || uid.isEmpty) {
      await _stopUserListener();
      return;
    }

    if (_currentUid == uid && _notificationSubscription != null) {
      await saveCurrentFcmToken(uid);
      return;
    }

    await _stopUserListener();
    _currentUid = uid;
    _hasNotificationBaseline = false;
    _shownLocalNotificationIds = await _loadShownLocalNotificationIds(uid);

    _notificationSubscription = _notificationService
        .streamNotifications(uid)
        .listen(
          (notifications) => _handleFirestoreNotifications(uid, notifications),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              '[AppNotification] notification stream error uid=$uid: '
              '$error\n$stackTrace',
            );
          },
        );

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => _saveFcmToken(uid, token),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[AppNotification] token refresh error: $error\n$stackTrace',
        );
      },
    );

    await saveCurrentFcmToken(uid);
    debugPrint('[AppNotification] started listener uid=$uid');
  }

  Future<void> _stopUserListener() async {
    if (_currentUid != null) {
      debugPrint('[AppNotification] stopped listener uid=$_currentUid');
    }
    _currentUid = null;
    _hasNotificationBaseline = false;
    _shownLocalNotificationIds = <String>{};
    await _notificationSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _notificationSubscription = null;
    _tokenRefreshSubscription = null;
  }

  Future<void> _handleFirestoreNotifications(
    String uid,
    List<NotificationModel> notifications,
  ) async {
    final validNotifications = notifications
        .where((item) => item.id.trim().isNotEmpty)
        .toList();

    if (!_hasNotificationBaseline) {
      _hasNotificationBaseline = true;
      for (final notification in validNotifications) {
        _shownLocalNotificationIds.add(notification.id);
      }
      await _persistShownLocalNotificationIds(uid);
      debugPrint(
        '[AppNotification] baseline set uid=$uid '
        'count=${validNotifications.length}',
      );
      return;
    }

    for (final notification in validNotifications.reversed) {
      final id = notification.id.trim();
      if (notification.isRead ||
          notification.isDeleted ||
          _shownLocalNotificationIds.contains(id)) {
        continue;
      }

      await _showPersistentNotification(notification);
      _shownLocalNotificationIds.add(id);
      await _persistShownLocalNotificationIds(uid);
    }
  }

  Future<void> _showPersistentNotification(
    NotificationModel notification,
  ) async {
    final payload = jsonEncode({
      'notificationId': notification.id,
      'type': notification.type,
      'targetType': notification.targetType,
      'targetId': notification.targetId,
      'projectId': notification.projectId,
      'taskId': notification.taskId,
      'conversationId': notification.targetType == 'conversation'
          ? notification.targetId
          : null,
    });

    await _showLocalNotification(
      idSeed: notification.id,
      title: notification.title.trim().isEmpty
          ? 'Thông báo mới'
          : notification.title.trim(),
      body: notification.body.trim().isEmpty
          ? 'Bạn có một thông báo mới trong ứng dụng.'
          : notification.body.trim(),
      payload: payload,
    );
  }

  Future<void> _handleForegroundFcmMessage(RemoteMessage message) async {
    debugPrint(
      '[AppNotification] foreground FCM messageId=${message.messageId}',
    );
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    await _showLocalNotification(
      idSeed:
          message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'Thông báo mới',
      body: body?.trim().isNotEmpty == true
          ? body!.trim()
          : 'Bạn có một thông báo mới trong ứng dụng.',
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _showLocalNotification({
    required String idSeed,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _localNotifications.show(
        id: _positiveNotificationId(idSeed),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
      debugPrint('[AppNotification] local notification shown idSeed=$idSeed');
    } catch (error, stackTrace) {
      debugPrint(
        '[AppNotification] show local notification failed: '
        '$error\n$stackTrace',
      );
    }
  }

  void _handleNotificationTap(String? payload, {required String source}) {
    debugPrint(
      '[AppNotification] notification tapped source=$source '
      'hasPayload=${payload != null && payload.isNotEmpty}',
    );
    requestOpenNotificationsTab();
  }

  Future<void> _saveFcmToken(String uid, String token) async {
    final normalizedToken = token.trim();
    if (uid.trim().isEmpty || normalizedToken.isEmpty) return;

    final tokenDocId = _tokenDocId(normalizedToken);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid.trim())
        .collection('fcmTokens')
        .doc(tokenDocId)
        .set({
          'token': normalizedToken,
          'platform': _platformLabel,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    debugPrint(
      '[AppNotification] FCM token saved uid=$uid '
      'length=${normalizedToken.length} token=${_redactedToken(normalizedToken)}',
    );
  }

  Future<Set<String>> _loadShownLocalNotificationIds(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_shownIdsKey(uid)) ?? <String>[]).toSet();
  }

  Future<void> _persistShownLocalNotificationIds(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final values = _shownLocalNotificationIds.toList();
    final trimmed = values.length > _maxStoredShownIds
        ? values.sublist(values.length - _maxStoredShownIds)
        : values;
    await prefs.setStringList(_shownIdsKey(uid), trimmed);
  }

  String _shownIdsKey(String uid) => 'shown_local_notifications_$uid';

  String _tokenDocId(String token) {
    return base64Url.encode(utf8.encode(token)).replaceAll('=', '');
  }

  int _positiveNotificationId(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _redactedToken(String token) {
    if (token.length <= 12) return '<redacted:${token.length}>';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }
}
