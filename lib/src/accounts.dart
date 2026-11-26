import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String? validateUsername(String value) =>
    RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(value.trim())
    ? null
    : 'Use 3–24 letters, numbers or underscores.';
String? validateEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? null
    : 'Enter a valid email address.';
String? validatePassword(String value) =>
    value.length >= 8 ? null : 'Use at least 8 characters.';

abstract class AccountBackend {
  String? get userId;
  String? get provider;
  String? get pendingUsername;
  Stream<AuthChangeEvent> get events;
  Future<String?> readUsername();
  Future<void> writeUsername(String username);
  Future<void> signIn(String email, String password);
  Future<void> signUp(
    String username,
    String email,
    String password,
    String redirect,
  );
  Future<bool> google(String redirect);
  Future<void> resetEmail(String email, String redirect);
  Future<void> updatePassword(String password);
  Future<void> acceptCallback(Uri uri);
}

class SupabaseAccountBackend implements AccountBackend {
  SupabaseAccountBackend(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  String? get provider =>
      client.auth.currentUser?.appMetadata['provider'] as String?;
  @override
  String? get pendingUsername =>
      client.auth.currentUser?.userMetadata?['signup_username'] as String?;
  @override
  Stream<AuthChangeEvent> get events =>
      client.auth.onAuthStateChange.map((e) => e.event);
  @override
  Future<String?> readUsername() async {
    final row = await client
        .from('profiles')
        .select('username')
        .eq('user_id', userId!)
        .maybeSingle();
    return row?['username'] as String?;
  }

  @override
  Future<void> writeUsername(String username) async {
    await client.from('profiles').upsert({
      'user_id': userId!,
      'username': username,
    });
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(
    String username,
    String email,
    String password,
    String redirect,
  ) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {'signup_username': username},
      emailRedirectTo: redirect,
    );
  }

  @override
  Future<bool> google(String redirect) => client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: redirect,
    queryParams: {'prompt': 'select_account'},
  );
  @override
  Future<void> resetEmail(String email, String redirect) =>
      client.auth.resetPasswordForEmail(email, redirectTo: redirect);
  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> acceptCallback(Uri uri) async {
    await client.auth.getSessionFromUrl(uri);
  }
}

class AccountController extends ChangeNotifier {
  AccountController(this.backend) {
    _events = backend?.events.listen(
      (event) {
        if (event == AuthChangeEvent.passwordRecovery) {
          recovery = true;
          dismissed = false;
        }
        if (event == AuthChangeEvent.signedOut) {
          recovery = false;
          username = null;
          dismissed = false;
        }
        // Do not make async Auth calls inside the SDK auth event callback.
        scheduleMicrotask(refreshProfile);
      },
      onError: (Object error) {
        message =
            'This sign-in link could not be used. Please request a new link.';
        dismissed = false;
        _notify();
      },
    );
    if (backend?.userId != null) scheduleMicrotask(refreshProfile);
  }
  final AccountBackend? backend;
  StreamSubscription<AuthChangeEvent>? _events;
  StreamSubscription<Uri>? _links;
  bool recovery = false,
      dismissed = false,
      loading = false,
      profileLoaded = false,
      _disposed = false;
  String? username, message;
  int _generation = 0;
  String? _profileUser;
  String? _lastCallback;
  bool get signedIn => backend?.userId != null;
  bool get needsUsername => signedIn && profileLoaded && username == null;
  bool get needsAttention =>
      !dismissed && (recovery || needsUsername || message != null);
  String get redirect {
    const configured = String.fromEnvironment('AUTH_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return Uri.base.replace(query: '', fragment: '').toString();
    return 'io.synthdex.app://auth-callback/';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void dismiss() {
    dismissed = true;
    message = null;
    _notify();
  }

  void reopen() {
    dismissed = false;
    message = null;
    _notify();
  }

  Future<void> startLinks() async {
    if (backend == null) return;
    try {
      final links = AppLinks();
      _links = links.uriLinkStream.listen(
        handleCallback,
        onError: (Object _) {
          message =
              'Unable to open the account link. Please request a new one.';
          _notify();
        },
      );
      final initial = kIsWeb ? Uri.base : await links.getInitialLink();
      if (initial != null) await handleCallback(initial);
    } catch (_) {
      message = 'Account return links are unavailable on this device. Local tracking still works.';
      _notify();
    }
  }

  Future<void> handleCallback(Uri uri) async {
    final expected = Uri.parse(redirect);
    if (uri.scheme != expected.scheme ||
        uri.host != expected.host ||
        uri.port != expected.port ||
        uri.path != expected.path) {
      return;
    }
    Map<String, String> fragment = {};
    try {
      fragment = Uri.splitQueryString(uri.fragment);
    } catch (_) {
      return;
    }
    final params = {...fragment, ...uri.queryParameters};
    if (!params.containsKey('code') &&
        !params.containsKey('access_token') &&
        !params.containsKey('error_description')) {
      return;
    }
    if (_lastCallback == uri.toString()) return;
    _lastCallback = uri.toString();
    dismissed = false;
    try {
      if (params.containsKey('error_description')) {
        throw const FormatException('Link expired or was cancelled.');
      }
      await backend!.acceptCallback(uri);
      if (params['type'] == 'recovery') recovery = true;
      await refreshProfile();
    } catch (_) {
      message = 'This account link expired, was cancelled, or could not be verified. Request a new link and open it on this device.';
    }
    _notify();
  }

  Future<void> refreshProfile() async {
    final ticket = ++_generation, uid = backend?.userId;
    if (uid != _profileUser) {
      username = null;
      profileLoaded = false;
      _profileUser = uid;
    }
    if (uid == null) {
      profileLoaded = false;
      loading = false;
      _notify();
      return;
    }
    loading = true;
    message = null;
    _notify();
    try {
      var value = await backend!.readUsername();
      if (ticket != _generation || uid != backend!.userId) return;
      // Metadata is only a suggested signup name, never an authorization claim.
      final pending = backend!.pendingUsername;
      if (value == null &&
          backend!.provider == 'email' &&
          pending != null &&
          validateUsername(pending) == null) {
        try {
          await backend!.writeUsername(pending.trim());
          value = pending.trim();
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow;
          message = 'That username was taken. Please choose another.';
        }
      }
      if (ticket != _generation || uid != backend!.userId) return;
      username = value;
      profileLoaded = true;
    } catch (_) {
      if (ticket == _generation) {
        message = 'Could not load your account profile. Retry when connected.';
        profileLoaded = false;
      }
    } finally {
      if (ticket == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  AccountBackend get _api =>
      backend ??
      (throw StateError(
        'Cloud connection is unavailable. Restart the app to reconnect.',
      ));
  Future<void> signIn(String email, String password) async {
    dismissed = false;
    message = null;
    await _api.signIn(email.trim(), password);
    await refreshProfile();
  }

  Future<void> signUp(String name, String email, String password) async {
    if (validateUsername(name) != null ||
        validateEmail(email) != null ||
        validatePassword(password) != null) {
      throw const FormatException('Check your username, email and password.');
    }
    dismissed = false;
    message = null;
    await _api.signUp(name.trim(), email.trim(), password, redirect);
    if (signedIn) await refreshProfile();
  }

  Future<void> google() async {
    dismissed = false;
    message = null;
    if (!await _api.google(redirect)) {
      throw StateError('Could not open Google sign-in. Try again.');
    }
  }

  Future<void> chooseUsername(String name) async {
    if (validateUsername(name) != null) {
      throw const FormatException('Use 3–24 letters, numbers or underscores.');
    }
    if (!signedIn) {
      throw StateError('Sign in before choosing an account username.');
    }
    final uid = backend!.userId;
    try {
      await _api.writeUsername(name.trim());
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const FormatException(
          'That username is already taken. Choose another.',
        );
      }
      rethrow;
    }
    if (uid != backend!.userId) {
      throw StateError('Your account changed. Try again.');
    }
    username = name.trim();
    profileLoaded = true;
    message = null;
    _notify();
  }

  Future<void> sendReset(String email) async {
    if (validateEmail(email) != null) {
      throw const FormatException('Enter a valid email address.');
    }
    await _api.resetEmail(email.trim(), redirect);
  }

  Future<void> resetPassword(String password) async {
    if (!recovery || !signedIn) {
      throw StateError('Open a fresh password recovery link first.');
    }
    if (validatePassword(password) != null) {
      throw const FormatException('Use at least 8 characters.');
    }
    await _api.updatePassword(password);
    recovery = false;
    message = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    _links?.cancel();
    super.dispose();
  }
}
