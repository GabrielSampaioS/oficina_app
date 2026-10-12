import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/login_page.dart';
import 'ui/orders_page.dart';

import 'theme/app_theme.dart';

class OficinaApp extends StatelessWidget {
  const OficinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oficina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

/// Raiz do app: mostra o login ou a lista de OS conforme a sessão. É um widget
/// próprio (e não um `home` condicional) para que a troca seja sempre
/// reconstruída pelo Riverpod.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    return user == null ? const LoginPage() : const OrdersPage();
  }
}
