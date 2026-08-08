import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionController(ApiClient());
  await session.initialize();
  runApp(PrimeCarCenterApp(session: session));
}

class PrimeCarCenterApp extends StatelessWidget {
  final SessionController session;
  const PrimeCarCenterApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: session,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Prime Car Center',
          theme: buildPccTheme(),
          home: session.loading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : session.signedIn
                  ? HomeShell(session: session)
                  : AuthScreen(session: session),
        ),
      );
}
