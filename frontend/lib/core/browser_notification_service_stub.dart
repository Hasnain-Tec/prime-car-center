class BrowserNotificationService {
  BrowserNotificationService._();

  static final BrowserNotificationService instance =
      BrowserNotificationService._();

  bool get permissionGranted => false;

  Future<bool> requestPermission() async {
    return false;
  }

  Future<void> show({
    required String title,
    required String body,
    required String tag,
  }) async {}
}
