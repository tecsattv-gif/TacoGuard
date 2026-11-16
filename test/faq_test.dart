import 'package:flutter_test/flutter_test.dart';
import 'package:tacoguard/assistant.dart';

void main() {
  test('perguntas prontas: sem repetidas e todas completas', () {
    final seen = <String>{};
    for (final f in kFaq) {
      expect(seen.add(f.q), isTrue, reason: 'repetida: ${f.q}');
      expect(f.a.trim(), isNotEmpty, reason: f.q);
      expect(f.ref.trim(), isNotEmpty, reason: f.q);
      expect(f.keys, isNotEmpty, reason: f.q);
    }
    expect(kFaq.length, greaterThan(80));
  });

  test('tocar numa pergunta da lista devolve a resposta dela', () {
    for (final f in kFaq) {
      expect(faqMatch(f.q), same(f), reason: f.q);
    }
  });

  test('perguntas escritas pelo motorista caem na resposta certa', () {
    String? q(String s) => faqMatch(s)?.q;
    expect(q('não encontrei park e o horário acabou'),
        'O tempo acabou e não achei vaga no park. O que faço?');
    expect(q('o que coloco atrás do ticket'),
        'O que escrevo atrás do talão (ticket)?');
    expect(q('que lei eu ponho no talão'), 'Que lei coloco no talão?');
    expect(q('hora extraordinária para chegar em casa'),
        'Posso conduzir mais para chegar em casa?');
    expect(q('perdi o cartão'),
        'Perdi o cartão ou foi roubado. Posso conduzir?');
  });
}
