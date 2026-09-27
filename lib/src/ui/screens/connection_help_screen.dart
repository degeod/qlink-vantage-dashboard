import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Explains how to connect when the IPE1000-P is on the home Wi‑Fi / router.
class ConnectionHelpScreen extends StatelessWidget {
  const ConnectionHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        title: const Text('Verbinden via router'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          _SectionTitle('Situatie'),
          _Body(
            'De IPE1000-P hangt aan je thuisnetwerk via de wifi-router '
            '(Ethernet of wifi-bridge). De telefoon praat niet “met de router”, '
            'maar met het IP-adres van de IPE op dat netwerk — of, buitenshuis, '
            'via een poortforward op diezelfde router.',
          ),
          SizedBox(height: 18),
          _SectionTitle('1. Thuis op hetzelfde wifi-netwerk'),
          _Bullet('Zet de telefoon op dezelfde wifi als de IPE (niet gast-wifi).'),
          _Bullet('Kies in de app: Local LAN.'),
          _Bullet('Host: 192.168.1.33  (IP van de IPE)'),
          _Bullet('Poort: 3041  (VCommand — niet 3040 van QLink)'),
          _Bullet('Sluit WebPoint (Home.exe) en QLink op de pc — maar één TCP-sessie tegelijk.'),
          _Bullet('Tik Connect.'),
          SizedBox(height: 18),
          _SectionTitle('2. Buitenshuis via de router (port forward)'),
          _Bullet('Geef de IPE een vast LAN-IP (nu: 192.168.1.33).'),
          _Bullet(
            'In de router: Port Forward / Virtual Server:\n'
            '  • Protocol: TCP\n'
            '  • Externe poort: bv. 3041 (of een andere hoge poort)\n'
            '  • Interne IP: 192.168.1.33\n'
            '  • Interne poort: 3041',
          ),
          _Bullet(
            'In de app: Via router\n'
            '  • WAN / DynDNS: jouw publieke IP of DynDNS-naam\n'
            '  • Externe poort: dezelfde als in de router-regel',
          ),
          _Bullet('WebPoint/QLink weer dicht laten. Tik Connect.'),
          SizedBox(height: 18),
          _SectionTitle('Router-checklist'),
          _Bullet('IPE en telefoon zitten in hetzelfde subnet (thuis), of forward is actief (buiten).'),
          _Bullet('Geen AP-isolatie / client isolation op wifi (blokkeert LAN-verkeer).'),
          _Bullet('Firewall op de router laat TCP 3041 (of jouw externe poort) toe.'),
          _Bullet('DynDNS updaten als je geen vast publiek IP hebt.'),
          SizedBox(height: 18),
          _SectionTitle('Veiliger alternatief'),
          _Body(
            'Open liever geen VCommand-poort naar het internet. Gebruik een VPN '
            'naar huis; verbind daarna met Local LAN (192.168.1.33:3041).',
          ),
          SizedBox(height: 18),
          _SectionTitle('Snelwaarden voor jouw installatie'),
          _CodeBlock(
            'LAN IPE:     192.168.1.33\n'
            'VCommand:    3041\n'
            'QLink (pc):  3040  ← niet voor deze app\n'
            'Master:      thuis',
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.muted, height: 1.45));
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.charcoalElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', height: 1.45, color: AppColors.ink),
      ),
    );
  }
}
