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
  LawTopic('Gravidade das infrações (multas)',
      'Diretiva 2006/22/CE, anexo III; Reg. (UE) 2016/403',
      Icons.gavel_rounded, [
    'Escalões: leve (MI), grave (SI), muito grave (VSI) e gravíssima '
        '(MSI). A gravidade é igual em toda a UE; o valor da multa é cada '
        'país que fixa.',
    'Duas semanas (limite 90 h): até menos de 100 h leve; 100 a 105 h '
        'grave; 105 a 112h30 muito grave; 112h30 ou mais gravíssima.',
    'Semana (limite 56 h): até menos de 60 h leve; 60 a 65 h grave; 65 a '
        '70 h muito grave; 70 h ou mais gravíssima.',
    'Condução contínua (limite 4h30): até 5 h leve; 5 a 6 h grave; mais '
        'de 6 h muito grave.',
    'Condução diária: 13h30 (dia de 9 h) ou 15 h (dia de 10 h) sem pausa '
        'nem descanso de 4h30 é gravíssima.',
    'Na fiscalização podem ser multadas as infrações do dia atual e dos '
        '56 dias anteriores, mesmo que tenham sido noutro país.',
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
  LawTopic('Cartão de motorista: obrigações e cuidados',
      'Reg. (UE) n.º 165/2014, art. 26.º a 29.º, 32.º, 34.º e 35.º',
      Icons.credit_card_rounded, [
    'O cartão é pessoal e só pode haver um: cada motorista tem um único '
        'cartão válido, emitido pelo país onde mora habitualmente. Vale '
        '5 anos.',
    'CERTO: meter o cartão antes de mexer o caminhão (mesmo para '
        'manobrar) e deixá-lo durante todo o trabalho do dia, pausas '
        'incluídas.',
    'CERTO: ao meter o cartão, fazer a entrada manual de todo o tempo '
        'fora do caminhão (cama, martelo ou quadrado). Não pode haver '
        'períodos em branco.',
    'CERTO: ao trocar de caminhão no mesmo dia, tirar o cartão do '
        'primeiro e metê-lo no segundo, com a entrada manual do tempo entre '
        'os dois.',
    'CERTO: ter o cartão sempre consigo durante a viagem e mostrá-lo na '
        'fiscalização, com os talões e registos manuais do dia e dos 56 '
        'dias anteriores.',
    'CERTO: pedir a renovação pelo menos 15 dias úteis antes de acabar a '
        'validade; pedir um cartão novo em 7 dias se for perdido, roubado ou '
        'avariado.',
    'ERRADO (infração muito grave ou crime): usar o cartão de outro, '
        'emprestar o seu, ter dois cartões, usar cartão falso, alterado ou '
        'caducado.',
    'ERRADO: conduzir sem cartão (por exemplo, esquecido em casa), tirar o '
        'cartão na pausa para "limpar" o tempo, ou fazer entradas manuais '
        'falsas.',
    'ERRADO: deixar o cartão com a empresa ou no caminhão para outro usar. '
        'A empresa pode descarregá-lo, mas não pode ficar com ele.',
    'Cuidados: guardar numa capa, longe do sol, do calor (tablier no '
        'verão), de ímanes e da humidade; não dobrar, riscar nem colar nada '
        'no chip. Se estiver sujo, limpar o chip só com pano seco e macio.',
    'O cartão guarda pelo menos 28 dias de atividades; depois os mais '
        'antigos são escritos por cima. Por isso a empresa tem de o '
        'descarregar a cada 28 dias no máximo.',
    'O cartão de motorista não tem PIN. Quem tem PIN é o cartão da '
        'empresa, da oficina e da polícia.',
  ]),
  LawTopic('Usar o tacógrafo passo a passo (VDO)',
      'Reg. (UE) n.º 165/2014, art. 34.º; manual do tacógrafo',
      Icons.play_circle_rounded, [
    'Começar o dia: caminhão parado, cartão na ranhura 1, entrada manual '
        'do tempo fora (normalmente cama), país de início, confirmar. Depois '
        'martelo para a verificação e arrancar: a condução é automática.',
    'Mudar a atividade: caminhão parado, tecla 1 até aparecer o símbolo '
        '(martelo, quadrado ou cama). Na pausa ponha sempre a cama.',
    'Ao desligar a ignição o tacógrafo pode pôr martelo sozinho: confira o '
        'visor a cada paragem.',
    'Fronteira: os tacógrafos da 2.ª versão gravam sozinhos; nos antigos '
        'marque o país na primeira paragem depois da fronteira.',
    'Carga/descarga (2.ª versão): OK > Entrada veículo > Carga/descarga.',
    'Ferry/comboio: OK > Entrada veículo > Ferry/comboio início, e cama.',
    'Acabar o dia: segure a tecla 1 mais de 2 segundos, escolha o país de '
        'fim, confirme e, se quiser, imprima o dia.',
    'Talão do dia: OK > Imprimir condutor 1 > 24h dia > data > OK (em UTC).',
    'Leve sempre rolos de papel de reserva. Mesmo para manobrar, meta o '
        'cartão.',
    'Os nomes dos menus mudam um pouco entre marcas e versões; veja o '
        'manual do seu aparelho.',
  ]),
  LawTopic('Função OUT (fora do âmbito)',
      'Reg. 561/2006, art. 3.º e art. 13.º; Reg. (UE) n.º 165/2014',
      Icons.do_not_disturb_on_rounded, [
    'OUT quer dizer "out of scope": condução fora do âmbito da lei do '
        'tacógrafo. Serve só para transportes que a lei não obriga a '
        'registar (isenções do art. 3.º e isenções nacionais do art. 13.º).',
    'Não serve para viagens normais: ir vazio carregar, ir à oficina ou '
        'voltar à base também é condução e conta para os limites.',
    'Ligar (VDO): caminhão parado, carregue em OK, vá com as setas até '
        '"Entrada veículo", OK, escolha "OUT início" e confirme com OK.',
    'Desligar: "Entrada veículo" > "OUT fim" > OK. O OUT também acaba '
        'sozinho quando o cartão é metido ou tirado.',
    'Noutras marcas (Stoneridge, Intellic) o caminho é parecido, no menu '
        'de entradas do veículo; veja o manual do aparelho.',
    'Com OUT ligado, o visor mostra o símbolo OUT. O tacógrafo continua a '
        'gravar; a condução fica marcada como fora do âmbito.',
    'Condução em OUT para a empresa conta como outros trabalhos (martelo) '
        'no tempo de trabalho. No TacoGuard, corrija esse trecho para '
        'martelo no Histórico.',
    'Usar OUT sem ter direito é infração e pode ser tratado como registo '
        'falso. Na dúvida, não use e pergunte à empresa.',
  ]),
  LawTopic('Mudar a hora no tacógrafo (hora local e UTC)',
      'Reg. (UE) n.º 165/2014; manual do tacógrafo',
      Icons.schedule_rounded, [
    'O tacógrafo grava sempre em hora UTC. O que o motorista muda é só a '
        'hora local que aparece no visor; registos e talões continuam em '
        'UTC.',
    'Portugal e Reino Unido: inverno = UTC, verão = UTC + 1. Espanha, '
        'França, Alemanha e quase toda a Europa central: inverno = UTC + 1, '
        'verão = UTC + 2.',
    'A hora muda no último domingo de março (adianta 1 h) e no último '
        'domingo de outubro (atrasa 1 h).',
    'Passos (VDO): 1. Caminhão parado. 2. Carregue em OK. 3. Com as setas '
        'vá até "Entrada veículo" e carregue em OK. 4. Escolha "Hora local" '
        'e OK. 5. Com as setas mude a hora em passos de 30 minutos. '
        '6. Confirme com OK e saia com a tecla de voltar.',
    'Ao passar para um país com outro fuso pode fazer o mesmo: muda só o '
        'visor, a gravação não muda.',
    'Com o caminhão a andar o menu não abre. Faça sempre parado.',
    'Se a hora UTC estiver errada, quem acerta é a oficina autorizada. '
        'Alguns modelos antigos deixam o motorista corrigir até 1 minuto '
        'por semana ("Correção UTC").',
    'No TacoGuard não precisa mudar nada: usa a hora do telefone e conta '
        'a semana em UTC, como o tacógrafo.',
  ]),
  LawTopic('Como o TacoGuard conta os tempos', 'Uso do app',
      Icons.speed_rounded, [
    'A jornada começa só quando você toca em "Iniciar jornada". Depois o '
        'GPS faz o resto.',
    'A condução começa sozinha quando o caminhão arranca. A parada é '
        'detectada sozinha quando ele fica parado o tempo escolhido em '
        'Ajustes. Como no tacógrafo, a parada começa em MARTELO, sem '
        'pergunta: no trânsito, parado, o tacógrafo continua em martelo até '
        'você mudar para pausa.',
    'Aos 15 minutos parado (quando a parada já pode contar como pausa) '
        'aparece o pop-up perguntando se é pausa. Ao escolher Pausa ou '
        'Carga/Descarga, a parada muda desde a hora em que parou. Sem '
        'resposta continua martelo; pode corrigir depois no Histórico. '
        'Também pode mudar logo no cartão "Martelo automático" da tela Hoje.',
    'Cada parada, pausa e descanso fica gravado com o local (coordenadas).',
    'Se for sair de carro numa parada, toque em "Vou sair de carro": o '
        'movimento não conta como condução e a parada continua.',
    'Se encerrou a jornada e surgiu viagem de última hora, use "Reabrir a '
        'jornada": a contagem continua de onde parou.',
    'Na tela Hoje, a faixa colorida mostra o dia: azul condução, verde '
        'pausa, amarelo martelo, laranja carga/descarga e cinza o que ainda '
        'não foi classificado.',
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
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
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
