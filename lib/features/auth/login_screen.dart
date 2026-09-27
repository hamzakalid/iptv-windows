import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _server = TextEditingController(text: savedServerUrl(ref.read(prefsProvider)));
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _obscure = true;
  bool _showServer = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(
            serverUrl: _server.text,
            email: _email.text.trim(),
            password: _password.text,
            signup: _signup,
          );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;

    final form = Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!wide) ...[const _Logo(), const SizedBox(height: 32)],
            Text(_signup ? 'Create your account' : 'Welcome back', style: AppText.h3),
            const SizedBox(height: 6),
            Text(
              _signup ? 'Start streaming in under a minute.' : 'Sign in to continue watching.',
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(PhosphorIconsRegular.at, size: 16)),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: [_signup ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(PhosphorIconsRegular.lock, size: 16),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash, size: 16),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showServer = !_showServer),
                icon: Icon(_showServer ? PhosphorIconsRegular.caretUp : PhosphorIconsRegular.hardDrives),
                label: Text(_showServer ? 'Hide server settings' : 'Server: ${_server.text}'),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _showServer
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'http://192.168.1.10:4000',
                          prefixIcon: Icon(PhosphorIconsRegular.hardDrives, size: 16),
                          helperText: 'Address of your IPTV backend',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Server address is required' : null,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(PhosphorIconsRegular.warningCircle, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!)),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signup ? 'Create account' : 'Sign in'),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_signup ? 'Already have an account?' : 'New here?',
                  style: const TextStyle(color: AppColors.textMuted)),
              TextButton(
                onPressed: () => setState(() {
                  _signup = !_signup;
                  _error = null;
                }),
                child: Text(_signup ? 'Sign in' : 'Create account'),
              ),
            ]),
          ],
        ),
      ),
    );

    final panel = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form),
      ),
    );

    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: _Backdrop()),
        if (wide)
          Row(children: [
            const Expanded(flex: 6, child: _Showcase()),
            Expanded(
              flex: 5,
              child: Container(
                color: AppColors.bg.withValues(alpha: 0.85),
                child: panel,
              ),
            ),
          ])
        else
          SafeArea(child: panel),
      ]),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: const Icon(PhosphorIconsFill.play, size: 18, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        const Text(appName, style: AppText.h4),
      ]);
}

/// A single field of saturated indigo, the system's one "presence" move,
/// fading into the ground.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.8),
            radius: 1.4,
            colors: [AppColors.section, AppColors.bg],
            stops: [0, 0.75],
          ),
        ),
      );
}

class _Showcase extends StatelessWidget {
  const _Showcase();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Logo(),
            Spacer(),
            Text('All your TV.\nOne quiet app.', style: AppText.h1),
            SizedBox(height: 18),
            SizedBox(
              width: 520,
              child: Text(
                'Live channels, movies and series from your IPTV provider, with a programme guide, '
                'recommendations and synced progress.',
                style: TextStyle(fontSize: 15, height: 1.55, color: AppColors.neutral400),
              ),
            ),
            SizedBox(height: 28),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Tag('Live TV with EPG', icon: PhosphorIconsRegular.broadcast),
              Tag('Movies & series', icon: PhosphorIconsRegular.filmStrip),
              Tag('Resume anywhere', icon: PhosphorIconsRegular.arrowsClockwise),
              Tag('Xtream & M3U', icon: PhosphorIconsRegular.playlist),
            ]),
            Spacer(),
          ],
        ),
      );
}
