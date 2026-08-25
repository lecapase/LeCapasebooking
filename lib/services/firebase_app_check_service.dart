import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const String _webRecaptchaEnterpriseSiteKey =
    '6LehipgtAAAAAB0I4iu-utYnTbnymP18BV9tXbHX';

Future<void> initializeFirebaseAppCheck() async {
  if (!kIsWeb) {
    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaEnterpriseProvider(_webRecaptchaEnterpriseSiteKey),
  );
}
