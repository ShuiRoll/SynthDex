# Account setup and callback configuration

Accounts are optional. They exist for cloud backups and an editable display name;
all tracking works signed out. No secrets are stored in source — the app ships only
the publishable key, which is public by design, and row-level security protects
personal rows.

## Configured endpoints

| Setting | Default |
| --- | --- |
| Supabase URL | `https://sgwucpmxkxlgirgoukri.supabase.co` |
| Redirect (web) | Current page URL with query and fragment stripped |
| Redirect (native) | `io.synthdex.app://auth-callback/` |

Both are overridable:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=AUTH_REDIRECT_URL=https://your.site/auth/callback
```

`AUTH_REDIRECT_URL` wins when set. Never put a service-role or secret key here.

## Required project configuration

In the Supabase dashboard:

1. **Authentication → URL Configuration** — add every exact redirect used:
   - the web origin, e.g. `http://localhost:3000/` and the deployed site URL;
   - the native scheme, `io.synthdex.app://auth-callback/`.
2. **Authentication → Providers → Google** — enable it and register the provider's
   authorized redirect URI (Supabase's `/auth/v1/callback`).
3. **Authentication → Emails** — confirm the signup template and the recovery
   template both use the configured redirect. Raise the email rate limits only if
   you accept the associated risk; the default limits can delay repeated
   confirmation or recovery attempts.

Native platforms also need the `io.synthdex.app` scheme registered (Android intent
filter, iOS URL type) for `app_links` to receive the callback.

## Flows

### Email and password

Signup sends username, email and password. The username rides in user metadata as
`signup_username` and is only a *suggestion*: the database is authoritative. When
the user confirms and the provider is email with a valid suggestion and no profile
row exists yet, the app writes `profiles.username`; a duplicate (`23505`) there
shows "That username was taken. Please choose another." Choosing a name by hand
reports "That username is already taken. Choose another." Neither overwrites an
existing name.

Sign-in is email plus password. The 8-character minimum is client-side validation
only (`validatePassword`), so the project's own auth password policy still applies.
Username rules — `^[A-Za-z0-9_]{3,24}$` — are enforced in the client and, for
`profiles.username`, by a check constraint plus a unique index on `lower(username)`.

### Google

`signInWithOAuth` with `prompt=select_account`. Google accounts have no signup
username metadata, so a returning user keeps the username already stored; a new
user goes through username onboarding. If a write races another user, the unique
`23505` is reported as taken and onboarding stays recoverable.

### Password recovery

`resetPasswordForEmail` sends a link. Opening it produces a recovery event, and the
app requires a *fresh* recovery link plus a signed-in session before calling
`updateUser`. Without both, it refuses with "Open a fresh password recovery link
first." A cold start into a recovery link works because the auth listener is
installed before tokens are exchanged.

### Username onboarding

After sign-in, the profile is loaded from `profiles`. If it is missing and the
provider is email with a valid suggestion, the suggestion is written; otherwise the
app asks for a username. A failed profile read is retried rather than treated as
"no username", so a network blip cannot cause an overwrite.

## Callback handling

- `main.dart` initializes Supabase with `detectSessionInUri: false` and starts link
  listening after `runApp`, so an account listener exists before a cold-start
  token exchange.
- `app_links`' `uriLinkStream` handles warm links; the initial link (or `Uri.base`
  on web) handles cold starts.
- A callback is ignored unless scheme, host, port **and** path match the configured
  redirect exactly. Foreign links cannot inject a session.
- A callback must carry `code`, `access_token` or `error_description`; anything else
  is ignored. The same URI is processed once (`_lastCallback`).
- `error_description` and SDK failures produce "This account link expired, was
  cancelled, or could not be verified. Request a new link and open it on this
  device." rather than a crash or a silent no-op.

## Security notes

- `profiles` is owner-only with `anon` revoked; catalog tables stay public.
- Username metadata is never treated as an authorization claim.
- Backup and restore capture the user id and abort if the account changes between
  the RPC and the local write.
- Display-name editing is gated on a signed-in session; guest theme and difficulty
  changes are not.
- Personal data lives locally first, so signing out or losing the connection never
  removes progress.

## Verification status

The offline suite covers email signup, Google onboarding, recovery entry, duplicate
usernames, profile retry and callback host validation. Real email confirmation,
live Google sign-in and native-device callbacks have not been exercised end to end.
