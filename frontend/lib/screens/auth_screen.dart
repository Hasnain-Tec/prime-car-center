import 'package:flutter/material.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  final SessionController session;
  const AuthScreen({super.key, required this.session});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    for (final controller in [
      _loginEmail,
      _loginPassword,
      _name,
      _email,
      _phone,
      _password
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.session.login(_loginEmail.text.trim(), _loginPassword.text);
    } catch (error) {
      showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    if (!_registerKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final message = await widget.session.register(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration submitted'),
          content: Text(message),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'))
          ],
        ),
      );
      setState(() => _registering = false);
    } catch (error) {
      showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        if (MediaQuery.sizeOf(context).width >= 900)
          Expanded(
            child: Container(
              color: PccColors.charcoal,
              padding: const EdgeInsets.all(64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandBadge(
                    size: 82,
                    logoUrl: widget.session.workshop.logoUrl,
                  ),
                  SizedBox(height: 28),
                  Text('PRIME CAR CENTER',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  SizedBox(height: 10),
                  Text('Workshop Job Records & Invoicing',
                      style: TextStyle(color: Color(0xFFB9C2CC), fontSize: 17)),
                  SizedBox(height: 32),
                  Text(
                      'Secure job assignment, user approval, role permissions, expenses and admin-only financial reporting.',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 15, height: 1.5)),
                ],
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _registering ? _buildRegister() : _buildLogin(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLogin() => Form(
        key: _loginKey,
        child: Column(
            key: const ValueKey('login'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _BrandBadge(
                  size: 62,
                  logoUrl: widget.session.workshop.logoUrl,
                ),
              ),
              const SizedBox(height: 18),
              const Text('Sign in',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Use your approved workshop account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PccColors.inkSoft)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _loginEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined)),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _loginPassword,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(_hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined)),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: _busy ? null : _login,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: const Text('SIGN IN')),
              const SizedBox(height: 10),
              TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _registering = true),
                  child: const Text('Create a registration request')),
            ]),
      );

  Widget _buildRegister() => Form(
        key: _registerKey,
        child: Column(
            key: const ValueKey('register'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Request an account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'The administrator must approve your account before login.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PccColors.inkSoft)),
              const SizedBox(height: 22),
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().length < 3
                      ? 'Enter your full name.'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email.'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) => value == null || value.length < 8
                      ? 'Use at least 8 characters.'
                      : null),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: _busy ? null : _register,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('SUBMIT REQUEST')),
              const SizedBox(height: 10),
              TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _registering = false),
                  child: const Text('Back to sign in')),
            ]),
      );
}

class _BrandBadge extends StatelessWidget {
  final double size;
  final String? logoUrl;

  const _BrandBadge({
    required this.size,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();

    Widget fallback() {
      return Text(
        'PCC',
        style: TextStyle(
          color: PccColors.charcoal,
          fontWeight: FontWeight.w900,
          fontSize: size * .24,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: url != null && url.isNotEmpty ? Colors.white : PccColors.hazard,
        border: Border.all(
          color: PccColors.charcoal,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(size * .23),
      ),
      alignment: Alignment.center,
      child: url == null || url.isEmpty
          ? fallback()
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback(),
            ),
    );
  }
}
