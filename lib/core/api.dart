import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;

import '../app/config.dart';

// Erreur de l'API : message en français prêt à afficher, comme ApiError du site
class ApiException implements Exception {
  ApiException(this.status, this.message, [this.fields = const []]);
  final int status;
  final String message;
  final List<Map<String, dynamic>> fields; // erreurs par champ : [{ field, message }]

  @override
  String toString() => message;
}

// Appels à l'API Kin Factures (mêmes routes et mêmes champs snake_case que le site).
// Connexion par jeton : « Authorization: Bearer … », jeton gardé dans le coffre chiffré du téléphone.
class Api extends GetxService {
  static Api get to => Get.find();

  static const _tokenKey = 'kf_session_token';
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;
  String? _token;

  // Appelé quand l'API répond 401 (session expirée ou fermée ailleurs)
  void Function()? onUnauthorized;

  Future<Api> init() async {
    _token = await _storage.read(key: _tokenKey);
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      // Les erreurs sont traitées ci-dessous (message de l'API)
      validateStatus: (_) => true,
    ));
    return this;
  }

  bool get hasToken => _token != null;

  Future<void> saveToken(String? token) async {
    _token = token;
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _request('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _request('POST', path, body: body ?? {});
  Future<dynamic> patch(String path, Object body) => _request('PATCH', path, body: body);
  Future<dynamic> put(String path, Object body) => _request('PUT', path, body: body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  // Réponse brute (connexion : jeton dans l'en-tête set-auth-token)
  Future<Response<dynamic>> raw(String method, String path, {Object? body}) => _send(method, path, body: body);

  Future<dynamic> _request(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    final response = await _send(method, path, body: body, query: query);
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return response.data;

    if (status == 401 && _token != null) onUnauthorized?.call();
    throw errorOf(response);
  }

  Future<Response<dynamic>> _send(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      return await _dio.request(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {if (_token != null) 'Authorization': 'Bearer $_token'},
          contentType: body == null ? null : Headers.jsonContentType,
        ),
      );
    } on DioException {
      throw ApiException(0, 'Connexion au serveur impossible. Vérifiez votre connexion internet.');
    }
  }

  // API Kin Factures : { error, fields } ; Better Auth (connexion) : { message, code }
  static ApiException errorOf(Response<dynamic> response) {
    final data = response.data;
    String? message;
    var fields = const <Map<String, dynamic>>[];
    if (data is Map) {
      message = (data['error'] ?? data['message']) as String?;
      if (data['fields'] is List) fields = (data['fields'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return ApiException(response.statusCode ?? 0, message ?? 'Une erreur inattendue est survenue. Réessayez.', fields);
  }
}
