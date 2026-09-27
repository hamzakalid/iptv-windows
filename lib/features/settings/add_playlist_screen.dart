import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/nocturne.dart';

class AddPlaylistScreen extends ConsumerStatefulWidget {
  const AddPlaylistScreen({super.key});

  @override
  ConsumerState<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends ConsumerState<AddPlaylistScreen> {
  final _form = GlobalKey<FormState>();
  PlaylistType _type = PlaylistType.xtream;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _testing = false;
  bool _saving = false;
  Json? _testResult;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _url, _server, _user, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _config => _type == PlaylistType.m3u
      ? {'url': _url.text.trim()}
      : {'serverUrl': _server.text.trim(), 'username': _user.text.trim(), 'password': _pass.text};

  String get _resolvedName {
    final n = _name.text.trim();
    if (n.isNotEmpty) return n;
    final host = Uri.tryParse(_type == PlaylistType.m3u ? _url.text.trim() : _server.text.trim())?.host;
    return (host == null || host.isEmpty) ? 'My playlist' : host;
  }

  Future<void> _test() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _error = null;
      _testResult = null;
    });
    try {
      final r = await ref.read(repositoryProvider).testPlaylist(_resolvedName, _type, _config);
      setState(() => _testResult = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = await ref.read(repositoryProvider).createPlaylist(_resolvedName, _type, _config);
      ref.read(activePlaylistProvider.notifier).select(p.id);
      ref.invalidate(playlistsProvider);
      ref.invalidate(homeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${p.name}" added — importing your content now.')),
      );
      context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _urlValidator(String? v) {
    if (_required(v) != null) return 'Required';
    final u = Uri.tryParse(v!.trim());
    return (u == null || !u.hasScheme || u.host.isEmpty) ? 'Enter a full URL starting with http:// or https://' : null;
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    const gap = SizedBox(height: 14);
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad - 8, 20, pad, 14),
            child: Row(children: [
              NocIconButton(
                icon: Ph.arrowLeft,
                tooltip: 'Back',
                onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
              ),
              const SizedBox(width: 6),
              const Expanded(child: PageTitle('Add playlist', caption: 'Connect an IPTV source to your account')),
            ]),
          ),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(padding: EdgeInsets.fromLTRB(pad, 6, pad, 32), children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Overline('Source type', padding: EdgeInsets.only(bottom: 8)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Seg<PlaylistType>(
                          options: const [
                            SegOption(PlaylistType.xtream, 'Xtream Codes', icon: Ph.hardDrives),
                            SegOption(PlaylistType.m3u, 'M3U URL', icon: Ph.link),
                          ],
                          value: _type,
                          onChanged: (t) => setState(() {
                            _type = t;
                            _testResult = null;
                            _error = null;
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _type == PlaylistType.xtream
                            ? 'Recommended. Unlocks EPG, movie details, cast and episode lists.'
                            : 'Any .m3u / .m3u8 playlist link from your provider.',
                        style: NocText.muted,
                      ),
                      const SizedBox(height: 24),
                      const Overline('Details', padding: EdgeInsets.only(bottom: 10)),
                      _Field(
                        label: 'Name (optional)',
                        child: TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            hintText: 'My provider',
                            prefixIcon: Icon(Ph.tag, size: 16),
                          ),
                        ),
                      ),
                      gap,
                      if (_type == PlaylistType.m3u)
                        _Field(
                          label: 'Playlist URL',
                          child: TextFormField(
                            controller: _url,
                            keyboardType: TextInputType.url,
                            validator: _urlValidator,
                            decoration: const InputDecoration(
                              hintText: 'https://provider.com/get.php?…',
                              prefixIcon: Icon(Ph.link, size: 16),
                            ),
                          ),
                        )
                      else ...[
                        _Field(
                          label: 'Server URL',
                          child: TextFormField(
                            controller: _server,
                            keyboardType: TextInputType.url,
                            validator: _urlValidator,
                            decoration: const InputDecoration(
                              hintText: 'http://provider.com:8080',
                              prefixIcon: Icon(Ph.hardDrives, size: 16),
                            ),
                          ),
                        ),
                        gap,
                        _Field(
                          label: 'Username',
                          child: TextFormField(
                            controller: _user,
                            validator: _required,
                            decoration: const InputDecoration(prefixIcon: Icon(Ph.user, size: 16)),
                          ),
                        ),
                        gap,
                        _Field(
                          label: 'Password',
                          child: TextFormField(
                            controller: _pass,
                            obscureText: true,
                            validator: _required,
                            decoration: const InputDecoration(prefixIcon: Icon(Ph.lock, size: 16)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_testResult != null) _TestResult(result: _testResult!),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Ph.warningCircle, size: 16, color: AppColors.danger),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: TextStyle(
                                      fontSize: 13, height: 1.4, color: AppColors.danger.withValues(alpha: 0.9))),
                            ),
                          ]),
                        ),
                      Row(children: [
                        NocButton(
                          label: _testing ? 'Testing…' : 'Test connection',
                          icon: Ph.plugsConnected,
                          height: 38,
                          onPressed: _testing || _saving ? null : _test,
                        ),
                        const SizedBox(width: 8),
                        GradientButton(
                          label: 'Save playlist',
                          icon: Ph.check,
                          loading: _saving,
                          onPressed: _testing ? null : _save,
                        ),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
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

class _TestResult extends StatelessWidget {
  const _TestResult({required this.result});
  final Json result;

  @override
  Widget build(BuildContext context) {
    final valid = result['valid'] != false;
    final info = jMap(result['info']) ?? const {};
    final expires = jDate(info['expiresAt']);
    final rows = <(String, String)>[
      if (jStr(info['status']) != null) ('Status', jStr(info['status'])!),
      if (expires != null) ('Expires', '${expires.year}-${expires.month.toString().padLeft(2, '0')}-${expires.day.toString().padLeft(2, '0')}'),
      if (jInt(info['maxConnections']) != null)
        ('Connections', '${jInt(info['activeConnections']) ?? 0} / ${jInt(info['maxConnections'])}'),
      if (jInt(info['channels']) != null) ('Channels', '${jInt(info['channels'])}'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NocTag(
            valid ? 'Connected' : 'Failed',
            kind: valid ? TagKind.accent : TagKind.neutral,
            icon: valid ? Ph.checkCircle : Ph.xCircle,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(valid ? 'Connection successful' : 'Connection failed',
                style: TextStyle(
                  fontSize: 13,
                  color: valid ? AppColors.muted : AppColors.danger.withValues(alpha: 0.9),
                )),
          ),
        ]),
        if (rows.isNotEmpty) const SizedBox(height: 4),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(width: 110, child: Text(k, style: TextStyle(fontSize: 13, color: AppColors.muted))),
              Expanded(
                child: Text(v,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFeatures: NocText.tabular)),
              ),
            ]),
          ),
      ]),
    );
  }
}
