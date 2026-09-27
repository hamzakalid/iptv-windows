import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back (Esc)',
          onPressed: () => context.pop(),
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
        ),
        title: const Text('Add playlist'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _form,
            child: ListView(padding: EdgeInsets.all(context.pagePadding), children: [
              SegmentedControl<PlaylistType>(
                expand: true,
                segments: const [
                  Segment(PlaylistType.xtream, 'Xtream Codes', icon: PhosphorIconsRegular.hardDrives),
                  Segment(PlaylistType.m3u, 'M3U URL', icon: PhosphorIconsRegular.link),
                ],
                selected: _type,
                onChanged: (t) => setState(() {
                  _type = t;
                  _testResult = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _type == PlaylistType.xtream
                    ? 'Recommended. Unlocks EPG, movie details, cast and episode lists.'
                    : 'Any .m3u / .m3u8 playlist link from your provider.',
                style: AppText.meta,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  prefixIcon: Icon(PhosphorIconsRegular.tag, size: 16),
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
                    prefixIcon: Icon(PhosphorIconsRegular.link, size: 16),
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
                    prefixIcon: Icon(PhosphorIconsRegular.hardDrives, size: 16),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _user,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(PhosphorIconsRegular.user, size: 16)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  obscureText: true,
                  validator: _required,
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(PhosphorIconsRegular.lock, size: 16)),
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
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(PhosphorIconsRegular.warningCircle, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!)),
                  ]),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: _testing || _saving ? null : _test,
                    icon: _testing
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(PhosphorIconsRegular.plugsConnected),
                    label: const Text('Test'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: _testing || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(PhosphorIconsRegular.check),
                    label: const Text('Save playlist'),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(valid ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.xCircle, color: color),
          const SizedBox(width: 10),
          Text(valid ? 'Connection successful' : 'Connection failed',
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ]),
        if (rows.isNotEmpty) const SizedBox(height: 4),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.textMuted))),
              Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
            ]),
          ),
      ]),
    );
  }
}
