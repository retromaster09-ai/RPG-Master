import 'package:supabase_flutter/supabase_flutter.dart';

class AccountService {
  const AccountService(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    final response = await _client.functions.invoke(
      'rpg-account',
      body: {'action': action, ...data},
    );
    final result = Map<String, dynamic>.from(response.data as Map);
    if (result['error'] != null) {
      throw AccountException(result['error'].toString());
    }
    return result;
  }

  Future<void> signIn(String username, String password) async {
    final result = await call('login', {
      'username': username,
      'password': password,
    });
    await _client.auth.setSession(
      result['refresh_token'] as String,
      accessToken: result['access_token'] as String,
    );
  }

  Future<void> register(String username, String password) async {
    await call('register', {'username': username, 'password': password});
  }
}

class AccountException implements Exception {
  const AccountException(this.code);
  final String code;
}

String accountMessage(Object error, String fallback) {
  final details = error is FunctionException ? error.details : null;
  final code = error is AccountException
      ? error.code
      : details is Map
      ? details['error']
      : null;
  return switch (code) {
    'invalid_credentials' => 'Confira o nome de usuário e a senha.',
    'invalid_code' => 'Código inválido, expirado ou já usado.',
    'invalid_password' => 'Use uma senha de pelo menos 8 caracteres.',
    'invalid_username' =>
      'Use de 3 a 24 letras sem acento, números, ponto, hífen ou sublinhado.',
    'registration_limited' =>
      'Muitas tentativas de cadastro. Tente de novo em 15 minutos.',
    'reset_failed' => 'A senha não pôde ser alterada. Solicite um novo código.',
    'username_taken' => 'Esse nome de usuário já está em uso.',
    'invalid_request' => 'Confira os campos e tente de novo.',
    'not_authorized' => 'Esta operação não está disponível para sua conta.',
    _ => fallback,
  };
}

bool isUsername(String? value) =>
    value != null &&
    RegExp(r'^[a-z0-9][a-z0-9_.-]{2,23}$').hasMatch(value.trim().toLowerCase());
