import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../data/api.dart';
import '../state/providers.dart';
import '../domain/models.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  Role _role = Role.mecanico;

  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // TODO: integrar com o método de cadastro da sua API.
      // Exemplo esperado:
      // await ref.read(authApiProvider).register(
      //   name: _name.text.trim(),
      //   username: _username.text.trim(),
      //   password: _password.text,
      //   role: _role,
      // );

      throw UnimplementedError('O cadastro ainda não foi implementado na API.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } on UnimplementedError catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível realizar o cadastro.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/images/logo.svg',
                        semanticsLabel: 'My SVG Image',
                        height: 160,
                        width: 160,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    key: const Key('register-name'),
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return 'Informe seu nome.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    key: const Key('register-username'),
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return 'Informe um nome de usuário.';
                      }
                      if ((v ?? '').trim().length < 3) {
                        return 'Use pelo menos 3 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Role>(
                    key: const Key('register-role'),
                    value: _role,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de usuário',
                      prefixIcon: Icon(Icons.work_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: Role.values.map((role) {
                      return DropdownMenuItem<Role>(
                        value: role,
                        child: Text(role.name),
                      );
                    }).toList(),
                    onChanged: (role) {
                      if (role != null) {
                        setState(() => _role = role);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    key: const Key('register-password'),
                    controller: _password,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if ((v ?? '').length < 8) {
                        return 'A senha deve ter pelo menos 8 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    key: const Key('register-confirm-password'),
                    controller: _confirmPassword,
                    obscureText: !_showPassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirme a senha',
                      prefixIcon: Icon(Icons.lock_reset),
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v != _password.text) {
                        return 'As senhas não coincidem.';
                      }
                      return null;
                    },
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const Key('register-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  FilledButton(
                    key: const Key('register-submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar conta'),
                  ),

                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Já tenho uma conta · Voltar ao login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
