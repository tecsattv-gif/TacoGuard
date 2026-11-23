import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'charts_page.dart';
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
              style: TextStyle(color: TG.danger, fontSize: 12)),
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
          FilledButton.tonalIcon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TachoHelpPage())),
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(tr('Como ligar (passo a passo)'))),
        ]),
      ]),
    );
  }
}

/// 1.11.9: mini tutorial para emparelhar e ligar ao tacógrafo.
class TachoHelpPage extends StatelessWidget {
  const TachoHelpPage({super.key});

  static const _txt = <String, List<(String, List<String>)>>{
    'pt': [
      ('No tacógrafo (VDO DTCO 4.1)', [
        'Camião parado, ignição ligada e o seu cartão no leitor 1.',
        'Carregue em OK para abrir o menu.',
        'Carregue em ▼ até "Entrada condutor 1" e carregue em OK.',
        'Carregue em ▼ até "Bluetooth" e carregue em OK.',
        'Escolha "Emparelhamento" e carregue em OK. O tacógrafo fica visível com o nome DTCO-número de série.',
      ]),
      ('No telemóvel', [
        'Abra Definições → Bluetooth e procure aparelhos.',
        'Toque em DTCO-… (ex.: DTCO-20876740).',
        'Aparece um código de 6 números no telemóvel e no tacógrafo. Se forem iguais, toque em Emparelhar no telemóvel e carregue em OK no tacógrafo.',
        'O DTCO fica em "Aparelhos emparelhados". Só é preciso fazer isto uma vez.',
      ]),
      ('No TacoGuard', [
        'Ajustes → Tacógrafo: ligue "Ligar ao tacógrafo (Bluetooth)".',
        'Permita "Aparelhos próximos" quando o Android perguntar.',
        'Toque em "Escolher tacógrafo" e escolha o DTCO-….',
        'Espere uns segundos: o estado passa a "Ligado" e no ecrã Hoje aparece o cartão Tacógrafo com os tempos (os dados chegam um a um, ~1 minuto para todos).',
      ]),
      ('Se não ligar', [
        'Confirme que a ignição está ligada (com ela desligada o Bluetooth do tacógrafo desliga).',
        'Feche outras apps ligadas ao tacógrafo: ele só aceita uma ligação de cada vez.',
        'Toque em "Tentar ligar". O app também volta a tentar sozinho a cada 30 s.',
        'Se continuar, desemparelhe o DTCO no Bluetooth do telemóvel e repita os passos.',
        'Em "Teste e registo" → "Partilhar registo" pode mandar o registo para análise.',
      ]),
      ('Importante', [
        'Caminho no DTCO 4.1 em português: OK → Entrada condutor 1 → Bluetooth → Emparelhamento. Noutros idiomas os nomes mudam.',
        'Sem ligação ao tacógrafo, o TacoGuard continua a funcionar pelo GPS como sempre.',
      ]),
    ],
    'en': [
      ('On the tachograph (VDO DTCO 4.1)', [
        'Truck stopped, ignition on and your card in slot 1.',
        'Press OK to open the menu.',
        'Press ▼ until "Input driver 1" and press OK.',
        'Press ▼ until "Bluetooth" and press OK.',
        'Choose "Pairing" and press OK. The tachograph becomes visible as DTCO-serial number.',
      ]),
      ('On the phone', [
        'Open Settings → Bluetooth and scan for devices.',
        'Tap DTCO-… (e.g. DTCO-20876740).',
        'A 6-digit code appears on the phone and on the tachograph. If they match, tap Pair on the phone and press OK on the tachograph.',
        'The DTCO now shows under "Paired devices". You only need to do this once.',
      ]),
      ('In TacoGuard', [
        'Settings → Tachograph: turn on "Connect to tachograph (Bluetooth)".',
        'Allow "Nearby devices" when Android asks.',
        'Tap "Choose tachograph" and pick the DTCO-….',
        'Wait a few seconds: the status becomes "Connected" and the Tachograph card appears on the Today screen (data arrives one item at a time, about 1 minute for all).',
      ]),
      ('If it does not connect', [
        'Check the ignition is on (with it off the tachograph Bluetooth switches off).',
        'Close other apps connected to the tachograph: it accepts only one connection at a time.',
        'Tap "Try to connect". The app also retries by itself every 30 s.',
        'If it still fails, unpair the DTCO in the phone Bluetooth settings and repeat the steps.',
        'In "Test and log" → "Share log" you can send the log for analysis.',
      ]),
      ('Important', [
        'Path on the DTCO 4.1: OK → Input driver 1 → Bluetooth → Pairing. Names change with the tachograph language.',
        'Without a tachograph connection, TacoGuard keeps working by GPS as always.',
      ]),
    ],
    'es': [
      ('En el tacógrafo (VDO DTCO 4.1)', [
        'Camión parado, contacto puesto y su tarjeta en la ranura 1.',
        'Pulse OK para abrir el menú.',
        'Pulse ▼ hasta "Entrada conductor 1" y pulse OK.',
        'Pulse ▼ hasta "Bluetooth" y pulse OK.',
        'Elija "Emparejamiento" y pulse OK. El tacógrafo queda visible como DTCO-número de serie.',
      ]),
      ('En el móvil', [
        'Abra Ajustes → Bluetooth y busque dispositivos.',
        'Toque DTCO-… (p. ej. DTCO-20876740).',
        'Aparece un código de 6 números en el móvil y en el tacógrafo. Si coinciden, toque Emparejar en el móvil y pulse OK en el tacógrafo.',
        'El DTCO queda en "Dispositivos emparejados". Solo hay que hacerlo una vez.',
      ]),
      ('En TacoGuard', [
        'Ajustes → Tacógrafo: active "Conectar al tacógrafo (Bluetooth)".',
        'Permita "Dispositivos cercanos" cuando Android lo pida.',
        'Toque "Elegir tacógrafo" y elija el DTCO-….',
        'Espere unos segundos: el estado pasa a "Conectado" y en la pantalla Hoy aparece la tarjeta Tacógrafo con los tiempos (los datos llegan uno a uno, ~1 minuto para todos).',
      ]),
      ('Si no conecta', [
        'Compruebe que el contacto está puesto (sin él, el Bluetooth del tacógrafo se apaga).',
        'Cierre otras apps conectadas al tacógrafo: solo acepta una conexión a la vez.',
        'Toque "Intentar conectar". La app también reintenta sola cada 30 s.',
        'Si sigue sin conectar, desempareje el DTCO en el Bluetooth del móvil y repita los pasos.',
        'En "Prueba y registro" → "Compartir registro" puede enviar el registro para análisis.',
      ]),
      ('Importante', [
        'Ruta en el DTCO 4.1: OK → Entrada conductor 1 → Bluetooth → Emparejamiento. Los nombres cambian según el idioma del tacógrafo.',
        'Sin conexión al tacógrafo, TacoGuard sigue funcionando por GPS como siempre.',
      ]),
    ],
    'fr': [
      ('Sur le chronotachygraphe (VDO DTCO 4.1)', [
        'Camion à l\'arrêt, contact mis et votre carte dans le lecteur 1.',
        'Appuyez sur OK pour ouvrir le menu.',
        'Appuyez sur ▼ jusqu\'à « Saisie conducteur 1 » et appuyez sur OK.',
        'Appuyez sur ▼ jusqu\'à « Bluetooth » et appuyez sur OK.',
        'Choisissez « Appairage » et appuyez sur OK. Le tachygraphe devient visible sous le nom DTCO-numéro de série.',
      ]),
      ('Sur le téléphone', [
        'Ouvrez Paramètres → Bluetooth et recherchez les appareils.',
        'Touchez DTCO-… (ex. : DTCO-20876740).',
        'Un code à 6 chiffres apparaît sur le téléphone et sur le tachygraphe. S\'ils sont identiques, touchez Appairer sur le téléphone et appuyez sur OK sur le tachygraphe.',
        'Le DTCO apparaît dans « Appareils associés ». À faire une seule fois.',
      ]),
      ('Dans TacoGuard', [
        'Réglages → Tachygraphe : activez « Se connecter au tachygraphe (Bluetooth) ».',
        'Autorisez « Appareils à proximité » quand Android le demande.',
        'Touchez « Choisir le tachygraphe » et choisissez le DTCO-….',
        'Attendez quelques secondes : l\'état passe à « Connecté » et la carte Tachygraphe apparaît sur l\'écran Aujourd\'hui (les données arrivent une par une, ~1 minute pour toutes).',
      ]),
      ('Si la connexion échoue', [
        'Vérifiez que le contact est mis (sans contact, le Bluetooth du tachygraphe s\'éteint).',
        'Fermez les autres applis connectées au tachygraphe : il n\'accepte qu\'une connexion à la fois.',
        'Touchez « Réessayer ». L\'appli réessaie aussi toute seule toutes les 30 s.',
        'Sinon, dissociez le DTCO dans le Bluetooth du téléphone et refaites les étapes.',
        'Dans « Test et journal » → « Partager le journal » vous pouvez envoyer le journal pour analyse.',
      ]),
      ('Important', [
        'Chemin sur le DTCO 4.1 : OK → Saisie conducteur 1 → Bluetooth → Appairage. Les noms changent selon la langue du tachygraphe.',
        'Sans connexion au tachygraphe, TacoGuard continue de fonctionner par GPS comme toujours.',
      ]),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final secs = _txt[langNotifier.value] ?? _txt['pt']!;
    final cs = Theme.of(context).colorScheme;
    var n = 0;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Como ligar (passo a passo)'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          for (final sec in secs) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(sec.$1,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: cs.primary)),
            ),
            for (final step in sec.$2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                          radius: 12,
                          backgroundColor: cs.primaryContainer,
                          child: Text('${++n}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onPrimaryContainer))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(step,
                              style: const TextStyle(fontSize: 15, height: 1.3))),
                    ]),
              ),
          ],
        ],
      ),
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

          if (_t.channels == 0)
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
        if (_t.didData.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Dados recebidos do tacógrafo'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final e in _t.didData.entries)
            Text('${TachoLink.dids[e.key] ?? e.key.toRadixString(16)}: ${TachoLink.pretty(e.key, e.value)}  (${TachoLink.hex(e.value)})',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () => TachoLink.I.resetBadDids(),
            child: Text(tr('Voltar a pedir todos os dados'))),
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


/// 1.11.8: cartão no ecrã Hoje com os tempos lidos do tacógrafo.
/// Só aparece com o tacógrafo ligado e a mandar dados.
class TachoLiveCard extends StatelessWidget {
  const TachoLiveCard({super.key});

  static Future<void> _askFortnight(BuildContext context) async {
    final t = TachoLink.I;
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Bissemanal')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Escreva a condução das 2 semanas que o tacógrafo mostra (menu do motorista 1, ex.: 67h12). Só é preciso uma vez: depois o app guarda as semanas sozinho.')),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(hintText: '67h12'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: Text(tr('Guardar'))),
        ],
      ),
    );
    if (v == null) return;
    final m = RegExp(r'(\d+)\D+(\d{1,2})').firstMatch(v.trim());
    final h = m != null ? int.parse(m.group(1)!) : int.tryParse(v.trim());
    if (h == null) return;
    final total = h * 60 + (m != null ? int.parse(m.group(2)!) : 0);
    final week = t.minutes(0xF99B) ?? 0;
    if (total < week || total > 90 * 60) return;
    await t.setPrevWeek(total - week);
  }

  /// Valor de uma linha: DID do tacógrafo, ou calculado (−1 bissemanal,
  /// −2 falta na semana, −3 falta em 2 semanas).
  static int? value(TachoLink t, int code) {
    final fn = t.fortnightDrive?.inMinutes;
    final leftFn = fn == null ? null : (90 * 60 - fn).clamp(0, 90 * 60);
    switch (code) {
      case -1:
        return fn;
      case -2:
        final wk = t.minutes(0xF99B);
        if (wk == null) return null;
        var l = 56 * 60 - wk;
        if (leftFn != null && leftFn < l) l = leftFn;
        return l.clamp(0, 56 * 60);
      case -3:
        return leftFn;
      default:
        // 1.14.3: dado com mais de 2 min não aparece (não fica parado).
        return t.fresh(code, seconds: 300) ? t.minutes(code) : null;
    }
  }

  static String _hm(int? m) =>
      m == null ? '—' : '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: TachoLink.I,
        builder: (context, _) {
          final t = TachoLink.I;
          if (!t.connected || t.didData.isEmpty) return const SizedBox(height: 0, width: 0);
          final st = t.workingState;
          final act = switch (st) {
            0 => tr('Descanso'),
            1 => tr('Disponibilidade'),
            2 => tr('Outro trabalho'),
            3 => tr('Condução'),
            _ => tr('à espera de dados'),
          };
          final rows = <(String, int)>[
            (tr('Condução contínua'), 0xF923),
            (tr('Pausa acumulada'), 0xF925),
            (tr('Atividade atual há'), 0xF927),
            (tr('Condução hoje'), 0xF99A),
            (tr('Condução na semana'), 0xF99B),
            (tr('Condução bissemanal'), -1), // 90 h − o que falta (F9B3)
            (tr('Falta conduzir na semana'), -2),
            (tr('Falta conduzir em 2 semanas'), -3),
            (tr('Até ao descanso diário'), 0xF99C),
            (tr('Até ao descanso semanal'), 0xF9A1),
          ];
          final cs = Theme.of(context).colorScheme;
          return Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.bluetooth_connected, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('${tr('Tacógrafo')}: $act',
                              style: const TextStyle(fontWeight: FontWeight.w800))),
                      if (t.live)
                        Text(tr('ao vivo'),
                            style: TextStyle(color: cs.primary, fontSize: 12)),
                      // 1.13.0: atalho para a tela de gráficos.
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: tr('Gráficos'),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                            backgroundColor: cs.primary.withValues(alpha: 0.15)),
                        icon: Icon(Icons.bar_chart_rounded, color: cs.primary),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ChartsPage())),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    // 1.12.6: bissemanal sem a semana passada: pedir ao
                    // motorista o total das 2 semanas que o DTCO mostra.
                    if (t.weekDrive != null && t.fortnightDrive == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: OutlinedButton.icon(
                          onPressed: () => _askFortnight(context),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: Text(tr('Indicar a bissemanal do tacógrafo')),
                        ),
                      ),
                    for (final r in rows)
                      if (value(t, r.$2) != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Expanded(child: Text(r.$1)),
                            Text(
                                _hm(value(t, r.$2)),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()])),
                          ]),
                        ),
                  ]),
            ),
          );
        },
      );
}
