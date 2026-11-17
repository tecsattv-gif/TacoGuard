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

/// Grupo de perguntas prontas (um assunto).
class FaqGroup {
  final String title;
  final IconData icon;
  final List<Faq> items;
  const FaqGroup(this.title, this.icon, this.items);
}

const _r561 = 'Reg. 561/2006';
const _a12 = 'Reg. 561/2006, art. 12.º';
const _r165 = 'Reg. (UE) n.º 165/2014';
const _app = 'Ajuda do app';

const List<FaqGroup> kFaqGroups = [
  // ------------------------------------------------------------ Condução
  FaqGroup('Condução', Icons.local_shipping_rounded, [
    Faq('Quanto tempo posso conduzir sem parar?',
        'No máximo 4h30. Depois é obrigatória a pausa de 45 minutos seguidos, '
            'ou dividida em 15 + 30 minutos (nesta ordem).',
        '$_r561, art. 7.º',
        ['seguid', 'sem parar', '4h30', 'quatro horas', 'continua', '4 30']),
    Faq('Quantas horas posso conduzir por dia?',
        '9 horas. Duas vezes por semana pode chegar a 10 horas. Conta toda '
            'a condução entre dois descansos (diário ou semanal).',
        '$_r561, art. 6.º, n.º 1',
        ['diaria', 'conduzir por dia', 'conducao diaria', 'por dia']),
    Faq('Quantas vezes posso fazer 10 horas de condução?',
        'Duas vezes em cada semana (segunda 00:00 a domingo 24:00). Nos '
            'outros dias o máximo é de 9 horas.',
        '$_r561, art. 6.º, n.º 1',
        ['10 horas', 'dez horas', 'quantas vezes', 'esticar']),
    Faq('Para conduzir 10 horas, quantas pausas preciso?',
        'Duas pausas completas: uma de 45 minutos (ou 15 + 30) depois das '
            'primeiras 4h30 e outra de 45 minutos (ou 15 + 30) depois de '
            'mais 4h30, antes de fazer a última hora.',
        '$_r561, art. 6.º e art. 7.º',
        ['quantas pausas', 'segunda pausa', 'ultima hora', 'duas pausas']),
    Faq('Quantas horas posso conduzir por semana?',
        '56 horas na semana (segunda a domingo) e 90 horas em duas semanas '
            'seguidas. Se fez 56 numa semana, na seguinte só pode fazer 34.',
        '$_r561, art. 6.º, n.os 2 e 3',
        ['semanal', '56', 'conduzir por semana', 'conducao semanal']),
    Faq('Como contam as 90 horas em duas semanas?',
        'Somam-se sempre duas semanas seguidas: a semana passada com esta, '
            'e esta com a próxima. Nenhuma dessas somas pode passar de '
            '90 horas. O artigo 12.º não permite passar das 90 horas.',
        '$_r561, art. 6.º, n.º 3',
        ['90', 'noventa', 'quinzena', 'duas semanas', 'bissemanal']),
    Faq('Quando começa e quando acaba a semana?',
        'Começa na segunda-feira às 00:00 e acaba no domingo às 24:00. O '
            'tacógrafo conta em hora UTC, e o TacoGuard faz igual (em '
            'Portugal no inverno é a mesma hora; em Espanha, França ou '
            'Alemanha é 1 hora a menos no inverno e 2 no verão).',
        '$_r561, art. 4.º, al. i)',
        ['comeca a semana', 'acaba a semana', 'utc', 'segunda-feira',
          'domingo', 'meia-noite']),
    Faq('Posso trabalhar 6 dias seguidos?',
        'Pode. O descanso semanal tem de começar, no máximo, ao fim de seis '
            'períodos de 24 horas (144 horas) depois do fim do descanso '
            'semanal anterior. Sétimo dia seguido de trabalho não pode.',
        '$_r561, art. 8.º, n.º 6',
        ['6 dias', 'seis dias', 'dias seguidos', 'setimo dia', '7 dias']),
    Faq('Uma manobra pequena conta como condução?',
        'Conta. O tacógrafo regista como condução qualquer movimento do '
            'veículo, mesmo curto. E mexer o caminhão interrompe a pausa ou '
            'o descanso que estava a fazer.',
        '$_r561, art. 4.º, al. j)',
        ['manobra', 'mexer', 'mudar de lugar', 'andar um pouco', 'metros']),
    Faq('Parado no trânsito ou na fila conta como pausa?',
        'Não. Parado no trânsito, o tacógrafo passa sozinho para martelo '
            '(outros trabalhos), que é trabalho e não pausa. No TacoGuard, '
            'paragens mais curtas que o tempo escolhido em Ajustes ficam '
            'como condução (trânsito).',
        '$_r561, art. 4.º, al. d)',
        ['transito', 'engarrafamento', 'fila parada', 'semaforo']),
  ]),

  // -------------------------------------------------------------- Pausas
  FaqGroup('Pausas', Icons.free_breakfast_rounded, [
    Faq('Como funciona a pausa de 45 minutos?',
        'A pausa de 45 minutos pode ser feita de uma vez ou em duas partes: '
            'a primeira de pelo menos 15 minutos e a segunda de pelo menos '
            '30 minutos. A ordem não pode ser trocada (30 + 15 não vale). '
            'Martelo e carga/descarga não contam como pausa.',
        '$_r561, art. 7.º',
        ['pausa de 45', '45 minutos', 'dividir a pausa', 'dividida']),
    Faq('Posso fazer a pausa de 30 primeiro e a de 15 depois?',
        'Não. A ordem é obrigatória: primeiro a de pelo menos 15 minutos, '
            'depois a de pelo menos 30. Se fez 30 e depois 15, a pausa não '
            'está completa: precisa de mais uma de 30 minutos.',
        '$_r561, art. 7.º',
        ['30 primeiro', '30 + 15', '30+15', 'ordem trocada', 'trocar a ordem',
          '30 e depois 15']),
    Faq('Posso fazer três pausas de 15 minutos?',
        'Não. Três de 15 não valem como pausa de 45. Só vale 45 de uma vez, '
            'ou uma de pelo menos 15 seguida de uma de pelo menos 30.',
        '$_r561, art. 7.º',
        ['tres pausas', '15 + 15', '15+15', 'tres de 15', '3 pausas']),
    Faq('Uma pausa de 20 ou 25 minutos conta?',
        'Conta como a primeira parte (pelo menos 15 minutos). Depois ainda '
            'falta uma de pelo menos 30 minutos, antes de completar 4h30 de '
            'condução. Pausa com menos de 15 minutos não conta para nada.',
        '$_r561, art. 7.º',
        ['20 minutos', '25 minutos', 'pausa de 10', 'pausa curta',
          'menos de 15']),
    Faq('Fiz a pausa de 45 antes das 4h30. A contagem zera?',
        'Zera. Depois de uma pausa completa (45 minutos, ou 15 + 30) começa '
            'uma nova contagem de 4h30, mesmo que ainda não tivesse '
            'conduzido as 4h30.',
        '$_r561, art. 7.º',
        ['zera', 'antes das 4h30', 'nova contagem', 'recomeca', 'reinicia']),
    Faq('Posso fazer a pausa enquanto carregam ou descarregam?',
        'Só se estiver mesmo livre para descansar: sem ajudar, sem vigiar a '
            'carga e sem ter de ficar à disposição. Se tem de ajudar, '
            'acompanhar ou esperar ordens, é martelo ou disponibilidade, '
            'não é pausa.',
        '$_r561, art. 4.º, al. d)',
        ['enquanto carregam', 'enquanto descarregam', 'durante a carga',
          'durante a descarga', 'cais']),
    Faq('Martelo conta como pausa?',
        'Não. Martelo (outros trabalhos) e carga/descarga são trabalho. Só '
            'a pausa/descanso (cama) conta para os 45 minutos.',
        '$_r561, art. 4.º e art. 7.º',
        ['martelo conta', 'outros trabalhos', 'conta como pausa']),
    Faq('Disponibilidade (quadrado) conta como pausa?',
        'Para um motorista só, não. Disponibilidade é tempo de espera: não é '
            'pausa nem descanso. Só com dois motoristas é que os 45 minutos '
            'ao lado do colega, com o caminhão a andar, podem valer como '
            'pausa.',
        '$_r561, art. 7.º; Diretiva 2002/15/CE, art. 3.º',
        ['disponibilidade conta', 'quadrado', 'espera conta']),
    Faq('Se vou parar para dormir, preciso fazer a pausa de 45 antes?',
        'Não. A pausa só é obrigatória se for continuar a conduzir. Se ao '
            'fim das 4h30 começa logo o descanso diário ou semanal, o '
            'descanso substitui a pausa.',
        '$_r561, art. 7.º',
        ['parar para dormir', 'fim do dia', 'descanso substitui',
          'ultima conducao']),
  ]),

  // ----------------------------------------------------- Descanso diário
  FaqGroup('Descanso diário e amplitude', Icons.hotel_rounded, [
    Faq('Quanto tempo de descanso diário?',
        'Regular: 11 horas seguidas (ou 3 + 9 horas). Reduzido: pelo menos '
            '9 horas, no máximo 3 vezes entre dois descansos semanais. O '
            'descanso tem de caber nas 24 horas depois do descanso anterior.',
        '$_r561, art. 8.º',
        ['descanso diario', 'dormir', '11 horas', 'descanso da noite']),
    Faq('Um descanso de 10 horas conta como quê?',
        'Como reduzido. Tudo o que tiver pelo menos 9 horas e menos de 11 é '
            'descanso diário reduzido, e gasta uma das 3 vezes permitidas '
            'entre dois descansos semanais.',
        '$_r561, art. 4.º, al. g)',
        ['descanso de 10', '10 horas de descanso', '9h30', '10h30']),
    Faq('Quantos descansos reduzidos (9 horas) posso fazer?',
        'Três entre dois descansos semanais. Depois do descanso semanal a '
            'conta volta a zero.',
        '$_r561, art. 8.º, n.º 4',
        ['quantos reduzidos', 'descansos reduzidos', 'tres vezes',
          '3 vezes', 'descanso de 9']),
    Faq('Tenho de compensar o descanso diário reduzido?',
        'Não. Só o descanso semanal reduzido é que tem de ser compensado. '
            'O diário reduzido (9 horas) não se compensa; só está limitado a '
            '3 vezes entre descansos semanais.',
        '$_r561, art. 8.º',
        ['compensar o diario', 'compensar descanso diario',
          'compensar as 9']),
    Faq('Como funciona o descanso dividido 3 + 9?',
        'O descanso regular pode ser feito em duas partes: a primeira de '
            'pelo menos 3 horas seguidas e a segunda de pelo menos 9 horas '
            'seguidas (12 no total), nesta ordem. Conta como regular: não '
            'gasta nenhuma das 3 vezes de reduzido.',
        '$_r561, art. 4.º, al. g)',
        ['3 + 9', '3+9', 'descanso dividido', 'tres mais nove', 'duas partes',
          '12 horas']),
    Faq('O que quer dizer descanso dentro das 24 horas?',
        'A partir da hora em que acabou o descanso anterior contam-se '
            '24 horas, e o novo descanso tem de caber aí dentro. Exemplo: '
            'começou às 6:00. Para 11 horas de descanso tem de parar até às '
            '19:00; para 9 horas (reduzido), até às 21:00.',
        '$_r561, art. 8.º, n.º 2',
        ['dentro das 24', '24 horas', 'ate que horas', 'que horas tenho de '
              'parar']),
    Faq('O que é a amplitude? 13 ou 15 horas?',
        'É o tempo do início ao fim da jornada. Com descanso de 11 horas o '
            'máximo é 13 horas; com descanso reduzido de 9 horas pode chegar '
            'a 15 horas, no máximo 3 vezes entre dois descansos semanais.',
        '$_r561, art. 8.º',
        ['amplitude', 'treze', 'quinze', '13 horas', '15 horas']),
    Faq('Passei das 13 horas de amplitude. E agora?',
        'Não é infração por si só: o descanso dessa noite passa a contar '
            'como reduzido (tem de ter pelo menos 9 horas) e gasta uma das '
            '3 vezes. Se já gastou as 3, aí sim é infração.',
        '$_r561, art. 8.º, n.os 2 e 4',
        ['passei das 13', 'mais de 13', 'passou de 13']),
    Faq('Passei das 15 horas de amplitude. E agora?',
        'O descanso de 9 horas já não cabe nas 24 horas: é infração, a não '
            'ser que tenha sido para chegar a um local de paragem seguro. '
            'Nesse caso imprima o talão e escreva o motivo atrás '
            '(artigo 12.º). Depois faça o descanso completo.',
        '$_r561, art. 8.º e art. 12.º',
        ['passei das 15', 'mais de 15', 'passou de 15']),
    Faq('Posso mexer o caminhão durante o descanso?',
        'Não. O descanso tem de ser seguido: qualquer condução interrompe e '
            'o descanso recomeça do zero. A exceção é o ferry ou comboio. Se '
            'a polícia ou o dono do local mandar tirar o caminhão, imprima '
            'o talão e escreva atrás o motivo, a hora e quem mandou.',
        '$_r561, art. 4.º, al. f) e g)',
        ['mexer o caminhao', 'durante o descanso', 'interromper o descanso',
          'tirar o caminhao', 'mandou sair']),
    Faq('Posso fazer o descanso diário na cabine?',
        'Pode, se o veículo tiver cama e estiver parado. O mesmo vale para '
            'o descanso semanal reduzido (24 horas). Só o semanal regular '
            '(45 horas) é que não pode ser na cabine.',
        '$_r561, art. 8.º, n.º 8',
        ['diario na cabine', 'dormir na cabine', 'dormir no caminhao']),
  ]),

  // ---------------------------------------------------- Descanso semanal
  FaqGroup('Descanso semanal', Icons.weekend_rounded, [
    Faq('Como é o descanso semanal?',
        'Regular: 45 horas. Reduzido: 24 horas, com compensação do que '
            'faltou até o fim da 3.ª semana seguinte. Tem de começar no '
            'máximo 144 horas (6 dias) depois do descanso semanal anterior.',
        '$_r561, art. 8.º, n.º 6',
        ['descanso semanal', '45 horas', 'fim de semana']),
    Faq('O que são as 144 horas?',
        'É o prazo para começar o descanso semanal: seis períodos de '
            '24 horas contados a partir do fim do descanso semanal anterior. '
            'Exemplo: o descanso acabou na segunda às 6:00; o próximo '
            'descanso semanal tem de começar até domingo às 6:00.',
        '$_r561, art. 8.º, n.º 6',
        ['144', 'cento e quarenta', 'prazo do descanso semanal']),
    Faq('Um descanso de 30 horas conta como quê?',
        'Como descanso semanal reduzido (pelo menos 24 e menos de 45 horas). '
            'Ficam a faltar 15 horas, que têm de ser compensadas.',
        '$_r561, art. 4.º, al. h)',
        ['30 horas', '35 horas', '40 horas', 'menos de 45', '36 horas']),
    Faq('Como compenso o descanso semanal reduzido?',
        'O que faltou para as 45 horas tem de ser feito de uma só vez, '
            'colado a outro descanso de pelo menos 9 horas, até o fim da '
            '3.ª semana seguinte. Exemplo: fez 24 horas, faltaram 21. Pode '
            'juntar as 21 horas a um descanso diário (9 + 21 = 30 horas) ou '
            'a um semanal (45 + 21 = 66 horas).',
        '$_r561, art. 8.º, n.os 6 e 7',
        ['compensar', 'compensacao', 'compenso', 'horas em falta',
          'compensar descanso', 'compensar o descanso semanal',
          'devolver horas']),
    Faq('Posso fazer dois descansos semanais reduzidos seguidos?',
        'Só em transporte internacional de mercadorias e fora do país da '
            'empresa. Em 4 semanas seguidas tem de haver 4 descansos '
            'semanais, 2 deles regulares. Depois dos dois reduzidos, o '
            'descanso semanal seguinte tem de ser regular e vir junto com a '
            'compensação dos dois.',
        '$_r561, art. 8.º, n.os 6 e 6-B',
        ['dois reduzidos', 'reduzidos seguidos', 'dois descansos reduzidos',
          '24 seguidos']),
    Faq('Posso fazer o descanso de 45 horas na cabine?',
        'Não. O descanso semanal regular (45 horas ou mais) não pode ser '
            'feito no veículo; a empresa paga o alojamento. O diário e o '
            'semanal reduzido podem ser feitos na cabine com cama.',
        '$_r561, art. 8.º, n.º 8',
        ['45 na cabine', 'cabina', 'descanso de 45 horas na cabine']),
    Faq('Quem paga o hotel no descanso de 45 horas?',
        'A empresa. O descanso semanal regular fora de casa tem de ser num '
            'alojamento adequado, com cama e casa de banho, pago pelo '
            'empregador.',
        '$_r561, art. 8.º, n.º 8',
        ['hotel', 'alojamento', 'quem paga', 'pensao', 'dormida']),
    Faq('De quanto em quanto tempo tenho de voltar a casa?',
        'A empresa tem de organizar o trabalho para o motorista voltar a '
            'casa ou à base pelo menos a cada 4 semanas, para um descanso '
            'semanal regular. Se fez dois reduzidos seguidos, tem de voltar '
            'antes do descanso regular da 3.ª semana.',
        '$_r561, art. 8.º, n.º 8-A',
        ['voltar a casa', 'ir a casa', '4 semanas', 'quatro semanas',
          'regresso a casa']),
    Faq('O descanso semanal apanhou duas semanas. Conta para qual?',
        'Conta para uma ou para a outra, à escolha, mas nunca para as duas. '
            'Exemplo: começou no domingo e acabou na terça.',
        '$_r561, art. 8.º, n.º 9',
        ['duas semanas conta', 'apanhou duas', 'entre duas semanas',
          'conta para qual']),
    Faq('O descanso semanal pode ser em qualquer dia?',
        'Pode. Não precisa de ser ao fim de semana. O que conta é ter pelo '
            'menos 24 ou 45 horas e começar dentro das 144 horas depois do '
            'descanso semanal anterior.',
        '$_r561, art. 8.º, n.º 6',
        ['qualquer dia', 'meio da semana', 'sabado', 'dia da semana']),
  ]),

  // ------------------------------------------------- Artigo 12 (exceções)
  FaqGroup('Passar do tempo: park, casa e talão (art. 12.º)',
      Icons.report_problem_rounded, [
    Faq('Posso passar do tempo para chegar a um park?',
        'Pode. O artigo 12.º deixa passar dos limites só o necessário para '
            'chegar a um local de paragem adequado e seguro, sem pôr em '
            'risco a segurança rodoviária. Vale para a condução, para a '
            'pausa e para o descanso. Ao chegar, imprima o talão e escreva '
            'o motivo atrás, à mão.',
        _a12,
        ['passar do tempo', 'exceder', 'chegar a um park', 'estacionamento',
          'achar park', 'achar um park', 'procurar park', 'procurar um park',
          'passar uns minutos', 'passar 10 minutos', 'tempinho',
          'local seguro', 'artigo 12', 'passar do horario']),
    Faq('O tempo acabou e não achei vaga no park. O que faço?',
        '1. Siga com calma até o próximo local seguro (park, área de '
            'serviço, zona industrial). Não pare na berma nem em sítio '
            'perigoso.\n'
            '2. Só o necessário: pare no primeiro local adequado, não no '
            'que lhe dá mais jeito.\n'
            '3. Logo ao parar, imprima o talão do dia (cartão do condutor, '
            '24 h).\n'
            '4. Atrás do talão escreva à mão o motivo, o local, a data e a '
            'hora, "Art. 12.º Reg. (CE) 561/2006", o nome e assine.\n'
            '5. Faça a pausa ou o descanso completo e guarde o talão para '
            'mostrar na fiscalização.',
        _a12,
        ['nao achei vaga', 'sem vaga', 'park cheio', 'parque cheio',
          'nao encontrei', 'nao tem lugar', 'sem lugar', 'lotado',
          'tempo acabou', 'horario acabou']),
    Faq('O que escrevo atrás do talão (ticket)?',
        'Escreva à mão, com letra legível:\n'
            '• Motivo. Ex.: "Park da A1 km 120 cheio, sem lugar seguro. '
            'Segui até a área de serviço seguinte."\n'
            '• Local onde parou.\n'
            '• Data e hora em que chegou.\n'
            '• "Art. 12.º do Regulamento (CE) n.º 561/2006".\n'
            '• Nome e assinatura.\n'
            'A lei obriga a escrever o motivo; o resto é boa prática, para '
            'não haver dúvida na fiscalização.',
        _a12,
        ['atras do talao', 'o que escrevo', 'escrever no talao',
          'verso', 'o que coloco', 'anotar', 'justificar', 'justificacao']),
    Faq('Que lei coloco no talão?',
        'Artigo 12.º do Regulamento (CE) n.º 561/2006. Pode escrever '
            'abreviado: "Art. 12.º Reg. (CE) 561/2006". É o artigo das '
            'exceções para chegar a um local de paragem adequado, a casa '
            'ou à base.',
        _a12,
        ['que lei', 'qual lei', 'qual artigo', 'que artigo',
          'numero da lei']),
    Faq('Como imprimo o talão no tacógrafo?',
        'Com o caminhão parado e a ignição ligada, entre no menu do '
            'tacógrafo: Impressão > Condutor 1 > Dia (24 h) e escolha a '
            'data de hoje. O caminho muda um pouco conforme a marca (VDO, '
            'Stoneridge). Tenha sempre um rolo de papel de reserva.',
        _r165,
        ['como imprimo', 'imprimir', 'impressao', 'tirar o talao',
          'imprimir o talao', 'rolo', 'papel']),
    Faq('Quando tenho de imprimir e escrever no talão?',
        'O mais tardar ao chegar ao local de paragem (ou ao destino, no '
            'caso de ir para casa ou para a base). Não deixe para o dia '
            'seguinte: anotação feita depois pode não ser aceite.',
        _a12,
        ['quando imprimir', 'quando escrever', 'mais tardar', 'ao chegar',
          'no dia seguinte']),
    Faq('Posso conduzir mais para chegar em casa?',
        'Em situação excecional, pode passar até 1 hora da condução diária '
            'e semanal para chegar a casa ou à base e fazer o descanso '
            'semanal. Podem ser até 2 horas se for para o descanso semanal '
            'regular (45 h) e fizer uma pausa de 30 minutos seguidos logo '
            'antes do tempo a mais. Escreva o motivo no talão ao chegar e '
            'compense depois.',
        _a12,
        ['chegar em casa', 'chegar a casa', 'chegar a base', 'hora a mais',
          'uma hora a mais', 'hora extra', 'horas extraordinarias',
          'extraordinaria', 'regressar']),
    Faq('Como funcionam as 2 horas a mais para chegar a casa?',
        'Valem só para ir fazer o descanso semanal regular (45 horas ou '
            'mais) em casa ou na base. Antes de começar o tempo a mais tem '
            'de fazer uma pausa de 30 minutos seguidos. Exemplo: acabou as '
            '9 horas a 1h40 de casa. Pare 30 minutos, conduza até casa, '
            'imprima o talão e escreva o motivo atrás.',
        _a12,
        ['2 horas a mais', 'duas horas a mais', 'duas horas',
          'pausa de 30 antes']),
    Faq('A hora a mais serve para um descanso diário normal?',
        'Não. A hora (ou as 2 horas) a mais é só para chegar a casa ou à '
            'base e fazer o descanso semanal. Num dia normal só pode passar '
            'do tempo o necessário para chegar a um local de paragem '
            'seguro.',
        _a12,
        ['serve para', 'descanso diario normal', 'dia normal',
          'durante a semana']),
    Faq('Tenho de compensar o tempo que passei?',
        'A hora ou as 2 horas a mais para chegar a casa ou à base, sim: com '
            'o mesmo tempo de descanso, de uma só vez, junto a outro '
            'descanso, até o fim da 3.ª semana seguinte. Exemplo: passou '
            '50 minutos; faça um descanso com 50 minutos a mais.',
        _a12,
        ['compensar o tempo', 'tempo que passei', 'compensar a hora',
          'devolver o tempo']),
    Faq('Posso usar o artigo 12.º todos os dias?',
        'Não. É para situações que não dava para prever: park cheio, '
            'acidente, estrada cortada, mau tempo, demora fora do normal. '
            'Não serve para viagem mal planeada nem pode ser usado sempre. '
            'Quem decide se aceita é o agente na fiscalização, caso a caso.',
        _a12,
        ['todos os dias', 'sempre', 'varias vezes', 'abusar',
          'quantas vezes posso usar']),
    Faq('Trânsito ou acidente atrasou e o tempo acabou. E agora?',
        'Vale o mesmo: siga só até o primeiro local de paragem seguro, '
            'imprima o talão ao chegar e escreva atrás o que aconteceu '
            '(ex.: "Acidente na A4, estrada cortada 1h20"), o local, a '
            'hora, o artigo 12.º e assine.',
        _a12,
        ['acidente', 'atrasou', 'estrada cortada', 'atraso', 'mau tempo',
          'neve', 'imprevisto']),
    Faq('A empresa pode mandar eu passar do tempo?',
        'Não. A decisão de usar o artigo 12.º é do motorista, por '
            'segurança. A empresa tem de organizar o trabalho para os '
            'tempos serem cumpridos e não pode pagar prémios que levem a '
            'passar dos limites.',
        '$_r561, art. 10.º e art. 12.º',
        ['empresa mandar', 'empresa manda', 'patrao', 'chefe', 'obrigar',
          'premio']),
    Faq('Por quanto tempo guardo o talão?',
        'Leve-o consigo enquanto puder ser pedido na estrada: o dia atual e '
            'os 56 dias anteriores. Depois entregue à empresa, que tem de '
            'guardar os registos pelo menos 1 ano.',
        '$_r165, art. 33.º e art. 36.º',
        ['guardo o talao', 'guardar o talao', 'guardar o ticket',
          'quanto tempo guardo']),
  ]),

  // -------------------------------------------- Tacógrafo e fiscalização
  FaqGroup('Tacógrafo, cartão e fiscalização', Icons.fact_check_rounded, [
    Faq('Quantos dias a polícia pode pedir?',
        'O dia atual e os 56 dias anteriores (cartão, talões e registos '
            'manuais).',
        '$_r165, art. 36.º',
        ['policia', 'fiscalizacao', '56 dias', '28 dias', 'controlo',
          'quantos dias']),
    Faq('O que querem dizer os símbolos do tacógrafo?',
        'Volante: condução. Martelos cruzados: outros trabalhos (martelo). '
            'Quadrado com um risco: disponibilidade (espera). Cama: pausa '
            'ou descanso.',
        '$_r165, art. 34.º, n.º 5',
        ['simbolos', 'simbolo', 'volante', 'cama', 'desenho']),
    Faq('O que é a disponibilidade (quadrado)?',
        'É o tempo de espera em que não tem de ficar no posto de trabalho '
            'mas tem de estar pronto a arrancar, e cuja duração já sabia '
            'antes: espera para carregar com hora marcada, espera em '
            'fronteira ou ferry, e o tempo ao lado do colega com o caminhão '
            'a andar. Não é pausa nem descanso.',
        'Diretiva 2002/15/CE, art. 3.º, al. b)',
        ['o que e disponibilidade', 'disponibilidade', 'tempo de espera',
          'esperar para carregar']),
    Faq('Tenho de marcar o país no tacógrafo?',
        'Sim: o país onde começa e o país onde acaba o trabalho do dia. E, '
            'ao passar uma fronteira, o país onde entrou, na primeira '
            'paragem possível na fronteira ou logo a seguir. Os '
            'tacógrafos inteligentes da 2.ª versão registam a fronteira '
            'sozinhos.',
        '$_r165, art. 34.º, n.os 6 e 7',
        ['pais', 'fronteira', 'marcar o pais', 'entrada no pais']),
    Faq('O que é a entrada manual ao meter o cartão?',
        'Ao inserir o cartão, o tacógrafo pergunta o que fez desde que o '
            'tirou. Tem de indicar essas horas: descanso (cama), martelo ou '
            'disponibilidade. Sem isso ficam períodos em branco, que podem '
            'dar multa.',
        '$_r165, art. 34.º, n.º 3',
        ['entrada manual', 'meter o cartao', 'inserir o cartao',
          'periodo em branco', 'atividade desconhecida']),
    Faq('Como justifico férias, folgas ou baixa?',
        'Ao voltar, ao inserir o cartão, registe esses dias como descanso '
            '(cama) na entrada manual. Em alguns países e empresas usa-se '
            'também a declaração de atividade, assinada pela empresa; '
            'pergunte na sua.',
        '$_r165, art. 34.º, n.º 3',
        ['ferias', 'folga', 'baixa', 'doenca', 'declaracao de atividade',
          'dias sem conduzir']),
    Faq('Perdi o cartão ou foi roubado. Posso conduzir?',
        'Pode, até 15 dias de calendário (ou mais, se for preciso para '
            'levar o caminhão à base). Peça o cartão novo em 7 dias de '
            'calendário; se foi roubado, participe à polícia do local. No '
            'início e no fim de cada viagem imprima o talão, escreva o '
            'nome e o número da carta ou do cartão e assine.',
        '$_r165, art. 29.º e art. 35.º',
        ['perdi o cartao', 'roubado', 'roubaram', 'cartao perdido',
          'sem cartao']),
    Faq('O cartão avariou ou não lê. O que faço?',
        'É igual ao cartão perdido: pode conduzir até 15 dias de '
            'calendário, pede a substituição em 7 dias e devolve o cartão '
            'avariado. No início e no fim de cada viagem imprima o talão '
            'com o nome, o número da carta ou do cartão e a assinatura.',
        '$_r165, art. 29.º e art. 35.º',
        ['cartao avariou', 'cartao avariado', 'nao le', 'cartao estragado',
          'erro de cartao', 'cartao com defeito']),
    Faq('Esqueci o cartão em casa. Posso conduzir?',
        'Não. Os 15 dias sem cartão valem só para cartão perdido, roubado '
            'ou avariado. Conduzir sem o cartão por esquecimento é infração '
            'grave.',
        '$_r165, art. 27.º e art. 29.º',
        ['esqueci o cartao', 'cartao em casa', 'esquecimento']),
    Faq('Quando tenho de renovar o cartão?',
        'O cartão vale 5 anos. Peça a renovação pelo menos 15 dias úteis '
            'antes de acabar a validade. Com o cartão caducado não pode '
            'conduzir.',
        '$_r165, art. 28.º',
        ['renovar', 'renovacao', 'validade do cartao', 'caducado',
          'caduca', '5 anos']),
    Faq('O tacógrafo avariou na viagem. O que faço?',
        'Anote à mão as atividades (condução, martelo, pausas, descanso) '
            'num talão ou numa folha, com o nome, o número do cartão e a '
            'assinatura. A empresa tem de mandar reparar numa oficina '
            'autorizada; se não der para voltar à base numa semana, a '
            'reparação é feita em viagem.',
        '$_r165, art. 37.º',
        ['tacografo avariou', 'tacografo avariado', 'tacografo parou',
          'reparar', 'oficina']),
    Faq('Posso usar o cartão de outro motorista?',
        'Nunca. O cartão é pessoal. Usar o cartão de outro, ou ter mais de '
            'um cartão, é das infrações mais graves e pode ser crime.',
        '$_r165, art. 27.º',
        ['cartao de outro', 'cartao do colega', 'cartao emprestado',
          'dois cartoes']),
    Faq('De quanto em quanto tempo a empresa descarrega o cartão?',
        'O cartão do motorista, no máximo a cada 28 dias; o tacógrafo do '
            'veículo, no máximo a cada 90 dias. A empresa guarda os dados '
            'pelo menos 1 ano.',
        'Reg. (UE) n.º 581/2010; Reg. 561/2006, art. 10.º',
        ['descarregar', 'descarrega', 'download', 'baixar o cartao',
          '90 dias', 'leitura do cartao']),
    Faq('Ir de carro buscar o caminhão conta como quê?',
        'Se o caminhão não está em casa nem na base, o tempo de viagem até '
            'ele não é descanso nem pausa. Se for você a conduzir o carro, '
            'conta como martelo (outros trabalhos); registe na entrada '
            'manual ao meter o cartão.',
        '$_r561, art. 9.º, n.os 2 e 3',
        ['buscar o caminhao', 'ir de carro', 'viagem de carro',
          'deslocacao ate o caminhao']),
    Faq('Que veículos têm de cumprir a lei do tacógrafo?',
        'Veículos de mercadorias com mais de 3,5 toneladas (com reboque). '
            'Desde 1 de julho de 2026 também os de mais de 2,5 toneladas em '
            'transporte internacional ou cabotagem por conta de outrem.',
        '$_r561, art. 2.º',
        ['que veiculos', 'quais veiculos', '3,5 toneladas', '2,5 toneladas',
          'carrinha', 'furgao', 'toneladas']),
  ]),

  // ------------------------------------- Usar o tacógrafo: passo a passo
  FaqGroup('Usar o tacógrafo: começar, conduzir e acabar',
      Icons.play_circle_rounded, [
    Faq('Como começo o dia no tacógrafo (iniciar viagem)?',
        '1. Caminhão parado, ignição ligada. 2. Meta o cartão na ranhura 1 '
            '(chip para cima e para a frente). 3. O visor mostra o seu nome '
            'e quando tirou o cartão. 4. Faça a entrada manual: o que fez '
            'desde que tirou o cartão (normalmente cama). 5. Escolha o país '
            'de início (em Espanha também a região) e confirme. 6. Com a '
            'tecla 1 ponha martelo para a verificação do caminhão. '
            '7. Arranque: a condução é marcada sozinha.',
        '$_r165, art. 34.º; manual do tacógrafo',
        ['comecar o dia', 'iniciar viagem', 'iniciar o dia', 'comecar viagem',
          'inicio do dia', 'meter o cartao de manha', 'abrir o dia',
          'comecar a trabalhar']),
    Faq('Como faço a entrada manual passo a passo?',
        'Ao meter o cartão aparece "Entrada adicional?" (ou "M"). Escolha '
            'Sim. O tacógrafo mostra o intervalo desde que tirou o cartão: '
            'com as setas escolha a atividade (cama para descanso, martelo, '
            'disponibilidade) e acerte a hora em que acabou, com OK. Repita '
            'até chegar à hora atual. No fim escolha o país de início e '
            'responda Sim a "Confirmar entrada?". Se errar, antes de '
            'confirmar pode voltar com a tecla de voltar.',
        '$_r165, art. 34.º, n.º 3; manual do tacógrafo',
        ['entrada manual passo', 'entrada adicional', 'como preencher',
          'preencher o descanso', 'por cama de manha', 'entrada m']),
    Faq('Que teclas tem o tacógrafo (VDO)?',
        'Tecla 1: muda a atividade do motorista 1 e, segurada mais de 2 '
            'segundos, tira o cartão 1. Tecla 2: o mesmo para o motorista 2. '
            'Setas para cima e para baixo: andar no menu e mudar valores. '
            'OK: abrir o menu e confirmar. Voltar: sair ou cancelar. Noutras '
            'marcas os botões são parecidos.',
        'Manual do tacógrafo',
        ['teclas', 'botoes', 'tecla 1', 'tecla 2', 'botao ok', 'setas']),
    Faq('Como mudo a atividade (martelo, quadrado, cama)?',
        'Com o caminhão parado, carregue na tecla 1 (motorista 1) várias '
            'vezes até aparecer o símbolo certo: martelos cruzados (outros '
            'trabalhos), quadrado (disponibilidade) ou cama (pausa ou '
            'descanso). A condução (volante) é marcada sozinha quando o '
            'caminhão anda.',
        '$_r165, art. 34.º, n.º 5; manual do tacógrafo',
        ['mudar atividade', 'trocar atividade', 'selecionar atividade',
          'por martelo', 'por cama', 'por quadrado', 'escolher atividade']),
    Faq('Como faço a pausa no tacógrafo?',
        'Ao parar, carregue na tecla 1 até aparecer a cama. O tempo com a '
            'cama conta como pausa (15, 30 ou 45 minutos). Martelo ou '
            'quadrado não contam como pausa. Muitos tacógrafos põem martelo '
            'sozinhos ao desligar a ignição: veja sempre o visor e troque '
            'para a cama. No TacoGuard responda "Pausa" no pop-up.',
        '$_r561, art. 7.º; manual do tacógrafo',
        ['pausa no tacografo', 'fazer a pausa', 'marcar pausa', 'pausa cama',
          'pausa de 45', 'meter a cama']),
    Faq('Que atividade o tacógrafo põe sozinho ao desligar a ignição?',
        'Depende da configuração feita pela oficina ou pela empresa: '
            'muitas vezes martelo para o motorista 1 e disponibilidade para o '
            'motorista 2. Por isso, ao parar, confira sempre o símbolo no '
            'visor e troque para o que está a fazer de verdade.',
        'Manual do tacógrafo',
        ['ignicao', 'desligar a ignicao', 'automatico', 'atividade automatica',
          'muda sozinho', 'liga sozinho']),
    Faq('Como acabo o dia e tiro o cartão?',
        '1. Caminhão parado. 2. Segure a tecla 1 mais de 2 segundos. 3. '
            'Escolha o país de fim (em Espanha também a região) e confirme '
            'com OK. 4. Se quiser, imprima o talão do dia. 5. O cartão sai. '
            'O cartão só se tira no fim do trabalho do dia, não nas pausas.',
        '$_r165, art. 34.º; manual do tacógrafo',
        ['tirar o cartao', 'acabar o dia', 'fim do dia', 'fechar o dia',
          'retirar o cartao', 'ejetar', 'sair o cartao', 'fim de jornada']),
    Faq('Posso tirar o cartão durante a pausa ou o descanso?',
        'Na pausa, não: o cartão fica até ao fim do trabalho do dia. No '
            'descanso diário ou semanal pode tirar (e no dia seguinte faz a '
            'entrada manual com cama). Em duas tripulações o cartão fica '
            'durante a viagem.',
        '$_r165, art. 34.º, n.º 1',
        ['tirar o cartao na pausa', 'cartao na pausa', 'cartao no descanso',
          'deixar o cartao']),
    Faq('Tenho de meter o cartão só para mexer o caminhão uns metros?',
        'Sim. Qualquer movimento sem cartão fica gravado como "condução '
            'sem cartão" e é infração. Meta o cartão antes de mexer o '
            'caminhão, mesmo para manobrar.',
        '$_r165, art. 34.º, n.º 1',
        ['sem cartao manobra', 'mexer o caminhao', 'manobrar', 'poucos metros',
          'conducao sem cartao']),
    Faq('Como marco a fronteira ao mudar de país?',
        'Tacógrafo inteligente da 2.ª versão (VDO DTCO 4.1, Stoneridge '
            'SE5000 Smart 2): grava a fronteira sozinho pelo GPS. Modelos '
            'mais antigos: na primeira paragem possível na fronteira ou logo '
            'a seguir, menu > "Entrada condutor 1" > "País início" (ou '
            '"Fronteira"), escolha o país onde entrou e OK.',
        '$_r165, art. 34.º, n.º 7',
        ['fronteira', 'marcar fronteira', 'mudar de pais', 'entrar em espanha',
          'entrar em franca', 'cruzar fronteira', 'passar a fronteira']),
    Faq('Como marco carga e descarga no tacógrafo?',
        'Nos tacógrafos da 2.ª versão: caminhão parado, OK > "Entrada '
            'veículo" > "Carga/descarga" > escolha Carga, Descarga ou Carga e '
            'descarga > OK. O tacógrafo grava a posição GPS do local. A '
            'atividade enquanto carrega é martelo (ou quadrado, se só '
            'espera).',
        '$_r165, art. 8.º; manual do tacógrafo',
        ['carga e descarga', 'marcar carga', 'marcar descarga', 'carregar',
          'descarregar', 'cabotagem']),
    Faq('Como marco o ferry ou o comboio?',
        'Antes de embarcar ou logo a bordo: OK > "Entrada veículo" > '
            '"Ferry/comboio início" > OK, e depois ponha a cama. Nos modelos '
            'novos marque também "Ferry/comboio fim" ao desembarcar. Assim '
            'o descanso pode ser interrompido para embarcar e desembarcar.',
        '$_r561, art. 9.º; manual do tacógrafo',
        ['ferry', 'barco', 'comboio', 'trem', 'comboio inicio', 'ferry inicio']),
    Faq('O tacógrafo grava onde eu estou?',
        'Os tacógrafos inteligentes gravam a posição GPS no início e no fim '
            'do dia de trabalho e a cada 3 horas de condução acumulada. Os da '
            '2.ª versão gravam também as fronteiras e as cargas e descargas.',
        '$_r165, art. 8.º',
        ['gps do tacografo', 'posicao', 'localizacao', 'grava onde',
          'tacografo inteligente', 'smart']),
    Faq('A polícia consegue ver o tacógrafo com o caminhão a andar?',
        'Sim. Os tacógrafos inteligentes têm leitura à distância (DSRC): a '
            'polícia vê da estrada a velocidade, os eventos e se há '
            'manipulação, e usa isso para escolher quem manda parar. A multa '
            'só vem depois do controlo na paragem.',
        '$_r165, art. 9.º',
        ['distancia', 'dsrc', 'controlo remoto', 'policia ve', 'antena']),
  ]),

  // ------------------------------------- Menus, talões e configurações
  FaqGroup('Tacógrafo: menus, talões e configurações', Icons.tune_rounded, [
    Faq('Como imprimo o talão do dia?',
        'Caminhão parado: OK > "Imprimir condutor 1" > "24h dia" > escolha a '
            'data com as setas > OK. Se perguntar, escolha impressão em UTC '
            '(a impressão em hora local não vale na fiscalização).',
        'Manual do tacógrafo',
        ['imprimir', 'talao do dia', 'impressao', 'tirar talao',
          'imprimir o dia', 'tirar papel']),
    Faq('Que outros talões posso imprimir?',
        'Do motorista: dia (24 h), eventos e falhas, e atividades dos '
            'últimos dias. Do veículo: dia do veículo, eventos e falhas, '
            'excessos de velocidade, dados técnicos e o diagrama de '
            'velocidade. Os nomes mudam um pouco conforme a marca.',
        'Manual do tacógrafo',
        ['talao de eventos', 'excesso de velocidade talao', 'dados tecnicos',
          'tipos de talao', 'impressoes']),
    Faq('Como vejo no visor o que fiz no dia?',
        'Caminhão parado: OK > "Visualizar condutor 1" (ou "Indicação") > '
            '"24h dia" > escolha a data. As atividades aparecem uma a uma; '
            'ande com as setas.',
        'Manual do tacógrafo',
        ['ver no visor', 'ver atividades', 'visualizar', 'consultar o dia',
          'ver o dia']),
    Faq('Como vejo quanto tempo ainda posso conduzir?',
        'Com o caminhão parado, carregue nas setas no ecrã principal: '
            'aparece a condução desde a última pausa válida, a pausa '
            'acumulada e, com o VDO Counter, o tempo que falta até à pausa e '
            'até ao fim da condução do dia. O TacoGuard mostra o mesmo na '
            'tela Hoje.',
        'Manual do tacógrafo',
        ['tempo restante', 'quanto falta', 'vdo counter', 'falta conduzir',
          'tempo que falta', 'contador']),
    Faq('Que avisos o tacógrafo dá na condução?',
        'Aos 4h15 de condução sem pausa dá um pré-aviso e aos 4h30 o aviso '
            'de pausa obrigatória. Carregue em OK para apagar a mensagem. '
            'Também avisa excesso de velocidade, falta de papel e erros de '
            'cartão.',
        'Manual do tacógrafo',
        ['aviso', 'avisos', 'mensagem', '4h15', 'pre aviso', 'alarme']),
    Faq('Quando o tacógrafo grava excesso de velocidade?',
        'Quando passa da velocidade programada (90 km/h no caminhão) '
            'durante mais de 60 segundos seguidos. Fica gravado como evento '
            'e aparece no talão de excessos de velocidade.',
        '$_r165, anexo IC',
        ['excesso de velocidade', 'velocidade', '90 km', 'passar dos 90',
          'limitador', 'segundos']),
    Faq('O que faço quando aparece uma mensagem de erro?',
        'Leia o código, carregue em OK para apagar e, se for erro do '
            'aparelho ou do cartão, imprima o talão de eventos e falhas e '
            'guarde-o. Se o erro repetir, avise a empresa: pode ser preciso '
            'ir à oficina autorizada.',
        'Manual do tacógrafo',
        ['erro', 'mensagem de erro', 'falha', 'evento', 'codigo de erro',
          'ponto de exclamacao']),
    Faq('Como troco o rolo de papel?',
        'Com o caminhão parado, carregue na frente da gaveta da impressora '
            'para abrir, ponha o rolo novo com o papel a sair por baixo (o '
            'lado de imprimir para cima) e feche. Se acabou a meio, a '
            'impressão continua sozinha. Use só rolos aprovados para esse '
            'tacógrafo e leve sempre rolos de reserva.',
        '$_r165, art. 34.º; manual do tacógrafo',
        ['papel', 'rolo', 'trocar o papel', 'acabou o papel', 'sem papel',
          'impressora']),
    Faq('Como mudo o idioma do tacógrafo?',
        'Caminhão parado: no ecrã principal carregue nas setas até '
            '"Idioma" (ou bandeira), OK, escolha o idioma e OK. O idioma fica '
            'gravado para o seu cartão.',
        'Manual do tacógrafo',
        ['idioma', 'lingua', 'portugues', 'mudar o idioma', 'linguagem']),
    Faq('Como funciona com dois motoristas?',
        'O motorista que conduz mete o cartão na ranhura 1 e o colega na '
            'ranhura 2. Com o caminhão a andar, o tacógrafo marca '
            'disponibilidade ao segundo motorista. Na troca, param, trocam '
            'os cartões de ranhura e cada um confirma a sua atividade.',
        '$_r165, art. 34.º; $_r561, art. 8.º, n.º 5',
        ['dois motoristas', 'segundo motorista', 'ranhura 2', 'colega',
          'tripulacao', 'dupla']),
    Faq('O que é a pergunta dos dados ITS ao meter o cartão?',
        'Os tacógrafos inteligentes perguntam se autoriza a partilha dos '
            'seus dados pessoais com outros sistemas do caminhão (ITS). Pode '
            'responder Sim ou Não; não muda nada no registo das horas.',
        '$_r165, art. 7.º',
        ['its', 'dados its', 'dados pessoais', 'consentimento', 'partilha']),
    Faq('De quanto em quanto tempo o tacógrafo vai à oficina?',
        'A inspeção periódica é a cada 2 anos numa oficina autorizada, e '
            'também depois de reparações ou de mudar a matrícula ou os '
            'pneus de tamanho. A data fica na placa de instalação, junto do '
            'tacógrafo ou na porta.',
        '$_r165, art. 23.º',
        ['oficina', 'inspecao', 'calibracao', '2 anos', 'placa',
          'aferir', 'aferição']),
    Faq('Quantos dias o cartão guarda?',
        'O cartão guarda pelo menos 28 dias de atividades (os cartões '
            'novos, da 2.ª geração, 56 dias ou mais). Mesmo assim a empresa '
            'tem de o descarregar no máximo a cada 28 dias.',
        '$_r165; Reg. (UE) n.º 581/2010',
        ['cartao guarda', 'memoria do cartao', 'quantos dias o cartao',
          'cartao cheio']),
    Faq('O que é o ponto de interrogação no talão?',
        'É tempo desconhecido: o cartão esteve fora e não preencheu a '
            'entrada manual. Na fiscalização pode ter de explicar. Para '
            'evitar, ao meter o cartão preencha sempre o tempo fora (cama, '
            'martelo ou disponibilidade).',
        '$_r165, art. 34.º, n.º 3',
        ['interrogacao', 'ponto de interrogacao', 'desconhecido',
          'tempo desconhecido', 'sinal de interrogacao']),
    Faq('Aparece "conflito de tempo" ao meter o cartão. O que é?',
        'O cartão tem uma hora de saída mais recente do que a hora do '
            'tacógrafo, normalmente porque a hora UTC de um dos tacógrafos '
            'está errada. Faça o dia normalmente, imprima o talão e avise a '
            'empresa para mandar acertar na oficina.',
        'Manual do tacógrafo',
        ['conflito de tempo', 'conflito', 'hora do cartao', 'erro de hora']),
  ]),

  // ---------------------------- Cartão de motorista: obrigações e cuidados
  FaqGroup('Cartão do tacógrafo: certo e errado', Icons.credit_card_rounded, [
    Faq('Quais são as minhas obrigações com o cartão?',
        '1. Ter um só cartão, pessoal e dentro da validade. 2. Metê-lo antes '
            'de mexer o caminhão e deixá-lo todo o dia de trabalho. 3. Fazer '
            'a entrada manual do tempo fora do caminhão. 4. Selecionar a '
            'atividade certa e marcar os países. 5. Levá-lo sempre consigo e '
            'mostrá-lo na fiscalização. 6. Avisar e pedir outro em 7 dias se '
            'perder, for roubado ou avariar. 7. Renovar a tempo.',
        '$_r165, art. 26.º a 29.º e 34.º',
        ['obrigacoes', 'obrigacao', 'deveres', 'regras do cartao',
          'tudo sobre o cartao', 'uso do cartao', 'como usar o cartao']),
    Faq('O que é proibido fazer com o cartão?',
        'Usar o cartão de outro motorista, emprestar o seu, ter mais de um '
            'cartão, usar cartão falso, alterado ou caducado, conduzir sem '
            'cartão, tirar o cartão na pausa para apagar tempo, fazer '
            'entradas manuais falsas e mexer no tacógrafo. Várias destas são '
            'infrações gravíssimas e algumas são crime.',
        '$_r165, art. 26.º, 32.º e 34.º; Reg. (UE) 2016/403',
        ['proibido', 'nao pode', 'errado', 'o que nao fazer', 'infracao cartao',
          'fraude', 'manipular']),
    Faq('Como devo cuidar do cartão?',
        'Guarde-o numa capa, longe do sol e do calor (não o deixe no tablier '
            'no verão), de ímanes, telemóvel encostado e humidade. Não o '
            'dobre, não o risque e não cole nada no chip. Se estiver sujo, '
            'limpe o chip só com um pano seco e macio. Meta-o com o chip '
            'virado para cima e para a frente, sem forçar.',
        'Manual do tacógrafo',
        ['cuidar', 'cuidados', 'estragar', 'proteger o cartao', 'limpar o chip',
          'capa', 'calor', 'sol']),
    Faq('Como meto o cartão do lado certo?',
        'Chip virado para cima e a apontar para dentro da ranhura (a seta do '
            'cartão também indica o sentido). Motorista na ranhura 1; '
            'colega, em dupla, na ranhura 2. Empurre até o tacógrafo o '
            'puxar; nunca force.',
        'Manual do tacógrafo',
        ['lado certo', 'ranhura', 'posicao do cartao',
          'chip para cima', 'como inserir']),
    Faq('Posso ter dois cartões, de dois países?',
        'Não. Cada motorista só pode ter um cartão válido, emitido pelo país '
            'onde mora habitualmente. Ter dois é infração gravíssima.',
        '$_r165, art. 26.º',
        ['dois cartoes', 'segundo cartao', 'cartao de outro pais',
          'cartao portugues e espanhol']),
    Faq('Onde peço o cartão e quanto tempo demora?',
        'No organismo do país onde mora (em Portugal, o IMT). Com o pedido '
            'vão normalmente a carta de condução, documento de identificação e '
            'foto. O cartão é emitido em até 1 mês e vale 5 anos.',
        '$_r165, art. 26.º',
        ['pedir o cartao', 'imt', 'primeiro cartao',
          'onde peco', 'quanto tempo demora']),
    Faq('Mudei de morada ou de país. E o cartão?',
        'O cartão continua válido. Se mudou a residência habitual para outro '
            'país da UE, pode pedir a troca pelo cartão desse país (e na '
            'renovação tem de ser lá). Avise a mudança de morada à entidade '
            'que o emitiu.',
        '$_r165, art. 26.º e 31.º',
        ['mudei de pais', 'mudar de pais', 'mudei de morada', 'trocar o cartao',
          'residencia', 'mudei de casa']),
    Faq('Mudei de empresa. O cartão fica com a empresa antiga?',
        'Não. O cartão é seu e vai consigo. Antes de sair, a empresa antiga '
            'deve descarregar o cartão; a nova descarrega a partir daí. A '
            'empresa não pode ficar com o seu cartão.',
        '$_r165, art. 27.º e 33.º',
        ['mudei de empresa', 'nova empresa', 'empresa ficou com o cartao',
          'patrao ficou com o cartao', 'mudar de patrao', 'despedido']),
    Faq('A empresa pode guardar o meu cartão?',
        'Não. O cartão é pessoal e tem de estar consigo quando conduz. A '
            'empresa pode pedi-lo para o descarregar, mas depois tem de o '
            'devolver.',
        '$_r165, art. 27.º',
        ['empresa guardar', 'empresa ficar', 'entregar o cartao',
          'deixar o cartao na empresa', 'escritorio']),
    Faq('Troquei de caminhão a meio do dia. Como faço?',
        '1. No primeiro caminhão, parado, ponha a atividade certa e tire o '
            'cartão (país de fim não é preciso se o dia continua). 2. No '
            'segundo, meta o cartão e, na entrada manual, registe o tempo '
            'entre os dois (martelo se andou a trabalhar, quadrado se '
            'esperou). 3. Continue normalmente.',
        '$_r165, art. 34.º',
        ['troquei de caminhao', 'trocar de caminhao', 'outro caminhao',
          'mudar de camiao', 'dois caminhoes no dia', 'troca de veiculo']),
    Faq('O caminhão tem tacógrafo de disco. Uso o cartão?',
        'Não. No tacógrafo analógico usa discos (folhas), um por dia, com '
            'nome, locais, datas e quilómetros escritos. Na fiscalização '
            'mostra os discos e também o cartão, se tiver um, porque os dias '
            'no tacógrafo digital também contam.',
        '$_r165, art. 34.º e 36.º',
        ['disco', 'analogico', 'folha', 'tacografo antigo', 'disco diagrama']),
    Faq('O cartão tem PIN?',
        'O cartão de motorista não tem PIN. Só o cartão da empresa, o da '
            'oficina e o da polícia é que pedem PIN.',
        'Manual do tacógrafo',
        ['pin', 'codigo', 'senha do cartao']),
    Faq('Encontrei o cartão que dei como perdido. Posso usar?',
        'Não. Depois de declarado perdido ou roubado o cartão fica anulado. '
            'Entregue-o à entidade que o emitiu e use só o cartão novo.',
        '$_r165, art. 29.º',
        ['encontrei o cartao', 'achei o cartao', 'cartao antigo',
          'cartao anulado', 'apareceu o cartao']),
    Faq('O cartão ficou preso ou não sai. O que faço?',
        'O cartão só sai com o caminhão parado e depois de escolher o país '
            'de fim. Confirme que parou, ligue a ignição e segure a tecla da '
            'ranhura. Se ainda assim não sair, não force: pode imprimir o '
            'talão, anotar e levar a uma oficina autorizada.',
        'Manual do tacógrafo',
        ['preso', 'nao sai', 'cartao preso', 'encravado', 'nao ejeta']),
  ]),

  // ------------------------------------------- Função OUT e hora do tacógrafo
  FaqGroup('Função OUT e hora do tacógrafo', Icons.schedule_rounded, [
    Faq('O que é a função OUT do tacógrafo?',
        'OUT ("out of scope") marca a condução fora do âmbito da lei do '
            'tacógrafo. Só pode ser usada em transportes que a lei não obriga '
            'a registar (isenções do art. 3.º ou isenções nacionais do '
            'art. 13.º). Viagens normais, ir vazio carregar ou ir à oficina '
            'não são OUT.',
        '$_r561, art. 3.º e art. 13.º',
        ['o out', 'fora do ambito', 'out of scope', 'funcao out', 'modo out']),
    Faq('Como ligo e desligo o OUT?',
        'Caminhão parado. VDO: OK > setas até "Entrada veículo" > OK > '
            '"OUT início" > OK. Para desligar: "Entrada veículo" > "OUT fim" '
            '> OK. O OUT também acaba sozinho quando mete ou tira o cartão. '
            'Noutras marcas o caminho é parecido, no menu de entradas do '
            'veículo.',
        '$_r165; manual do tacógrafo',
        ['ligar o out', 'desligar o out', 'ativar out', 'out inicio',
          'out fim', 'meter out', 'por out']),
    Faq('A condução em OUT conta para alguma coisa?',
        'Não conta como condução para os limites do tacógrafo, mas, feita '
            'para a empresa, conta como outros trabalhos (martelo) no tempo '
            'de trabalho. No TacoGuard corrija esse trecho para martelo no '
            'Histórico. Usar OUT sem ter direito é infração e pode ser '
            'tratado como registo falso.',
        '$_r561, art. 4.º, al. e)',
        ['out conta', 'conducao em out', 'out martelo', 'usar out']),
    Faq('Como mudo a hora no tacógrafo (verão / inverno)?',
        'Caminhão parado. VDO: OK > setas até "Entrada veículo" > OK > '
            '"Hora local" > OK > mude com as setas em passos de 30 minutos > '
            'OK. A hora muda no último domingo de março (adianta 1 h) e no '
            'último domingo de outubro (atrasa 1 h). Só muda o visor: o '
            'tacógrafo continua a gravar em UTC.',
        '$_r165; manual do tacógrafo',
        ['mudar a hora', 'mudar hora', 'acertar a hora', 'hora local',
          'hora de verao', 'hora de inverno', 'mudanca de hora',
          'atrasar', 'adiantar', 'relogio']),
    Faq('O que é a hora UTC do tacógrafo?',
        'É a hora universal (a de Portugal no inverno). O tacógrafo grava e '
            'imprime tudo em UTC; a semana também conta em UTC. Portugal: '
            'inverno = UTC, verão = UTC + 1. Espanha, França, Alemanha: '
            'inverno = UTC + 1, verão = UTC + 2.',
        '$_r165',
        ['utc', 'hora universal', 'fuso', 'fuso horario', 'diferenca de hora',
          'hora do talao']),
    Faq('A hora UTC do tacógrafo está errada. Posso acertar?',
        'A hora local do visor pode sempre. A hora UTC quem acerta é a '
            'oficina autorizada. Alguns modelos antigos deixam o motorista '
            'corrigir até 1 minuto por semana ("Correção UTC" no menu '
            '"Entrada veículo").',
        '$_r165; manual do tacógrafo',
        ['hora errada', 'utc errada', 'correcao utc', 'acertar utc',
          'hora adiantada', 'hora atrasada']),
    Faq('Passei para outro país. Tenho de mudar a hora?',
        'Não é obrigatório: a gravação é sempre em UTC. Se quiser ver a hora '
            'certa no visor, mude a hora local (Entrada veículo > Hora local). '
            'No TacoGuard não precisa mudar nada.',
        '$_r165',
        ['outro pais', 'mudar de pais', 'fuso de espanha', 'hora de espanha',
          'hora de franca']),
  ]),

  // ------------------------------------------------- Multas e gravidade
  FaqGroup('Multas e gravidade das infrações', Icons.gavel_rounded, [
    Faq('Como são classificadas as infrações?',
        'A UE tem uma tabela comum de gravidade, por escalões: leve (MI), '
            'grave (SI), muito grave (VSI) e gravíssima (MSI). Quanto mais '
            'passa do limite, mais grave. O valor da multa em euros é cada '
            'país que decide; a gravidade é igual em toda a UE.',
        'Diretiva 2006/22/CE, anexo III; Reg. (UE) 2016/403',
        ['classificadas', 'gravidade', 'leve', 'grave', 'muito grave',
          'gravissima', 'escalao', 'escaloes', 'tipo de infracao']),
    Faq('O que acontece se fizer 99 ou 100 horas em duas semanas?',
        'O limite é 90 horas. De mais de 90 até menos de 100 horas é '
            'infração leve. De 100 até menos de 112h30 já é grave '
            '(100 a 105 grave; 105 a 112h30 muito grave). A partir de '
            '112h30 (25% a mais) é gravíssima. Por isso 99 horas é leve e '
            '100 horas já sobe de escalão.',
        'Reg. 561/2006, art. 6.º, n.º 3; Reg. (UE) 2016/403',
        ['99', '100 horas', '99 horas', '105', '112', 'passar das 90',
          'mais de 90', 'duas semanas multa']),
    Faq('E se passar das 56 horas na semana?',
        'De mais de 56 até menos de 60 horas é leve. De 60 a 65 grave; de 65 '
            'a 70 muito grave. A partir de 70 horas (25% a mais) é '
            'gravíssima.',
        'Reg. 561/2006, art. 6.º, n.º 2; Reg. (UE) 2016/403',
        ['passar das 56', 'mais de 56', '60 horas semana', '65', '70 horas',
          'semana multa']),
    Faq('E se conduzir mais de 4h30 sem pausa?',
        'De 4h30 até 5 horas é leve. De 5 a 6 horas é grave. Mais de '
            '6 horas sem pausa é muito grave.',
        'Reg. 561/2006, art. 7.º; Diretiva 2006/22/CE, anexo III',
        ['mais de 4h30', '5 horas sem pausa', 'sem pausa multa',
          'passar das 4h30', '6 horas sem pausa']),
    Faq('Qual é a infração mais grave na condução diária?',
        'Passar 50% do limite diário sem pausa nem descanso de pelo menos '
            '4h30: 13h30 de condução num dia de 9 horas, ou 15 horas num '
            'dia de 10 horas. É gravíssima.',
        'Reg. 561/2006, art. 6.º, n.º 1; Reg. (UE) 2016/403',
        ['13h30', '13 horas e meia', 'conducao diaria multa',
          'passar das 9', 'passar das 10', 'gravissima diaria']),
    Faq('Qual é o valor das multas?',
        'Muda de país para país. A gravidade (leve, grave, muito grave, '
            'gravíssima) é igual em toda a UE, mas o valor em euros é cada '
            'país que fixa, e pode ir de dezenas a milhares de euros. Em '
            'vários países a multa é cobrada na hora ao motorista '
            'estrangeiro, e o caminhão pode ficar imobilizado até pagar.',
        'Diretiva 2006/22/CE; Reg. 561/2006, art. 19.º',
        ['multa', 'multas', 'coima', 'valor', 'quanto pago', 'euros',
          'pagar na hora']),
    Faq('A empresa também é multada?',
        'Pode ser. A empresa responde pelas infrações dos seus motoristas, a '
            'não ser que prove que organizou bem o trabalho. As infrações '
            'graves e gravíssimas repetidas podem levar a empresa a perder a '
            'idoneidade (a licença de transportador).',
        'Reg. 561/2006, art. 10.º; Reg. (CE) 1071/2009',
        ['empresa multada', 'empresa tambem', 'idoneidade', 'licenca',
          'responsabilidade da empresa']),
    Faq('A polícia de outro país pode multar infrações de dias atrás?',
        'Pode. Numa fiscalização o agente vê o dia atual e os 56 dias '
            'anteriores e pode multar infrações desse período, mesmo que '
            'tenham sido noutro país.',
        'Reg. 561/2006, art. 19.º, n.º 2',
        ['dias atras', 'outro pais', 'infracao antiga', 'multar depois',
          'semana passada']),
  ]),

  // --------------------------------------------------- Tempo de trabalho
  FaqGroup('Tempo de trabalho (martelo)', Icons.construction_rounded, [
    Faq('Quanto tempo posso trabalhar sem pausa (martelo)?',
        'Não mais de 6 horas seguidas de trabalho sem pausa. De 6 a 9 horas '
            'de trabalho: 30 minutos de pausa; mais de 9 horas: 45 minutos. '
            'Podem ser divididas em partes de pelo menos 15 minutos.',
        'Diretiva 2002/15/CE, art. 5.º',
        ['trabalhar sem pausa', '6 horas', 'seis horas seguidas']),
    Faq('Quantas horas posso trabalhar por semana?',
        'Em média 48 horas por semana (condução + martelo + '
            'carga/descarga). Numa semana pode chegar a 60 horas, desde que '
            'a média de 4 meses não passe de 48.',
        'Diretiva 2002/15/CE, art. 4.º',
        ['trabalhar por semana', '48 horas', '60 horas', 'horas de trabalho',
          'media']),
    Faq('O martelo conta para as 9 horas de condução?',
        'Não. As 9 (ou 10) horas são só de condução. Mas o martelo conta '
            'para o tempo de trabalho (48/60 horas), para as 6 horas sem '
            'pausa e para a amplitude.',
        '$_r561, art. 6.º; Diretiva 2002/15/CE',
        ['martelo conta para', 'conta para as 9', 'soma na conducao']),
    Faq('Carga e descarga contam como trabalho?',
        'Sim. Carregar, descarregar, ajudar, vigiar a carga, limpar, '
            'abastecer e tratar de papéis é trabalho (martelo). No '
            'TacoGuard aparece separado como Carga/Descarga, mas soma como '
            'trabalho.',
        'Diretiva 2002/15/CE, art. 3.º, al. a)',
        ['carga e descarga', 'carregar', 'descarregar', 'abastecer',
          'limpar', 'lavar']),
    Faq('Como é com trabalho noturno?',
        'Se fizer trabalho no período noturno, o tempo de trabalho não pode '
            'passar de 10 horas em cada 24 horas. O período noturno é '
            'definido pela lei de cada país (pelo menos 4 horas entre as '
            '00:00 e as 7:00).',
        'Diretiva 2002/15/CE, art. 7.º',
        ['noturno', 'noite', 'madrugada', 'trabalho de noite']),
  ]),

  // ----------------------------------------- Dois motoristas, ferry, etc.
  FaqGroup('Dois motoristas e ferry', Icons.groups_rounded, [
    Faq('E com dois motoristas?',
        'Cada um faz um descanso diário de pelo menos 9 horas dentro das '
            '30 horas depois do descanso anterior. Os limites de condução '
            '(4h30, 9/10 h, 56 h, 90 h) são iguais para cada um.',
        '$_r561, art. 8.º, n.º 5',
        ['dois motoristas', 'dupla', 'tripulacao', 'equipe', '30 horas',
          'dupla tripulacao']),
    Faq('Com dois motoristas, qual é a amplitude?',
        'Até 21 horas (30 horas menos as 9 de descanso). Na primeira hora o '
            'segundo motorista pode ainda não estar a bordo; depois disso '
            'tem de estar.',
        '$_r561, art. 4.º, al. o), e art. 8.º, n.º 5',
        ['21 horas', 'amplitude dupla', 'amplitude com dois']),
    Faq('Com dois motoristas, a pausa pode ser com o caminhão a andar?',
        'Pode. O motorista que vai ao lado pode fazer a pausa de 45 minutos '
            'com o caminhão a andar, desde que não ajude quem conduz. O '
            'descanso diário não: tem de ser com o veículo parado.',
        '$_r561, art. 7.º',
        ['pausa a andar', 'caminhao a andar', 'ao lado', 'passageiro',
          'colega a conduzir']),
    Faq('E no ferry ou no comboio?',
        'O descanso diário regular ou o semanal reduzido podem ser '
            'interrompidos no máximo 2 vezes, somando até 1 hora, para '
            'embarcar e desembarcar, com acesso a cama. No descanso semanal '
            'regular isso só vale se a travessia durar 8 horas ou mais e '
            'houver camarote.',
        '$_r561, art. 9.º',
        ['ferry', 'barco', 'comboio', 'trem', 'balsa', 'travessia',
          'embarcar']),
  ]),

  // ----------------------------------------------------------------- App
  FaqGroup('Como usar o TacoGuard', Icons.phone_android_rounded, [
    Faq('Como começo a jornada no TacoGuard?',
        'Na tela Hoje, toque em Iniciar jornada e confirme no pop-up. O início é sempre manual, '
            'para o app não abrir a jornada sozinho quando anda de carro. '
            'Depois disso o GPS faz o resto.',
        _app,
        ['comeco a jornada', 'iniciar jornada', 'abrir a jornada',
          'comecar o dia']),
    Faq('Como o TacoGuard sabe que parei?',
        'Pelo GPS. Depois de alguns minutos parado (você escolhe o tempo em '
            'Ajustes) ele grava o local e pergunta: Pausa, Martelo ou '
            'Carga/Descarga. Sem resposta, a parada fica "a classificar" e '
            'conta como pausa até você corrigir.',
        _app,
        ['sabe que parei', 'gps', 'classificar', 'detecta']),
    Faq('O pop-up da parada não aparece. O que faço?',
        'Em Ajustes, libere "Sobrepor a outros apps" e deixe a bateria '
            '"Sem restrições". Confira também se a localização está em '
            '"Permitir o tempo todo". Enquanto isso, responda pelo cartão '
            '"Parado há…" na tela Hoje.',
        _app,
        ['pop-up', 'popup', 'nao aparece', 'nao apareceu', 'janela',
          'sobrepor']),
    Faq('Vou almoçar de carro. Como faço?',
        'Com o caminhão parado, toque em "Vou sair de carro" antes de sair. '
            'O trajeto de carro não conta como condução e a pausa continua. '
            'Ao voltar para perto do caminhão o app retoma sozinho.',
        _app,
        ['almocar', 'sair de carro', 'vou sair', 'de carro', 'boleia']),
    Faq('Encerrei a jornada e surgiu outra viagem. E agora?',
        'Na tela Hoje, toque em Reabrir a jornada. Dá para reabrir enquanto '
            'o descanso não chegou a 9 horas. A amplitude continua a contar '
            'desde o início original.',
        _app,
        ['reabrir', 'encerrei', 'fechei a jornada', 'ultima hora',
          'por engano']),
    Faq('Como corrijo uma parada marcada errada?',
        'Em Histórico, abra a jornada e toque no trecho. Pode trocar o tipo '
            '(condução, pausa, martelo, carga/descarga) e escrever o nome '
            'do local. Antes de gravar, o app pede confirmação.',
        _app,
        ['corrijo', 'corrigir', 'marcada errada', 'trocar o tipo',
          'editar']),
    Faq('Apaguei uma jornada sem querer. Dá para recuperar?',
        'Sim, logo a seguir. Ao apagar, o app pede confirmação e depois '
            'mostra uma barra com DESFAZER e uma contagem de 8 segundos. '
            'Toque em DESFAZER antes de acabar a contagem e a jornada volta '
            'inteira. Passados os 8 segundos, só um backup a recupera.',
        _app,
        ['apaguei', 'apagar jornada', 'excluir', 'desfazer', 'recuperar',
          'sem querer apaguei']),
    Faq('Como faço o relatório em PDF?',
        'Na tela Relatórios escolha Diário, Semanal, Bissemanal ou Mensal, '
            'ande com as setas até a data e toque em Abrir PDF, Salvar ou '
            'Compartilhar. O nome do motorista e a matrícula saem no '
            'cabeçalho.',
        _app,
        ['relatorio', 'pdf', 'imprimir relatorio', 'mensal']),
    Faq('Onde coloco o meu nome e a matrícula?',
        'Em Ajustes > Relatórios. Os dois saem no cabeçalho dos PDF e vão '
            'no backup.',
        _app,
        ['matricula', 'meu nome', 'nome do motorista', 'placa']),
    Faq('Como faço e restauro o backup?',
        'Em Ajustes > Backup: Salvar guarda um arquivo no telefone, '
            'Compartilhar manda por WhatsApp, e-mail ou Drive, e Restaurar '
            'backup traz tudo de volta (substitui o que está no app).',
        _app,
        ['backup', 'restaurar', 'copia de seguranca', 'trocar de telefone',
          'perder os dados']),
    Faq('Como atualizo o TacoGuard?',
        'O app avisa quando há versão nova. Também pode ir em Ajustes > '
            'Sobre > Procurar atualização. As jornadas e as configurações '
            'continuam.',
        _app,
        ['atualizo', 'atualizar', 'atualizacao', 'versao nova',
          'nova versao']),
    Faq('Os quilômetros do app batem com o hodômetro?',
        'Quase. Os km são medidos pelo GPS e costumam diferir 1 a 3% do '
            'hodômetro. O trajeto no modo "de carro" não entra na conta.',
        _app,
        ['quilometros', 'km', 'hodometro', 'distancia']),
    Faq('O GPS para quando a tela apaga?',
        'Não deve parar. Para o celular não cortar o GPS, em Ajustes toque '
            'em Abrir ajustes de bateria e deixe o TacoGuard "Sem '
            'restrições".',
        _app,
        ['tela apaga', 'tela apagada', 'bateria', 'gps para',
          'sem restricoes']),
    Faq('O TacoGuard substitui o tacógrafo?',
        'Não. É um auxiliar para o motorista se organizar. O registo '
            'oficial é o do tacógrafo e do cartão, e pode haver diferenças '
            'de alguns minutos entre os dois.',
        _app,
        ['substitui', 'oficial', 'vale na fiscalizacao', 'diferenca']),
  ]),
];

/// Todas as perguntas prontas, na ordem dos grupos.
final List<Faq> kFaq = [for (final g in kFaqGroups) ...g.items];

const _stop = {
  'que', 'como', 'para', 'posso', 'pode', 'quanto', 'quantas', 'quantos',
  'uma', 'com', 'por', 'dos', 'das', 'nos', 'nas', 'tenho', 'ser', 'mais',
  'hora', 'horas', 'tempo', 'fazer', 'faco', 'qual', 'quando', 'the', 'meu',
  'minha', 'isso', 'esta', 'esse', 'nao', 'sim', 'tem', 'ter', 'foi',
};

/// Normaliza e troca sinónimos (dirigir = conduzir, parque = park...).
String _n(String s) => norm(s)
    .replaceAll('dirigir', 'conduzir')
    .replaceAll('guiar', 'conduzir')
    .replaceAll('parque', 'park')
    .replaceAll('ticket', 'talao')
    .replaceAll('camiao', 'caminhao')
    .replaceAll('camioes', 'caminhoes');

List<String> _words(String s) => _n(s)
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.length >= 3 && !_stop.contains(w))
    .toList();

/// Pontos de [f] para a pergunta já normalizada [q].
int _faqScore(Faq f, String q, List<String> qWords) {
  var score = 0;
  for (final k in f.keys) {
    if (q.contains(_n(k))) score += k.length > 4 ? 3 : 1;
  }
  final fw = _words(f.q).toSet();
  for (final w in qWords) {
    if (fw.contains(w)) score += 1;
  }
  return score;
}

/// Melhor resposta pronta para [question], ou null.
Faq? faqMatch(String question) {
  final q = _n(question).trim();
  for (final f in kFaq) {
    if (_n(f.q).trim() == q) return f; // tocou numa pergunta da lista
  }
  final qw = _words(q);
  Faq? best;
  var bestScore = 0;
  for (final f in kFaq) {
    final score = _faqScore(f, q, qw);
    if (score > bestScore) {
      bestScore = score;
      best = f;
    }
  }
  return bestScore >= 2 ? best : null;
}

/// Perguntas prontas que combinam com o que está a ser escrito.
List<Faq> faqFilter(String text) {
  final q = _n(text).trim();
  final qw = _words(q);
  if (qw.isEmpty) return kFaq;
  final scored = <(int, Faq)>[];
  for (final f in kFaq) {
    final s = _faqScore(f, q, qw);
    if (s > 0) scored.add((s, f));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final x in scored) x.$2];
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
      final all = faqFilter(q);
      final near =
          identical(all, kFaq) ? <Faq>[] : all.take(3).toList();
      _msgs.add(_Msg(
          near.isEmpty
              ? 'Não encontrei essa resposta nas perguntas prontas. Veja o '
                  'menu "Lei" ou tente com outras palavras (ex.: pausa, '
                  'descanso, amplitude, talão, park, cartão).'
              : 'Não encontrei uma resposta certa. Perguntas parecidas:\n'
                  '${near.map((f) => '• ${f.q}').join('\n')}\n\n'
                  'Toque em "Nova consulta" para ver a lista completa.',
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

  Widget _faqCard(Faq f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _send(f.q),
          child: Row(children: [
            Expanded(child: Text(f.q, style: const TextStyle(fontSize: 15))),
            const Icon(Icons.chevron_right_rounded, color: TG.muted),
          ]),
        ),
      );

  /// Perguntas prontas: por assunto, ou filtradas pelo que está escrito.
  List<Widget> _faqList() {
    final typed = _ctrl.text.trim();
    if (typed.length >= 3) {
      final found = faqFilter(typed);
      return [
        Text(
            found.isEmpty
                ? 'Nenhuma pergunta pronta com essas palavras. Toque em '
                    'enviar para procurar na lei.'
                : 'Perguntas prontas sobre "$typed"',
            style: const TextStyle(
                color: TG.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final f in found.take(12)) _faqCard(f),
      ];
    }
    return [
      Text('${kFaq.length} perguntas prontas, sem internet. Toque numa ou '
          'escreva abaixo para procurar.',
          style: const TextStyle(color: TG.muted, fontSize: 13)),
      const SizedBox(height: 4),
      for (final g in kFaqGroups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
          child: Row(children: [
            Icon(g.icon, size: 18, color: TG.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(g.title,
                  style: const TextStyle(
                      color: TG.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        for (final f in g.items) _faqCard(f),
      ],
    ];
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
                  label: Fit('Offline')),
              ButtonSegment(
                  value: true,
                  enabled: aiAvailable,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Fit(aiAvailable ? 'IA' : 'IA (sem chave)')),
            ],
            selected: {_useAi},
            onSelectionChanged: (s) => setState(() => _useAi = s.first),
          ),
        ),
        Expanded(
          child: _msgs.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: _faqList(),
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
                  onChanged: (_) {
                    if (_msgs.isEmpty) setState(() {});
                  },
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                      hintText: 'Pergunte sobre a lei'),
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
