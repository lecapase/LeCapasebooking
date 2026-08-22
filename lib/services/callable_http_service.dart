import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CallableHttpException implements Exception {
  const CallableHttpException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}

class CallableHttpService {
  CallableHttpService._();

  static const String _projectId = 'lecapase-booking-3af33';

  static const String _region = 'europe-west1';

  static Future<Map<String, dynamic>> call(
    String functionName, [
    Map<String, dynamic> data = const {},
  ]) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId'
      '.cloudfunctions.net/$functionName',
    );

    final headers = <String, String>{'Content-Type': 'application/json'};

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final token = await user.getIdToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(<String, dynamic>{'data': data}),
    );

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw CallableHttpException(
        code: 'invalid-response',
        message: 'Risposta non valida dal server.',
      );
    }

    if (decoded is! Map) {
      throw CallableHttpException(
        code: 'invalid-response',
        message: 'Risposta non valida dal server.',
      );
    }

    final error = decoded['error'];

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error is Map) {
      final message = error is Map
          ? (error['message'] ?? 'Operazione non riuscita.').toString()
          : 'Operazione non riuscita.';

      final code = error is Map
          ? (error['status'] ?? response.statusCode).toString()
          : response.statusCode.toString();

      throw CallableHttpException(code: code, message: message);
    }

    final result = decoded['result'];

    if (result == null) {
      return <String, dynamic>{};
    }

    if (result is! Map) {
      throw CallableHttpException(
        code: 'invalid-result',
        message: 'Dati ricevuti non validi.',
      );
    }

    return Map<String, dynamic>.from(result);
  }
}
