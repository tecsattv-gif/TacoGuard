import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'i18n.dart';
import 'tacho_link.dart';
import 'theme.dart';

/// 1.11.0 (experimental): cartão em Ajustes para ligar o TacoGuard ao
/// tacógrafo por Bluetooth. Opcional: desligado, o app segue só pelo GPS.
class TachoCard extends StatefulWidget {
  const TachoCard({super.key});
  @override
  State<TachoCard> createState() => _TachoCardState();
}

class _TachoCardState extends State<TachoCard> {
  final _t = TachoLink.I;

  @override
  void initState() {
    super.initState();
    _t.addListener(_refresh);
  }

  @override
  void dispose() {
    _t.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
    if (_t.needPin && mounted && !_asking) _askPin();
  }

  bool _asking = false;

  Future<void> _askPin() async {
    _asking = true;
    final c = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('PIN do tacógrafo')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Escreva o PIN de 4 algarismos que aparece no ecrã do tacógrafo.')),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(hintText: '0000'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: Text(tr('Enviar'))),
        ],
      ),
    );
    _asking = false;
    if (pin != null && pin.trim().length >= 4) await _t.sendPin(pin);
  }

  Future<void> _choose() async {
    final list = await _t.bonded();
    if (!mounted) return;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Nenhum aparelho emparelhado. Emparelhe primeiro o tacógrafo nas definições de Bluetooth do telefone.'))));
      return;
    }
    final pick = await showModalBottomSheet<Map<String, String>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
              title: Text(tr('Escolha o tacógrafo'),
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          for (final d in list)
            ListTile(
              leading: const Icon(Icons.bluetooth_rounded),
              title: Text(d['name']!.isEmpty ? d['address']! : d['name']!),
              subtitle: Text(d['address']!),
              onTap: () => Navigator.pop(ctx, d),
            ),
        ]),
      ),
    );
    if (pick != null) await _t.choose(pick['name']!, pick['address']!);
  }

  String get _stateText {
    if (!_t.enabled) return tr('Desligado: o app usa só o GPS.');
    if (_t.deviceAddress.isEmpty) return tr('Escolha o tacógrafo.');
    if (_t.connected) {
      return _t.lastData == null
          ? tr('Ligado a {0}. À espera dos dados…', [_t.deviceName])
          : tr('Ligado a {0}. Últimos dados às {1}.', [
              _t.deviceName,
              '${_t.lastData!.hour.toString().padLeft(2, '0')}:${_t.lastData!.minute.toString().padLeft(2, '0')}'
            ]);
    }
    return tr('Sem ligação ({0}). O app usa o GPS.', [_t.state]);
  }

  @override
  Widget build(BuildContext context) {
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Ligar ao tacógrafo (Bluetooth)')),
          subtitle: Text(tr('Experimental. Tacógrafos inteligentes com Bluetooth (ex.: VDO DTCO 4.0/4.1).')),
          value: _t.enabled,
          onChanged: (v) async {
            if (v && _t.deviceAddress.isEmpty) {
              await _choose();
            } else {
              await _t.setEnabled(v);
            }
          },
        ),
        Row(children: [
          Icon(
              _t.connected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              color: _t.connected ? TG.ok : TG.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(_stateText, style: const TextStyle(fontSize: 13.5))),
        ]),
        if (_t.lastError != null) ...[
          const SizedBox(height: 6),
          Text(_t.lastError!,
              style: const TextStyle(color: TG.danger, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          OutlinedButton.icon(
              onPressed: _choose,
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: Text(tr('Escolher tacógrafo'))),
          if (_t.enabled && _t.deviceAddress.isNotEmpty && !_t.connected)
            OutlinedButton.icon(
                onPressed: _t.connect,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('Tentar ligar'))),
          OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TachoTestPage())),
              icon: const Icon(Icons.bug_report_outlined),
              label: Text(tr('Teste e registo'))),
        ]),
      ]),
    );
  }
}

/// Tela de teste: tudo o que foi enviado e recebido, e botões para pedir
/// cada tipo de dados. O registo é para mandar ao desenvolvedor.
class TachoTestPage extends StatefulWidget {
  const TachoTestPage({super.key});
  @override
  State<TachoTestPage> createState() => _TachoTestPageState();
}

class _TachoTestPageState extends State<TachoTestPage> {
  final _t = TachoLink.I;
  final _raw = TextEditingController();

  @override
  void initState() {
    super.initState();
    _t.addListener(_r);
  }

  @override
  void dispose() {
    _t.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _share() async {
    final f = await _t.exportLog();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'text/plain')],
      subject: tr('Registo do tacógrafo (TacoGuard)'),
    ));
  }

  void _sendRaw() {
    final bytes = _raw.text
        .split(RegExp(r'[\s,]+'))
        .where((x) => x.isNotEmpty)
        .map((x) => int.tryParse(x, radix: 16))
        .whereType<int>()
        .toList();
    if (bytes.isNotEmpty) _t.sendRaw(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Tacógrafo: teste')),
        actions: [
          IconButton(
              tooltip: tr('Partilhar registo'),
              onPressed: _share,
              icon: const Icon(Icons.share_rounded)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${tr('Estado')}: ${_t.state}  •  ITS ID ${TachoLink.hex([_t.itsId])}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          OutlinedButton(onPressed: _t.connect, child: Text(tr('Ligar'))),
          OutlinedButton(
              onPressed: _t.listen, child: Text(tr('Esperar o tacógrafo'))),
          OutlinedButton(onPressed: _t.disconnect, child: Text(tr('Desligar'))),
          for (final e in TachoLink.trtpNames.entries)
            OutlinedButton(
                onPressed: () => _t.requestData(e.key),
                child: Text('${e.key}: ${e.value}')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _raw,
              decoration: InputDecoration(
                  labelText: tr('Enviar bytes (hex)'), hintText: 'EE A0 04 08 01 FF FF ..'),
            ),
          ),
          IconButton(onPressed: _sendRaw, icon: const Icon(Icons.send_rounded)),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share_rounded),
            label: Text(tr('Partilhar registo'))),
        const SizedBox(height: 12),
        for (final l in _t.log.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SelectableText(l,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
          ),
      ]),
    );
  }
}
