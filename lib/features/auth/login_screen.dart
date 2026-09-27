import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final t = Theme.of(context).textTheme;
    final wide = context.isWide;

    final form = Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!wide) ...[const _Logo(), const SizedBox(height: 32)],
            Text(_signup ? 'Create your account' : 'Welcome back', style: t.headlineMedium),
            const SizedBox(height: 6),
            Text(
              _signup ? 'Start streaming in under a minute.' : 'Sign in to continue watching.',
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
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
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showServer = !_showServer),
                icon: Icon(_showServer ? Icons.expand_less_rounded : Icons.dns_outlined, size: 18),
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
                          prefixIcon: Icon(Icons.dns_outlined),
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!)),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
            GradientButton(
              label: _signup ? 'Create account' : 'Sign in',
              loading: _busy,
              onPressed: _submit,
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Text(appName, style: Theme.of(context).textTheme.headlineSmall),
      ]);
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.8),
            radius: 1.4,
            colors: [Color(0xFF2A1655), Color(0xFF16102A), AppColors.bg],
            stops: [0, 0.45, 1],
          ),
        ),
      );
}

class _Showcase extends StatelessWidget {
  const _Showcase();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Logo(),
          const Spacer(),
          ShaderMask(
            shaderCallback: (r) => AppColors.brandGradient.createShader(r),
            child: Text('All your TV.\nOne beautiful app.',
                style: t.displayMedium?.copyWith(color: Colors.white, height: 1.1)),
          ),
          const SizedBox(height: 20),
          Text('Live channels, movies and series from your IPTV provider —\nwith smart recommendations and synced progress.',
              style: t.titleMedium?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w400, height: 1.5)),
          const SizedBox(height: 36),
          const Wrap(spacing: 12, runSpacing: 12, children: [
            MetaChip('Live TV with EPG', icon: Icons.live_tv_rounded),
            MetaChip('Movies & Series', icon: Icons.movie_outlined),
            MetaChip('Resume anywhere', icon: Icons.sync_rounded),
            MetaChip('Xtream & M3U', icon: Icons.playlist_play_rounded),
          ]),
          const Spacer(),
        ],
      ),
    );
  }
}
