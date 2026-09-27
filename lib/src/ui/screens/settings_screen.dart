import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../data/ivy_nvr_client.dart';
import '../../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/weather_city_picker.dart';
import 'connection_help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController localHostCtrl;
  late final TextEditingController localPortCtrl;
  late final TextEditingController remoteHostCtrl;
  late final TextEditingController remotePortCtrl;
  late final TextEditingController nvrUidCtrl;
  late final TextEditingController nvrUserCtrl;
  late final TextEditingController nvrPassCtrl;
  late final TextEditingController nvrChCtrl;
  late NetworkProfile profile;
  bool _importingQlk = false;
  bool _nvrBusy = false;
  String _nvrMsg = '';
  List<Map<String, dynamic>> _nvrFound = const [];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    localHostCtrl = TextEditingController(text: app.localHost);
    localPortCtrl = TextEditingController(text: '${app.localPort}');
    remoteHostCtrl = TextEditingController(text: app.remoteHost);
    remotePortCtrl = TextEditingController(text: '${app.remotePort}');
    nvrUidCtrl = TextEditingController(text: app.dashboard.nvrUid);
    nvrUserCtrl = TextEditingController(text: app.dashboard.nvrUser);
    nvrPassCtrl = TextEditingController(text: app.dashboard.nvrPassword);
    nvrChCtrl = TextEditingController(text: '${app.dashboard.nvrChannel}');
    profile = app.profile;
  }

  @override
  void dispose() {
    localHostCtrl.dispose();
    localPortCtrl.dispose();
    remoteHostCtrl.dispose();
    remotePortCtrl.dispose();
    nvrUidCtrl.dispose();
    nvrUserCtrl.dispose();
    nvrPassCtrl.dispose();
    nvrChCtrl.dispose();
    super.dispose();
  }

  int? _nvrChannelId(Map<String, dynamic> ch) {
    final raw = ch['channel'];
    return raw is num ? raw.toInt() : null;
  }

  String _nvrChannelLabel(Map<String, dynamic> ch, int index) {
    final id = _nvrChannelId(ch);
    final name = ch['name']?.toString().trim() ?? '';
    final online = ch['online'] == true;
    final base = name.isNotEmpty && name != 'Kanaal $id'
        ? name
        : 'Kanaal ${index + 1}';
    return online ? base : '$base (offline)';
  }

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.charcoalElevated,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: ListView(
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'IPE aan de wifi-router: thuis via Local LAN, buitenshuis via router-portforward.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ConnectionHelpScreen()),
              );
            },
            icon: const Icon(Icons.help_outline),
            label: const Text('Uitleg: IPE via wifi-router'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amber,
              side: const BorderSide(color: AppColors.amber),
            ),
          ),
          const SizedBox(height: 22),
          Text('Project / QLK', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.charcoalElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            ),
            child: Text(
              app.qlkSourceName == null
                  ? 'Nu actief: bundled WebPoint-testproject.\n'
                      'Kies een .qlk van je PC/telefoon om je echte project te laden. '
                      'Dit programmeert de Master niet — alleen de bedienings-UI. '
                      'Het bestand blijft bewaard tot je opnieuw laadt of terugzet.'
                  : 'Nu actief: ${app.qlkSourceName}\n'
                      'Lights ${app.project?.lights.length ?? 0} · '
                      'Keypads ${app.project?.keypads.length ?? 0} · '
                      'Macros ${app.project?.macros.length ?? 0}',
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _importingQlk ? null : () => _pickAndImportQlk(context, app),
            icon: _importingQlk
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(_importingQlk ? 'QLK laden…' : 'QLK-bestand selecteren & laden'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _importingQlk
                ? null
                : () async {
                    await app.reloadBundledProject();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bundled WebPoint-project herladen')),
                      );
                    }
                  },
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
            child: const Text('Terug naar bundled testproject'),
          ),
          const SizedBox(height: 16),
          Text(
            'Master: ${app.project?.master.name ?? "-"}\n'
            'Lights: ${app.project?.lights.length ?? 0} · '
            'Keypads: ${app.project?.keypads.length ?? 0} · '
            'Macros: ${app.project?.macros.length ?? 0}\n'
            'Active: ${app.activeHost}:${app.activePort} (${app.profile.name})',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 22),
          Text('Dashboard / tablet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined, color: AppColors.amber),
            title: const Text('Weer-stad', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              app.dashboard.weatherPlaceName,
              style: const TextStyle(color: AppColors.muted),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () async {
              final city = await showWeatherCityPicker(
                context,
                currentName: app.dashboard.weatherPlaceName,
              );
              if (city == null) return;
              await app.setDashboardWeatherLocation(
                lat: city.lat,
                lon: city.lon,
                placeName: city.name,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Weer-locatie: ${city.name}')),
                );
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('NVR op Dashboard', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'IvyIo SDK (zelfde stack als Foscam-app). Geen RTSP. '
              'Zoek de FN8108W in het LAN. Login = admin + wachtwoord van de Foscam-app. '
              'Leeg wachtwoord = SDK-fabriekswachtwoord (alleen als de UID dat vereist).',
              style: TextStyle(color: AppColors.muted, height: 1.35),
            ),
            value: app.dashboard.showNvr,
            activeColor: AppColors.amber,
            onChanged: (v) => app.setNvrSettings(show: v),
          ),
          if (app.dashboard.showNvr) ...[
            const SizedBox(height: 8),
            TextField(controller: nvrUidCtrl, decoration: _field('NVR UID')),
            const SizedBox(height: 12),
            TextField(controller: nvrUserCtrl, decoration: _field('Gebruiker', hint: 'admin')),
            const SizedBox(height: 12),
            TextField(
              controller: nvrPassCtrl,
              obscureText: true,
              decoration: _field('Wachtwoord', hint: 'Foscam-app; leeg = fabriek'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nvrChCtrl,
              keyboardType: TextInputType.number,
              decoration: _field('Kanaal', hint: 'SDK-nummer'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _nvrBusy
                      ? null
                      : () async {
                          setState(() {
                            _nvrBusy = true;
                            _nvrMsg = 'Zoeken…';
                          });
                          try {
                            final found = await IvyNvrClient.discover();
                            setState(() {
                              _nvrFound = found;
                              _nvrMsg = found.isEmpty
                                  ? 'Geen Foscam/Ivy-NVR in het LAN.'
                                  : '${found.length} NVR gevonden.';
                            });
                          } catch (e) {
                            setState(() => _nvrMsg = '$e');
                          } finally {
                            if (mounted) setState(() => _nvrBusy = false);
                          }
                        },
                  child: const Text('Zoek NVR in LAN'),
                ),
                ElevatedButton(
                  onPressed: _nvrBusy
                      ? null
                      : () async {
                          setState(() => _nvrBusy = true);
                          try {
                            await app.setNvrSettings(
                              uid: nvrUidCtrl.text,
                              user: nvrUserCtrl.text,
                              password: nvrPassCtrl.text,
                              channel: int.tryParse(nvrChCtrl.text.trim()) ?? 0,
                            );
                            final chans = await IvyNvrClient.login(
                              uid: nvrUidCtrl.text.trim(),
                              user: nvrUserCtrl.text.trim(),
                              password: nvrPassCtrl.text,
                            );
                            await app.applyNvrLogin(chans);
                            nvrChCtrl.text = '${app.dashboard.nvrChannel}';
                            setState(() => _nvrMsg = app.nvrStatus);
                          } catch (e) {
                            final msg = e is PlatformException
                                ? (e.message ?? e.code)
                                : '$e';
                            app.nvrReady = false;
                            app.nvrChannels = const [];
                            app.nvrStatus = msg;
                            app.notifyListeners();
                            setState(() => _nvrMsg = msg);
                          } finally {
                            if (mounted) setState(() => _nvrBusy = false);
                          }
                        },
                  child: const Text('NVR inloggen'),
                ),
              ],
            ),
            if (_nvrMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_nvrMsg, style: const TextStyle(color: AppColors.muted)),
              ),
            if (app.nvrChannels.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Kies kanalen (meer dan één mag)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < app.nvrChannels.length; i++)
                    FilterChip(
                      label: Text(
                        _nvrChannelLabel(app.nvrChannels[i], i),
                      ),
                      selected: app.dashboard.nvrSelectedChannels
                          .contains(_nvrChannelId(app.nvrChannels[i])),
                      selectedColor: const Color(0xFF2EE8E0),
                      checkmarkColor: const Color(0xFF12151A),
                      labelStyle: TextStyle(
                        color: app.dashboard.nvrSelectedChannels
                                .contains(_nvrChannelId(app.nvrChannels[i]))
                            ? const Color(0xFF12151A)
                            : Colors.white,
                      ),
                      onSelected: (_) {
                        final id = _nvrChannelId(app.nvrChannels[i]);
                        if (id == null) return;
                        nvrChCtrl.text = '$id';
                        app.toggleNvrChannel(id);
                      },
                    ),
                ],
              ),
            ],
            for (final d in _nvrFound)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${d['name'] ?? 'NVR'}  ${d['ip'] ?? ''}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${d['uid'] ?? ''}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                onTap: () => setState(() => nvrUidCtrl.text = '${d['uid'] ?? ''}'),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vaste tablet (muur)', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Op Dashboard: na 3 min geen aanraking → analoge klok in het midden, '
              'backlight gedimd. Echte Android-slaap zou de camera stoppen, dus het '
              'venster blijft wakker. Beweging of tik → scherm terug + IPE verbinden. '
              'Zonder camera in standby werkt wekken via beweging niet.',
              style: TextStyle(color: AppColors.muted, height: 1.35),
            ),
            value: app.dashboard.wallTabletMode,
            activeColor: AppColors.amber,
            onChanged: (v) async {
              if (v) {
                final cam = await Permission.camera.request();
                if (!cam.isGranted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Camera-toestemming geweigerd — muur-modus niet actief')),
                    );
                  }
                  return;
                }
              }
              await app.setWallTabletMode(v);
            },
          ),
          if (app.dashboard.wallTabletMode) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bewegingsgevoeligheid',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${app.dashboard.proximitySensitivity}',
                        style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    value: app.dashboard.proximitySensitivity.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${app.dashboard.proximitySensitivity}',
                    activeColor: AppColors.amber,
                    onChanged: (v) => app.setProximitySensitivity(v.round()),
                  ),
                  const Text(
                    'Links = minder vals alarm (lichtflikkering). Rechts = sneller wakker bij beweging.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text('Synchroniseren', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Namen, iconen, macro-inhoud, kleuren en dashboard-indeling worden per apparaat '
            'lokaal opgeslagen. Om tablet en telefoon gelijk te krijgen: exporteer op het '
            'bronapparaat en importeer op het andere (via Google Drive, e-mail, USB, …).',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _exportSettings(context, app),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
            icon: const Icon(Icons.upload_file),
            label: const Text('Instellingen exporteren (.json)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _importSettings(context, app),
            icon: const Icon(Icons.download),
            label: const Text('Instellingen importeren'),
          ),
          const SizedBox(height: 22),
          Text('Active path', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          SegmentedButton<NetworkProfile>(
            segments: const [
              ButtonSegment(value: NetworkProfile.local, label: Text('Local LAN'), icon: Icon(Icons.home_outlined)),
              ButtonSegment(value: NetworkProfile.remote, label: Text('Via router'), icon: Icon(Icons.public)),
            ],
            selected: {profile},
            onSelectionChanged: (s) => setState(() => profile = s.first),
          ),
          const SizedBox(height: 22),
          Text('Local IPE (LAN)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: localHostCtrl,
            decoration: _field('IPE IP', hint: '192.168.1.33'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: localPortCtrl,
            keyboardType: TextInputType.number,
            decoration: _field('VCommand port', hint: '3041'),
          ),
          const SizedBox(height: 22),
          Text('Via router (remote)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.charcoalElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'On your router, forward external TCP (e.g. 3041) to the IPE at '
              '192.168.1.33:3041. Then enter your public IP or DynDNS name below.\n\n'
              'Close WebPoint and QLink before connecting — the IPE allows one session.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: remoteHostCtrl,
            decoration: _field('WAN / DynDNS host', hint: 'myhome.duckdns.org'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: remotePortCtrl,
            keyboardType: TextInputType.number,
            decoration: _field('External TCP port', hint: '3041'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final localPort = int.tryParse(localPortCtrl.text.trim()) ?? 3041;
              final remotePort = int.tryParse(remotePortCtrl.text.trim()) ?? 3041;
              await app.saveNetworkSettings(
                localHost: localHostCtrl.text,
                localPort: localPort,
                remoteHost: remoteHostCtrl.text,
                remotePort: remotePort,
                profile: profile,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      profile == NetworkProfile.remote
                          ? 'Saved. Connect uses router ${remoteHostCtrl.text}:$remotePort'
                          : 'Saved. Connect uses LAN ${localHostCtrl.text}:$localPort',
                    ),
                  ),
                );
              }
            },
            child: const Text('Save connection settings'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await app.setProfile(profile);
              await app.connect();
            },
            icon: const Icon(Icons.link),
            label: Text(profile == NetworkProfile.remote ? 'Connect via router' : 'Connect on LAN'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amber,
              side: const BorderSide(color: AppColors.amber),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          Text('AI / onderhoud', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Voor verder bouwen op een andere PC: gebruik de bronmap of '
            'Desktop\\Vantage-Control-source.zip — niet alleen de APK. '
            'AGENTS.md zit ook in de app (onderstaand).',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showBundledDoc(context, 'assets/docs/START_HERE.md', 'START HERE'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('START HERE (AI)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showBundledDoc(context, 'assets/docs/AGENTS.md', 'AGENTS.md'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('AGENTS.md bekijken'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBundledDoc(BuildContext context, String assetPath, String title) async {
    final text = await rootBundle.loadString(assetPath);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.charcoal,
          appBar: AppBar(title: Text(title)),
          body: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(text, style: const TextStyle(color: AppColors.ink, height: 1.45, fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndImportQlk(BuildContext context, AppController app) async {
    setState(() => _importingQlk = true);
    try {
      // FileType.any: Android kent .qlk niet als MIME — custom filter toont vaak niets.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final name = file.name;
      final lower = name.toLowerCase();
      if (!lower.endsWith('.qlk') && !lower.endsWith('.txt') && !lower.endsWith('.text')) {
        if (!context.mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.charcoalElevated,
            title: const Text('Geen .qlk-extensie'),
            content: Text(
              '“$name” eindigt niet op .qlk. Toch proberen te laden?',
              style: const TextStyle(color: AppColors.muted),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Laden')),
            ],
          ),
        );
        if (proceed != true) return;
      }

      String text;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        text = _decodeQlkBytes(file.bytes!);
      } else if (file.path != null) {
        text = await File(file.path!).readAsString();
      } else {
        throw StateError('Kon bestand niet lezen (geen bytes/pad).');
      }
      if (text.trim().isEmpty) {
        throw StateError('Bestand is leeg.');
      }

      await app.importQlkText(text, sourceName: name);
      if (context.mounted) {
        final p = app.project;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QLK geladen: $name — '
              '${p?.lights.length ?? 0} lights, '
              '${p?.keypads.length ?? 0} keypads, '
              '${p?.macros.length ?? 0} macros',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QLK-import mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingQlk = false);
    }
  }

  Future<void> _exportSettings(BuildContext context, AppController app) async {
    try {
      final bundle = await app.exportSettingsBundle();
      final json = const JsonEncoder.withIndent('  ').convert(bundle);
      final bytes = utf8.encode(json);
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Instellingen opslaan',
        fileName: 'vantage-settings.json',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (!context.mounted) return;
      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instellingen geëxporteerd')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export mislukt: $e')),
        );
      }
    }
  }

  Future<void> _importSettings(BuildContext context, AppController app) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      String text;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        text = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        text = await File(file.path!).readAsString();
      } else {
        throw StateError('Kon bestand niet lezen.');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw FormatException('Geen geldig JSON-bestand.');
      }
      await app.importSettingsBundle(Map<String, dynamic>.from(decoded));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instellingen geïmporteerd — controleer Dashboard/Remote')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import mislukt: $e')),
        );
      }
    }
  }

  String _decodeQlkBytes(List<int> bytes) {
    // QLink exports are usually Windows Latin-1 / CP1252.
    final asLatin = latin1.decode(bytes, allowInvalid: true);
    if (asLatin.contains('QLink:') || asLatin.contains('Load:') || asLatin.contains('Station:')) {
      return asLatin;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
