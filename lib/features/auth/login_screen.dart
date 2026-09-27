import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/nocturne.dart';

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
            if (!wide) ...[const _Brand(), const SizedBox(height: 36)],
            Text(_signup ? 'Create your account' : 'Welcome back', style: wide ? NocText.h2 : NocText.h3),
            const SizedBox(height: 6),
            Text(
              _signup ? 'Start streaming in under a minute.' : 'Sign in to continue watching.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            _Field(
              label: 'Email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Ph.at, size: 16)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'Password',
              child: TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: [_signup ? AutofillHints.newPassword : AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: _signup ? 'At least 8 characters' : 'Your password',
                  prefixIcon: const Icon(Ph.lock, size: 16),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: NocIconButton(
                      icon: _obscure ? Ph.eye : Ph.eyeSlash,
                      size: 32,
                      iconSize: 16,
                      color: AppColors.n500,
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 32),
                ),
                validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: NocButton.ghost(
                icon: _showServer ? Ph.caretUp : Ph.hardDrives,
                label: _showServer ? 'Hide server settings' : 'Server: ${_server.text}',
                foreground: _showServer ? AppColors.accent : AppColors.n400,
                onPressed: () => setState(() => _showServer = !_showServer),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topLeft,
              child: _showServer
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: _Field(
                        label: 'Server address',
                        child: TextFormField(
                          controller: _server,
                          keyboardType: TextInputType.url,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'http://192.168.1.10:4000',
                            prefixIcon: Icon(Ph.hardDrives, size: 16),
                            helperText: 'Address of your IPTV backend',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Server address is required' : null,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _ErrorNote(_error!),
            ],
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: GradientButton(
                label: _signup ? 'Create account' : 'Sign in',
                icon: _signup ? Ph.userCirclePlus : Ph.signIn,
                loading: _busy,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Text(_signup ? 'Already have an account?' : 'New here?',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(width: 4),
              NocButton.ghost(
                label: _signup ? 'Sign in' : 'Create account',
                onPressed: () => setState(() {
                  _signup = !_signup;
                  _error = null;
                }),
              ),
            ]),
          ],
        ),
      ),
    );

    if (!wide) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form),
            ),
          ),
        ),
      );
    }

    // Desktop: narrow, left-aligned form column; the rest is a quiet showcase.
    return Scaffold(
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: context.isExpanded ? 560 : 500,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 40, 56, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Brand(),
              Expanded(
                child: Align(
                  alignment: const Alignment(-1, -0.2),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: form),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const Expanded(child: _Showcase()),
      ]),
    );
  }
}

/// `.field` — 12px label at 70% text above the input.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.7))),
        const SizedBox(height: 5),
        child,
      ]);
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Ph.warningCircle, color: AppColors.danger, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.danger.withValues(alpha: 0.9))),
          ),
        ]),
      );
}

/// Brand mark as in the rail: 34px accent-outlined square with a filled play.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: const Icon(PhF.play, size: 16, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Text(appName, style: NocText.h5),
      ]);
}

class _Showcase extends StatelessWidget {
  const _Showcase();

  static const _features = [
    (Ph.television, 'Live TV with EPG', 'Now and next on every channel, with a full guide.'),
    (Ph.filmSlate, 'Movies & Series', 'Details, cast and episode lists straight from your provider.'),
    (Ph.arrowsClockwise, 'Resume anywhere', 'Progress and My List sync across your devices.'),
    (Ph.playlist, 'Xtream & M3U', 'Bring any playlist and switch between them at any time.'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.rail,
          border: Border(left: BorderSide(color: AppColors.text.withValues(alpha: 0.06))),
        ),
        padding: const EdgeInsets.fromLTRB(64, 40, 56, 40),
        child: Align(
          alignment: const Alignment(-1, 0.1),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Overline(appName),
                const SizedBox(height: 12),
                Text('All your TV.\nOne quiet, fast app.', style: NocText.h2.copyWith(height: 1.15)),
                const SizedBox(height: 14),
                Text(
                  'Live channels, movies and series from your IPTV provider — with smart recommendations and synced progress.',
                  style: TextStyle(fontSize: 14, height: 1.55, color: AppColors.muted),
                ),
                const SizedBox(height: 32),
                for (final (icon, title, note) in _features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(icon, size: 17, color: AppColors.a300),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Text(note, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      );
}
