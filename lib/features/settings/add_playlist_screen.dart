import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/json.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

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
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add playlist')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _form,
            child: ListView(padding: EdgeInsets.all(context.pagePadding), children: [
              SegmentedButton<PlaylistType>(
                segments: const [
                  ButtonSegment(value: PlaylistType.xtream, icon: Icon(Icons.dns_rounded), label: Text('Xtream Codes')),
                  ButtonSegment(value: PlaylistType.m3u, icon: Icon(Icons.link_rounded), label: Text('M3U URL')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _testResult = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _type == PlaylistType.xtream
                    ? 'Recommended. Unlocks EPG, movie details, cast and episode lists.'
                    : 'Any .m3u / .m3u8 playlist link from your provider.',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              if (_type == PlaylistType.m3u)
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  validator: _urlValidator,
                  decoration: const InputDecoration(
                    labelText: 'Playlist URL',
                    hintText: 'https://provider.com/get.php?…',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                )
              else ...[
                TextFormField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  validator: _urlValidator,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'http://provider.com:8080',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _user,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  obscureText: true,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                ),
              ],
              const SizedBox(height: 20),
              if (_testResult != null) _TestResult(result: _testResult!),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!)),
                  ]),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing || _saving ? null : _test,
                    icon: _testing
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded),
                    label: const Text('Test'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    label: 'Save playlist',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    onPressed: _testing ? null : _save,
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
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
    final color = valid ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(valid ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
          const SizedBox(width: 10),
          Text(valid ? 'Connection successful' : 'Connection failed',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 34),
            child: Row(children: [
              SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.textMuted))),
              Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
      ]),
    );
  }
}
