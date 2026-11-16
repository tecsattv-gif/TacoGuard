import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'law.dart';
import 'models.dart';
import 'rules.dart';
import 'theme.dart';
import 'tracker.dart';

/// Pergunta pronta (funciona sem internet).
class Faq {
  final String q;
  final String a;
  final String ref;
  final List<String> keys;
  const Faq(this.q, this.a, this.ref, this.keys);
}

const List<Faq> kFaq = [
  Faq('Quanto tempo posso conduzir sem parar?',
      'No máximo 4h30. Depois é obrigatória a pausa de 45 minutos seguidos, '
          'ou dividida em 15 + 30 minutos (nesta ordem).',
      'Reg. 561/2006, art. 7.º',
      ['seguid', 'sem parar', '4h30', 'quatro horas', 'continua', '4 30']),
  Faq('Como funciona a pausa de 45 minutos?',
      'A pausa de 45 minutos pode ser feita de uma vez ou em duas partes: '
          'a primeira de pelo menos 15 minutos e a segunda de pelo menos '
          '30 minutos. A ordem não pode ser trocada (30 + 15 não vale). '
          'Martelo e carga/descarga não contam como pausa.',
      'Reg. 561/2006, art. 7.º',
      ['pausa', '45', '15', '30', 'dividir', 'dividida', 'parada']),
  Faq('Quantas horas posso conduzir por dia?',
      '9 horas. Duas vezes por semana pode chegar a 10 horas.',
      'Reg. 561/2006, art. 6.º, n.º 1',
      ['dia', 'diaria', 'diario', '9 horas', '10 horas', 'conduzir por dia']),
  Faq('Quantas horas posso conduzir por semana?',
      '56 horas na semana (segunda a domingo) e 90 horas em duas semanas '
          'seguidas. Se fez 56 numa semana, na seguinte só pode fazer 34.',
      'Reg. 561/2006, art. 6.º, n.os 2 e 3',
      ['semana', 'semanal', '56', '90', 'quinzena', 'duas semanas',
        'bissemanal']),
  Faq('O que é a amplitude? 13 ou 15 horas?',
      'É o tempo do início ao fim da jornada. Com descanso de 11 horas o '
          'máximo é 13 horas; com descanso reduzido de 9 horas pode chegar '
          'a 15 horas, no máximo 3 vezes entre dois descansos semanais.',
      'Reg. 561/2006, art. 8.º',
      ['amplitude', '13', '15', 'jornada', 'treze', 'quinze']),
  Faq('Quanto tempo de descanso diário?',
      'Regular: 11 horas seguidas (ou 3 + 9 horas). Reduzido: pelo menos '
          '9 horas, no máximo 3 vezes entre dois descansos semanais. O '
          'descanso tem de caber nas 24 horas depois do descanso anterior.',
      'Reg. 561/2006, art. 8.º',
      ['descanso diario', 'dormir', '11 horas', '9 horas', 'reduzido',
        'noite', 'descanso']),
  Faq('Como é o descanso semanal?',
      'Regular: 45 horas. Reduzido: 24 horas, com compensação do que '
          'faltou até o fim da 3.ª semana seguinte. Tem de começar no '
          'máximo 144 horas (6 dias) depois do descanso semanal anterior.',
      'Reg. 561/2006, art. 8.º, n.º 6',
      ['descanso semanal', '45 horas', '24 horas', 'fim de semana',
        'compensa', '144', 'seis dias']),
  Faq('Posso fazer o descanso de 45 horas na cabine?',
      'Não. O descanso semanal regular (45 horas ou mais) não pode ser '
          'feito no veículo; a empresa paga o alojamento. O diário e o '
          'semanal reduzido podem ser feitos na cabine com cama.',
      'Reg. 561/2006, art. 8.º, n.º 8',
      ['cabine', 'cabina', 'veiculo', 'hotel', 'alojamento', 'cama']),
  Faq('Martelo conta como pausa?',
      'Não. Martelo (outros trabalhos) e carga/descarga são trabalho. Só '
          'a pausa/descanso (cama) conta para os 45 minutos.',
      'Reg. 561/2006, art. 4.º e art. 7.º',
      ['martelo', 'outros trabalhos', 'carga', 'descarga', 'conta como']),
  Faq('Posso passar do tempo para chegar a um park?',
      'Pode, só o necessário para chegar a um local de paragem adequado e '
          'seguro, sem pôr em risco a segurança. Escreva o motivo à mão no '
          'talão do tacógrafo, o mais tardar ao chegar.',
      'Reg. 561/2006, art. 12.º',
      ['passar', 'exceder', 'park', 'estacionamento', 'talao', 'local seguro',
        'artigo 12']),
  Faq('Posso conduzir mais para chegar em casa?',
      'Em situação excecional, até 1 hora a mais para chegar a casa ou à '
          'base e fazer o descanso semanal; até 2 horas a mais se for o '
          'descanso semanal regular e fizer antes uma pausa de 30 minutos. '
          'Anote o motivo no talão e compense depois.',
      'Reg. 561/2006, art. 12.º',
      ['casa', 'base', 'uma hora a mais', 'duas horas', 'regressar',
        'voltar']),
  Faq('E no ferry ou no comboio?',
      'O descanso diário regular pode ser interrompido no máximo 2 vezes, '
          'somando até 1 hora, para embarcar e desembarcar, com acesso a '
          'cama.',
      'Reg. 561/2006, art. 9.º',
      ['ferry', 'barco', 'comboio', 'trem', 'balsa']),
  Faq('Quantos dias a polícia pode pedir?',
      'O dia atual e os 56 dias anteriores.',
      'Reg. (UE) n.º 165/2014, art. 36.º',
      ['dias', 'policia', 'fiscalizacao', '56 dias', '28 dias', 'controle',
        'controlo']),
  Faq('E com dois motoristas?',
      'Cada um faz um descanso diário de pelo menos 9 horas dentro das '
          '30 horas depois do descanso anterior.',
      'Reg. 561/2006, art. 8.º, n.º 5',
      ['dois motoristas', 'dupla', 'tripulacao', 'equipe', '30 horas']),
  Faq('Quanto tempo posso trabalhar sem pausa (martelo)?',
      'Não mais de 6 horas seguidas de trabalho sem pausa. De 6 a 9 horas '
          'de trabalho: 30 minutos de pausa; mais de 9 horas: 45 minutos.',
      'Diretiva 2002/15/CE, art. 5.º',
      ['trabalhar', 'trabalho', '6 horas', 'seis horas', '48', '60']),
  Faq('Como o TacoGuard sabe que parei?',
      'Pelo GPS. Depois de alguns minutos parado (você escolhe o tempo em '
          'Ajustes) ele grava o local e pergunta: Pausa, Martelo ou '
          'Carga/Descarga. Sem resposta, a parada fica "a classificar" e '
          'conta como pausa até você corrigir.',
      'Ajuda do app',
      ['app', 'tacoguard', 'gps', 'parei', 'pop-up', 'popup', 'classificar']),
];

/// Melhor resposta pronta para [question], ou null.
Faq? faqMatch(String question) {
  final q = norm(question);
  Faq? best;
  var bestScore = 0;
  for (final f in kFaq) {
    var score = 0;
    for (final k in f.keys) {
      if (q.contains(norm(k))) score += k.length > 4 ? 2 : 1;
    }
    if (score > bestScore) {
      bestScore = score;
      best = f;
    }
  }
  return bestScore >= 2 ? best : null;
}

/// Chave do Gemini embutida no build (segredo GEMINI_API_KEY do GitHub).
const _geminiKey = String.fromEnvironment('GEMINI_KEY');
bool get aiAvailable => _geminiKey.trim().isNotEmpty;

const _models = [
  'gemini-flash-latest',
  'gemini-flash-lite-latest',
  'gemini-2.5-flash',
];

/// Situação atual do motorista, para a IA poder responder "quanto falta".
String _situation() {
  final t = Tracker.I;
  final c = t.current;
  if (c == null) return 'Jornada fechada no momento.';
  final now = DateTime.now();
  final st = computeStatus(t.shifts, c, now);
  return 'Jornada aberta às ${fmtTime(c.start)}. '
      'Atividade atual: ${actLabel(t.currentAct ?? Act.unknown)}. '
      'Condução contínua: ${fmtDur(st.brk.driven)} de 4h30. '
      'Condução hoje: ${fmtDur(st.dayDrive)}. '
      'Amplitude: ${fmtDur(st.amplitude)}. '
      'Condução na semana: ${fmtDur(st.weekDrive)} de 56h. '
      'Em duas semanas: ${fmtDur(st.fortnightDrive)} de 90h. '
      'Descansos reduzidos usados: ${st.reducedRestsUsed} de 3.';
}

Future<String> askGemini(String question) async {
  final system = 'Você é o assistente do app TacoGuard, para motoristas de '
      'caminhão na Europa. Responda em português do Brasil, curto e '
      'direto. Responda SOMENTE com base no resumo da lei abaixo e na '
      'situação do motorista. Cite sempre o artigo entre parênteses. Se a '
      'resposta não estiver no resumo, diga que não sabe e mande conferir '
      'o regulamento. Não responda assuntos fora da lei do tacógrafo e do '
      'app.\n\nRESUMO DA LEI:\n${lawAsText()}\n'
      'SITUAÇÃO DO MOTORISTA AGORA:\n${_situation()}';
  int? lastStatus;
  for (final model in _models) {
    final r = await http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/'
              'openai/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_geminiKey.trim()}',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0.2,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': question},
            ],
          }),
        )
        .timeout(const Duration(seconds: 40));
    lastStatus = r.statusCode;
    if (r.statusCode == 200) {
      final m = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      final choices = (m['choices'] as List?) ?? [];
      if (choices.isNotEmpty) {
        final msg = (choices.first as Map)['message'] as Map?;
        final text = msg?['content']?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
    }
    // 404 = modelo não existe mais; 429 = cota deste modelo: tenta o próximo.
    if (r.statusCode != 404 && r.statusCode != 429 && r.statusCode != 503) {
      break;
    }
  }
  if (lastStatus == 429) {
    throw Exception('O limite gratuito da IA acabou por agora. Tente mais '
        'tarde ou use a consulta offline.');
  }
  throw Exception('A IA não respondeu (erro $lastStatus).');
}

class _Msg {
  final String text;
  final bool mine;
  final String? ref;
  final String? tag;
  const _Msg(this.text, this.mine, {this.ref, this.tag});
}

/// Tela "Consulta": perguntas prontas offline e IA (Gemini).
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _useAi = aiAvailable;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _down() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  void _offline(String q) {
    final f = faqMatch(q);
    if (f != null) {
      _msgs.add(_Msg(f.a, false, ref: f.ref, tag: 'Offline'));
    } else {
      _msgs.add(const _Msg(
          'Não encontrei essa resposta nas perguntas prontas. Veja o menu '
          '"Lei" ou tente com outras palavras (ex.: pausa, descanso, '
          'amplitude, semana).',
          false,
          tag: 'Offline'));
    }
  }

  Future<void> _send([String? text]) async {
    final q = (text ?? _ctrl.text).trim();
    if (q.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg(q, true));
      _busy = true;
    });
    _down();
    if (_useAi && aiAvailable) {
      try {
        final a = await askGemini(q);
        _msgs.add(_Msg(a, false, tag: 'IA'));
      } catch (e) {
        // Sem internet ou sem cota: cai para a resposta pronta.
        final f = faqMatch(q);
        if (f != null) {
          _msgs.add(_Msg(f.a, false, ref: f.ref, tag: 'Offline'));
        } else {
          _msgs.add(_Msg(
              e.toString().replaceFirst('Exception: ', '').contains('IA')
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'Sem conexão com a IA. Tente a consulta offline.',
              false,
              tag: 'IA'));
        }
      }
    } else {
      _offline(q);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _down();
  }

  Widget _bubble(_Msg m) {
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: m.mine ? TG.accent.withValues(alpha: 0.18) : TG.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: m.mine ? TG.accent : TG.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.tag != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(m.tag!,
                    style: const TextStyle(
                        color: TG.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            SelectableText(m.text,
                style: const TextStyle(fontSize: 15, height: 1.35)),
            if (m.ref != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(m.ref!,
                    style: const TextStyle(color: TG.muted, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SegmentedButton<bool>(
            segments: [
              const ButtonSegment(
                  value: false,
                  icon: Icon(Icons.offline_bolt_rounded),
                  label: Text('Offline')),
              ButtonSegment(
                  value: true,
                  enabled: aiAvailable,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(aiAvailable ? 'IA' : 'IA (sem chave)')),
            ],
            selected: {_useAi},
            onSelectionChanged: (s) => setState(() => _useAi = s.first),
          ),
        ),
        Expanded(
          child: _msgs.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    const Text('Perguntas frequentes',
                        style: TextStyle(
                            color: TG.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final f in kFaq)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          onTap: () => _send(f.q),
                          child: Row(children: [
                            Expanded(
                                child: Text(f.q,
                                    style: const TextStyle(fontSize: 15))),
                            const Icon(Icons.chevron_right_rounded,
                                color: TG.muted),
                          ]),
                        ),
                      ),
                  ],
                )
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    for (final m in _msgs) _bubble(m),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5)),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'A resposta é uma ajuda. Confira sempre o artigo: '
                      'o que vale é a lei e o tacógrafo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TG.muted, fontSize: 11),
                    ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              if (_msgs.isNotEmpty)
                IconButton(
                  tooltip: 'Nova consulta',
                  onPressed: () => setState(() => _msgs.clear()),
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                      hintText: 'Pergunte sobre a lei do tacógrafo'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : () => _send(),
                style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14)),
                child: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
