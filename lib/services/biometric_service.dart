import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth =
      LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final bool canCheckBiometrics =
          await _auth.canCheckBiometrics;

      final bool deviceSupported =
          await _auth.isDeviceSupported();

      if (!canCheckBiometrics ||
          !deviceSupported) {
        return false;
      }

      final List<BiometricType> biometrics =
          await _auth.getAvailableBiometrics();

      return biometrics.isNotEmpty;
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BiometricType>>
      getAvailableBiometrics() async {
    if (kIsWeb) {
      return <BiometricType>[];
    }

    try {
      return await _auth.getAvailableBiometrics();
    } on LocalAuthException {
      return <BiometricType>[];
    } catch (_) {
      return <BiometricType>[];
    }
  }

  static Future<bool> hasFaceId() async {
    final List<BiometricType> biometrics =
        await getAvailableBiometrics();

    return biometrics.contains(
      BiometricType.face,
    );
  }

  static Future<bool> hasFingerprint() async {
    final List<BiometricType> biometrics =
        await getAvailableBiometrics();

    return biometrics.contains(
          BiometricType.fingerprint,
        ) ||
        biometrics.contains(
          BiometricType.strong,
        );
  }

  static Future<String> biometricName() async {
    if (kIsWeb) {
      return 'Biometria non disponibile sul Web';
    }

    final List<BiometricType> biometrics =
        await getAvailableBiometrics();

    if (biometrics.contains(
      BiometricType.face,
    )) {
      return 'Face ID';
    }

    if (biometrics.contains(
      BiometricType.fingerprint,
    )) {
      return 'Impronta digitale';
    }

    if (biometrics.contains(
          BiometricType.strong,
        ) ||
        biometrics.contains(
          BiometricType.weak,
        )) {
      return 'Biometria';
    }

    return 'Biometria non disponibile';
  }

  static Future<bool> authenticate() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final bool available =
          await isAvailable();

      if (!available) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason:
            'Autenticati per accedere a Le Capase Booking',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopAuthentication() async {
    if (kIsWeb) {
      return;
    }

    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
