import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? client;
  try {
    await Supabase.initialize(
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://sgwucpmxkxlgirgoukri.supabase.co',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable_8pHUDKSv_O0vigPNlaoY4g_mo45K3Oi',
      ),
    );
    client = Supabase.instance.client;
  } catch (_) {
    // A cloud initialization failure must not block offline tracking.
  }
  final store = AppStore(client);
  await store.initialize();
  runApp(SynthDexApp(store: store));
  // The account listener exists before exchanging callback tokens, including
  // cold-start password recovery links.
  await store.accounts.startLinks();
}
