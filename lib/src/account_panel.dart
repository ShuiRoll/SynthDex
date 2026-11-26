import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'accounts.dart';

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
          () => error = 'Could not complete this request. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget button(String text, VoidCallback onTap, {bool secondary = false}) =>
      Padding(
        padding: EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.all(16),
              backgroundColor: secondary
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : null,
              foregroundColor: secondary
                  ? Theme.of(context).colorScheme.onSurface
                  : null,
            ),
            onPressed: busy ? null : onTap,
            child: Text(text),
          ),
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
    key: Key('account-username'),
    controller: username,
    autofillHints: [AutofillHints.username],
    maxLength: 24,
    validator: (v) => validateUsername(v ?? ''),
    decoration: InputDecoration(
      labelText: 'Username',
      helperText: '3–24 letters, numbers or underscores',
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: a,
    builder: (context, _) {
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
      return AutofillGroup(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPTIONAL CLOUD BACKUP',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                setup
                    ? 'One last step. Choose a username for your account.'
                    : reset
                    ? 'Your recovery link is verified. Set a new password.'
                    : 'Your local progress stays on this device. An account is only needed for cloud backups.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 24),
              if (error ?? a.message case final String message) ...[
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                SizedBox(height: 16),
              ],
              if (notice != null) ...[
                Text(
                  notice!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                SizedBox(height: 16),
              ],
              if (busy) LinearProgressIndicator(),
              if (a.loading) ...[
                LinearProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading account…'),
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
                Text(
                  '@${a.username}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
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
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                button(
                  'Send recovery email',
                  () => perform(
                    () => a.sendReset(email.text),
                    success: 'If an account uses this email, a recovery link will arrive shortly. Open it on this device.',
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'If you use Google, you can sign in with Google without a SynthDex password.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => change('signin'),
                  child: Text('Back to sign in'),
                ),
              ] else ...[
                button(
                  'Continue with Google',
                  () => perform(
                    a.google,
                    validate: false,
                    success: 'Complete sign-in in Google, then return here.',
                  ),
                  secondary: true,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'or use email',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (mode == 'signup') ...[
                  usernameField(),
                  SizedBox(height: 12),
                ],
                TextFormField(
                  key: Key('account-email'),
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: [AutofillHints.email],
                  validator: (v) => validateEmail(v ?? ''),
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                SizedBox(height: 16),
                passwordField(creating: mode == 'signup'),
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
                if (mode == 'signin')
                  TextButton(
                    onPressed: busy ? null : () => change('forgot'),
                    child: Text('Forgot password?'),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => change(mode == 'signup' ? 'signin' : 'signup'),
                  child: Text(
                    mode == 'signup'
                        ? 'Already have an account? Sign in'
                        : 'New here? Create account',
                  ),
                ),
              ],
              SizedBox(height: 16),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        a.dismiss();
                        widget.onDone();
                      },
                child: Text('Continue using local data'),
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
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: AccountPanel(
                        accounts: accounts,
                        onDone: accounts.dismiss,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
