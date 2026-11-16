import 'package:flutter/material.dart';

import 'theme.dart';

/// Um tema da lei, em linguagem simples, com o artigo de onde vem.
class LawTopic {
  final String title;
  final String ref;
  final IconData icon;
  final List<String> points;
  const LawTopic(this.title, this.ref, this.icon, this.points);
}

/// Resumo do Regulamento (CE) n.º 561/2006 (com as alterações do
/// Regulamento (UE) 2020/1054) para transporte de mercadorias.
const List<LawTopic> kLaw = [
  LawTopic('Condução diária', 'Reg. 561/2006, art. 6.º, n.º 1',
      Icons.local_shipping_rounded, [
    'O tempo de condução diário não pode passar de 9 horas.',
    'Pode ser de 10 horas, no máximo 2 vezes por semana.',
    'Conta toda a condução entre dois descansos (diário ou semanal).',
  ]),
  LawTopic('Condução semanal e em duas semanas',
      'Reg. 561/2006, art. 6.º, n.os 2 e 3', Icons.date_range_rounded, [
    'Na semana (segunda 00:00 a domingo 24:00) o máximo é de 56 horas de '
        'condução.',
    'Em duas semanas seguidas o máximo é de 90 horas de condução.',
    'Exemplo: se numa semana fez 56 horas, na seguinte só pode fazer 34.',
    'O tacógrafo conta a semana em hora UTC; o TacoGuard faz igual.',
  ]),
  LawTopic('Pausas', 'Reg. 561/2006, art. 7.º', Icons.free_breakfast_rounded, [
    'Depois de 4h30 de condução é obrigatória uma pausa de pelo menos '
        '45 minutos seguidos, a não ser que comece um descanso.',
    'A pausa pode ser dividida em duas: primeiro uma de pelo menos '
        '15 minutos e depois uma de pelo menos 30 minutos, nesta ordem, '
        'dentro das 4h30.',
    'Pausa é só para descansar. Martelo (outros trabalhos) e '
        'carga/descarga não contam como pausa.',
    'Depois de uma pausa completa (45, ou 15 + 30) começa uma nova '
        'contagem de 4h30.',
  ]),
  LawTopic('Descanso diário', 'Reg. 561/2006, art. 4.º, al. g), e art. 8.º',
      Icons.hotel_rounded, [
    'Em cada período de 24 horas depois do fim do descanso anterior tem '
        'de haver um novo descanso diário.',
    'Descanso regular: pelo menos 11 horas seguidas.',
    'Descanso dividido: 3 horas seguidas + 9 horas seguidas (12 no total), '
        'nesta ordem.',
    'Descanso reduzido: pelo menos 9 horas e menos de 11. Só pode ser '
        'feito 3 vezes entre dois descansos semanais.',
    'O descanso pode ser feito no veículo, se tiver cama e estiver parado.',
  ]),
  LawTopic('Amplitude (13 h ou 15 h)',
      'Consequência do art. 8.º (24 h menos o descanso)',
      Icons.timelapse_rounded, [
    'A amplitude é o tempo do início ao fim da jornada: condução, martelo, '
        'pausas, tudo conta.',
    'Com descanso de 11 horas, a amplitude máxima é de 13 horas '
        '(24 - 11).',
    'Com descanso reduzido de 9 horas, a amplitude pode chegar a 15 horas '
        '(24 - 9), no máximo 3 vezes entre dois descansos semanais.',
    'Passou de 13 horas? O descanso dessa noite já conta como reduzido.',
  ]),
  LawTopic('Descanso semanal', 'Reg. 561/2006, art. 8.º, n.os 6 a 8-A',
      Icons.weekend_rounded, [
    'Regular: pelo menos 45 horas seguidas. Reduzido: pelo menos 24 horas.',
    'Em duas semanas seguidas: dois descansos regulares, ou um regular e '
        'um reduzido.',
    'O que faltou no reduzido (até 45 h) tem de ser compensado de uma vez, '
        'junto a outro descanso de pelo menos 9 horas, até o fim da 3.ª '
        'semana seguinte.',
    'O descanso semanal tem de começar, no máximo, ao fim de seis períodos '
        'de 24 horas (144 horas) depois do descanso semanal anterior.',
    'O descanso semanal regular (45 h ou mais) não pode ser feito dentro '
        'do veículo; a empresa paga o alojamento.',
    'Em transporte internacional de mercadorias podem ser feitos dois '
        'descansos reduzidos seguidos fora do país da empresa, desde que em '
        '4 semanas haja 4 descansos semanais, 2 deles regulares.',
    'A empresa tem de organizar o trabalho para o motorista voltar a casa '
        'ou à base pelo menos a cada 4 semanas.',
  ]),
  LawTopic('Dois motoristas (tripulação múltipla)',
      'Reg. 561/2006, art. 8.º, n.º 5', Icons.groups_rounded, [
    'Com dois motoristas, cada um tem de fazer um descanso diário de pelo '
        'menos 9 horas dentro das 30 horas depois do descanso anterior.',
    'O TacoGuard controla um motorista só.',
  ]),
  LawTopic('Ferry e comboio', 'Reg. 561/2006, art. 9.º',
      Icons.directions_boat_rounded, [
    'Ao acompanhar o veículo em ferry ou comboio, o descanso diário '
        'regular pode ser interrompido no máximo 2 vezes, somando até '
        '1 hora, para embarcar e desembarcar.',
    'É preciso ter acesso a cama ou beliche durante o descanso.',
  ]),
  LawTopic('Exceções para chegar a um local seguro ou a casa',
      'Reg. 561/2006, art. 12.º', Icons.report_problem_rounded, [
    'Para chegar a um local de paragem adequado, pode passar dos limites '
        'o necessário para garantir a segurança das pessoas, do veículo e '
        'da carga, sem pôr em risco a segurança rodoviária.',
    'Em situação excecional, pode conduzir até 1 hora a mais para chegar '
        'à base ou a casa e fazer o descanso semanal.',
    'Pode conduzir até 2 horas a mais para fazer o descanso semanal '
        'regular em casa ou na base, desde que faça antes uma pausa de '
        '30 minutos seguidos.',
    'A hora ou as 2 horas a mais valem para a condução diária e semanal. '
        'O limite de 90 horas em duas semanas não pode ser passado.',
    'A hora ou as 2 horas a mais servem só para ir fazer o descanso '
        'semanal em casa ou na base. Num dia normal só pode passar o '
        'necessário para chegar a um local de paragem seguro.',
    'Tem de escrever o motivo à mão no talão (impressão) do tacógrafo, o '
        'mais tardar ao chegar. A hora ou as 2 horas a mais são '
        'compensadas com o mesmo tempo de descanso, de uma só vez, junto a '
        'outro descanso, até o fim da 3.ª semana seguinte.',
    'É uma exceção para o que não dava para prever (park cheio, acidente, '
        'estrada cortada, mau tempo). Não serve para viagem mal planeada '
        'nem pode ser usada sempre; o agente avalia caso a caso.',
  ]),
  LawTopic('Como anotar no talão quando passa do tempo',
      'Reg. 561/2006, art. 12.º (procedimento)', Icons.receipt_long_rounded, [
    '1. Siga só até o primeiro local de paragem adequado e seguro (park, '
        'área de serviço, zona industrial). Não pare em sítio perigoso.',
    '2. Logo ao parar, imprima o talão do dia: menu do tacógrafo, '
        'Impressão > Condutor 1 > Dia (24 h).',
    '3. Atrás do talão escreva à mão o motivo. Exemplo: "Park da A1 km 120 '
        'cheio, sem lugar seguro. Segui até a área de serviço seguinte."',
    '4. Escreva também o local onde parou, a data e a hora de chegada.',
    '5. Escreva a lei: "Art. 12.º do Regulamento (CE) n.º 561/2006".',
    '6. Ponha o nome e assine.',
    '7. Faça a pausa ou o descanso completo. Guarde o talão: pode ser '
        'pedido na estrada no próprio dia e nos 56 dias seguintes; depois '
        'entregue à empresa.',
    'A lei obriga a escrever o motivo; o local, a hora, o artigo e a '
        'assinatura são boa prática para não haver dúvida na fiscalização.',
    'Para chegar a casa ou à base com a hora (ou as 2 horas) a mais o '
        'procedimento é o mesmo: talão impresso ao chegar, motivo atrás e '
        'assinatura.',
  ]),
  LawTopic('Tempo de trabalho', 'Diretiva 2002/15/CE',
      Icons.construction_rounded, [
    'Não se pode trabalhar mais de 6 horas seguidas sem pausa.',
    'Trabalho de 6 a 9 horas no dia: pausa de pelo menos 30 minutos. '
        'Mais de 9 horas: pelo menos 45 minutos. Podem ser divididas em '
        'partes de 15 minutos.',
    'Média de 48 horas de trabalho por semana (condução + martelo), '
        'podendo chegar a 60 numa semana.',
    'Com trabalho noturno, o máximo é de 10 horas de trabalho em cada '
        '24 horas.',
  ]),
  LawTopic('Tacógrafo e fiscalização', 'Reg. (UE) n.º 165/2014',
      Icons.fact_check_rounded, [
    'Selecione sempre a atividade certa: condução, outros trabalhos '
        '(martelo), disponibilidade ou pausa/descanso.',
    'Na fiscalização o motorista mostra o dia atual e os 56 dias '
        'anteriores (cartão, talões e registos manuais).',
    'O cartão de motorista é pessoal: nunca conduza com o cartão de outro.',
    'As multas mudam de país para país. O TacoGuard é um auxiliar: o que '
        'vale na estrada é o registo do tacógrafo.',
  ]),
];

/// Tela "Lei do tacógrafo": temas com busca.
class LawPage extends StatefulWidget {
  const LawPage({super.key});
  @override
  State<LawPage> createState() => _LawPageState();
}

String norm(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  var o = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    o = o.replaceAll(from[i], to[i]);
  }
  return o;
}

class _LawPageState extends State<LawPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = norm(_q.trim());
    final list = kLaw.where((t) {
      if (q.isEmpty) return true;
      if (norm(t.title).contains(q)) return true;
      return t.points.any((p) => norm(p).contains(q));
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
            hintText: 'Buscar na lei (ex.: pausa, 45, semanal)',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nada encontrado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TG.muted)),
          ),
        for (final t in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: q.isNotEmpty,
                  leading: Icon(t.icon, color: TG.accent),
                  title: Text(t.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  subtitle: Text(t.ref,
                      style:
                          const TextStyle(color: TG.muted, fontSize: 12)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    for (final p in t.points)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 7, right: 10),
                              child: CircleAvatar(
                                  radius: 3, backgroundColor: TG.accent),
                            ),
                            Expanded(
                              child: Text(p,
                                  style: const TextStyle(
                                      fontSize: 15, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          'Resumo do Regulamento (CE) n.º 561/2006, com as alterações do '
          'Regulamento (UE) 2020/1054. Não substitui o texto oficial nem o '
          'tacógrafo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: TG.muted, fontSize: 12),
        ),
      ],
    );
  }
}

/// Todo o resumo em texto (vai para a IA como base das respostas).
String lawAsText() {
  final b = StringBuffer();
  for (final t in kLaw) {
    b.writeln('## ${t.title} (${t.ref})');
    for (final p in t.points) {
      b.writeln('- $p');
    }
    b.writeln();
  }
  return b.toString();
}
