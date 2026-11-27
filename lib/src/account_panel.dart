import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'accounts.dart';
import 'pjsk_ui.dart';
import 'themes.dart';

class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, required this.accounts, required this.onDone});
  final AccountController accounts;
  final VoidCallback onDone;
  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  String mode = 'signin';
  String? error, notice;
  bool busy = false, obscure = true;
  AccountController get a => widget.accounts;
  @override
  void dispose() {
    username.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void change(String next) => setState(() {
    mode = next;
    error = null;
    notice = null;
    password.clear();
  });
  Future<void> perform(
    Future<void> Function() fn, {
    String? success,
    bool validate = true,
  }) async {
    if (busy || (validate && !(form.currentState?.validate() ?? false))) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await fn();
      if (mounted) setState(() => notice = success);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not complete this request. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget button(String text, VoidCallback onTap, {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: PjskGlossyButton(
          label: text,
          onPressed: busy ? null : onTap,
          secondary: secondary,
        ),
      );
  Widget passwordField({bool creating = false}) => TextFormField(
    key: ValueKey('password-$creating'),
    controller: password,
    obscureText: obscure,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      creating ? AutofillHints.newPassword : AutofillHints.password,
    ],
    validator: (value) => creating
        ? validatePassword(value ?? '')
        : (value?.isEmpty ?? true)
        ? 'Enter your password.'
        : null,
    decoration: InputDecoration(
      labelText: creating ? 'Password (8+ characters)' : 'Password',
      suffixIcon: IconButton(
        tooltip: obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => obscure = !obscure),
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
  Widget usernameField() => TextFormField(
    key: const Key('account-username'),
    controller: username,
    autofillHints: const [AutofillHints.username],
    maxLength: 24,
    validator: (v) => validateUsername(v ?? ''),
    decoration: const InputDecoration(
      labelText: 'Username',
      helperText: '3–24 letters, numbers or underscores',
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: a,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final tokens = PjskTokens.of(context);
      final setup = a.needsUsername;
      final reset = a.recovery;
      final signedIn = a.signedIn && a.username != null;
      final title = reset
          ? 'Choose a new password'
          : setup
          ? 'Choose your username'
          : signedIn
          ? 'You’re signed in'
          : mode == 'signup'
          ? 'Create your account'
          : mode == 'forgot'
          ? 'Forgot password?'
          : 'Welcome back';
      final subtitle = setup
          ? 'One last step. Choose a username for your account.'
          : reset
          ? 'Your recovery link is verified. Set a new password.'
          : 'Your local progress stays on this device. An account is only needed for cloud backups.';
      return AutofillGroup(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PjskPageHeader(
                eyebrow: 'OPTIONAL CLOUD BACKUP',
                title: title,
                subtitle: subtitle,
              ),
              if (error ?? a.message case final String message) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.pink.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tokens.pink.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (notice != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.aqua.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tokens.aqua.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    notice!,
                    style: TextStyle(
                      color: tokens.isDark ? tokens.aqua : scheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (busy) const LinearProgressIndicator(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    for (final prev in previousChildren)
                      IgnorePointer(child: prev),
                    ?currentChild,
                  ],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey('$mode-$setup-$reset-$signedIn-${a.loading}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.loading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Loading account…'),
                    ] else if (reset) ...[
                      passwordField(creating: true),
                      button(
                        'Save new password',
                        () => perform(() async {
                          await a.resetPassword(password.text);
                          password.clear();
                        }, success: 'Password updated.'),
                      ),
                    ] else if (setup) ...[
                      usernameField(),
                      button(
                        'Finish account setup',
                        () => perform(() async {
                          await a.chooseUsername(username.text);
                        }, success: 'Your account is ready.'),
                      ),
                    ] else if (signedIn) ...[
                      PjskPrismCard(
                        gradient: tokens.heroGradient,
                        showArtOverlay: true,
                        child: Text(
                          '@${a.username}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      button('Continue to profile', () {
                        a.dismiss();
                        widget.onDone();
                      }),
                    ] else if (a.signedIn) ...[
                      button(
                        'Retry loading account',
                        () => perform(a.refreshProfile, validate: false),
                      ),
                    ] else if (mode == 'forgot') ...[
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => validateEmail(v ?? ''),
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      button(
                        'Send recovery email',
                        () => perform(
                          () => a.sendReset(email.text),
                          success:
                              'If an account uses this email, a recovery link will arrive shortly. Open it on this device.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'If you use Google, you can sign in with Google without a SynthDex password.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: busy ? null : () => change('signin'),
                          child: const Text('Back to sign in'),
                        ),
                      ),
                    ] else ...[
                      PjskPrismCard(
                        backgroundColor: scheme.surfaceContainer.withValues(
                          alpha: tokens.isDark ? 0.9 : 0.96,
                        ),
                        rainbowOpacity: 0.45,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            button(
                              'Continue with Google',
                              () => perform(
                                a.google,
                                validate: false,
                                success:
                                    'Complete sign-in in Google, then return here.',
                              ),
                              secondary: true,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'or use email',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (mode == 'signup') ...[
                              usernameField(),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              key: const Key('account-email'),
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: (v) => validateEmail(v ?? ''),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                            ),
                            const SizedBox(height: 14),
                            passwordField(creating: mode == 'signup'),
                            const SizedBox(height: 4),
                            button(
                              mode == 'signup' ? 'Create account' : 'Sign in',
                              () => perform(
                                () async {
                                  if (mode == 'signup') {
                                    await a.signUp(
                                      username.text,
                                      email.text,
                                      password.text,
                                    );
                                  } else {
                                    await a.signIn(email.text, password.text);
                                  }
                                  password.clear();
                                },
                                success: mode == 'signup'
                                    ? 'Check your email to confirm your account. Then return here to sign in.'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            if (mode == 'signin')
                              TextButton(
                                onPressed: busy ? null : () => change('forgot'),
                                child: const Text('Forgot password?'),
                              ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => change(
                                      mode == 'signup' ? 'signin' : 'signup',
                                    ),
                              child: Text(
                                mode == 'signup'
                                    ? 'Already have an account? Sign in'
                                    : 'New here? Create account',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          a.dismiss();
                          widget.onDone();
                        },
                  child: const Text('Continue using local data'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AccountGate extends StatelessWidget {
  const AccountGate({super.key, required this.accounts, required this.child});
  final AccountController accounts;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: accounts,
    builder: (context, _) => Stack(
      children: [
        child,
        if (accounts.needsAttention)
          Positioned.fill(
            child: Scaffold(
              body: Stack(
                children: [
                  const Positioned.fill(child: PjskStageBackdrop()),
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: AccountPanel(
                            accounts: accounts,
                            onDone: accounts.dismiss,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
