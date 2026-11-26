import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synthdex/src/accounts.dart';
import 'package:synthdex/src/account_panel.dart';

class FakeAccountBackend implements AccountBackend {
  final changes = StreamController<AuthChangeEvent>.broadcast();
  @override
  String? userId;
  @override
  String? provider;
  @override
  String? pendingUsername;
  String? savedUsername, resetAddress, updatedPassword, googleRedirect;
  List<String>? signupFields;
  bool duplicate = false, failProfile = false;
  int callbackCount = 0;
  @override
  Stream<AuthChangeEvent> get events => changes.stream;
  @override
  Future<String?> readUsername() async {
    if (failProfile) throw StateError('offline');
    return savedUsername;
  }

  @override
  Future<void> writeUsername(String username) async {
    if (duplicate) {
      throw const PostgrestException(message: 'duplicate', code: '23505');
    }
    savedUsername = username;
  }

  @override
  Future<void> signIn(String email, String password) async {
    userId = 'user';
    provider = 'email';
  }

  @override
  Future<void> signUp(
    String username,
    String email,
    String password,
    String redirect,
  ) async {
    signupFields = [username, email, password];
    pendingUsername = username;
  }

  @override
  Future<bool> google(String redirect) async {
    googleRedirect = redirect;
    return true;
  }

  @override
  Future<void> resetEmail(String email, String redirect) async {
    resetAddress = email;
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
  }

  @override
  Future<void> acceptCallback(Uri uri) async {
    callbackCount++;
    userId = 'user';
    changes.add(AuthChangeEvent.passwordRecovery);
  }
}

void main() {
  test('email registration uses only username email and password', () async {
    final backend = FakeAccountBackend(), accounts = AccountController(null);
    accounts.dispose();
    final controller = AccountController(backend);
    await controller.signUp('Player_1', 'player@example.com', 'password123');
    expect(backend.signupFields, [
      'Player_1',
      'player@example.com',
      'password123',
    ]);
    expect(controller.signedIn, isFalse); // Confirmation required.
    await controller.signIn('player@example.com', 'password123');
    expect(controller.username, 'Player_1');
    expect(controller.needsUsername, isFalse);
    controller.dispose();
    await backend.changes.close();
  });
  test(
    'new Google account requests username only; returning user keeps it',
    () async {
      final backend = FakeAccountBackend();
      final controller = AccountController(backend);
      await controller.google();
      expect(backend.googleRedirect, 'io.synthdex.app://auth-callback/');
      backend.userId = 'google-user';
      backend.provider = 'google';
      backend.pendingUsername = 'DoNotCopyGoogleName';
      await controller.refreshProfile();
      expect(controller.needsUsername, isTrue);
      expect(backend.savedUsername, isNull);
      await controller.chooseUsername('RhythmPlayer');
      await controller.refreshProfile();
      expect(controller.username, 'RhythmPlayer');
      expect(controller.needsUsername, isFalse);
      controller.dispose();
      await backend.changes.close();
    },
  );
  test('taken username leaves onboarding recoverable', () async {
    final backend = FakeAccountBackend()
      ..userId = 'user'
      ..provider = 'google'
      ..duplicate = true;
    final controller = AccountController(backend);
    await controller.refreshProfile();
    await expectLater(
      controller.chooseUsername('Player'),
      throwsFormatException,
    );
    expect(controller.needsUsername, isTrue);
    backend.duplicate = false;
    await controller.chooseUsername('Player2');
    expect(controller.username, 'Player2');
    controller.dispose();
    await backend.changes.close();
  });
  test('forgot password and cold callback enter verified recovery', () async {
    final backend = FakeAccountBackend(), controller = AccountController(null);
    controller.dispose();
    final accounts = AccountController(backend);
    await accounts.sendReset('player@example.com');
    expect(backend.resetAddress, 'player@example.com');
    await expectLater(accounts.resetPassword('password123'), throwsStateError);
    final uri = Uri.parse('io.synthdex.app://auth-callback/?code=valid-code');
    await accounts.handleCallback(uri);
    await Future<void>.delayed(Duration.zero);
    expect(accounts.recovery, isTrue);
    await accounts.handleCallback(uri);
    expect(backend.callbackCount, 1);
    await accounts.resetPassword('newpassword123');
    expect(backend.updatedPassword, 'newpassword123');
    expect(accounts.recovery, isFalse);
    accounts.dispose();
    await backend.changes.close();
  });
  test(
    'failed profile load is retried instead of overwriting username',
    () async {
      final backend = FakeAccountBackend()
        ..userId = 'user'
        ..failProfile = true
        ..savedUsername = 'Existing';
      final accounts = AccountController(backend);
      await Future<void>.delayed(Duration.zero);
      expect(accounts.needsUsername, isFalse);
      expect(accounts.message, isNotNull);
      backend.failProfile = false;
      await accounts.refreshProfile();
      expect(accounts.username, 'Existing');
      expect(accounts.message, isNull);
      accounts.dispose();
      await backend.changes.close();
    },
  );
  test('wrong callback host and invalid inputs are rejected', () async {
    final backend = FakeAccountBackend(), accounts = AccountController(null);
    accounts.dispose();
    final controller = AccountController(backend);
    await controller.handleCallback(
      Uri.parse('io.synthdex.app://other-host/?code=bad'),
    );
    expect(backend.callbackCount, 0);
    await expectLater(
      controller.signUp('bad name', 'bad', 'short'),
      throwsFormatException,
    );
    expect(backend.signupFields, isNull);
    controller.dispose();
    await backend.changes.close();
  });
  testWidgets('create account has three fields and Google setup only one', (
    tester,
  ) async {
    final backend = FakeAccountBackend(), accounts = AccountController(null);
    accounts.dispose();
    final controller = AccountController(backend);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountPanel(accounts: controller, onDone: () {}),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New here? Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Continue with Google'), findsOneWidget);
    backend.userId = 'google-user';
    backend.provider = 'google';
    await controller.refreshProfile();
    await tester.pumpAndSettle();
    expect(find.text('Choose your username'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await backend.changes.close();
  });
}
