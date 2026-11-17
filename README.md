# TacoGuard

App Android para o motorista de caminhão controlar a jornada pela lei do tacógrafo na Europa (Regulamento (CE) n.º 561/2006, com as alterações do Regulamento (UE) 2020/1054).

> O TacoGuard é um auxiliar. O registro oficial é o do tacógrafo, e pode haver pequenas diferenças de minutos entre os dois.

## Baixar

O APK mais novo fica em [Releases](https://github.com/tecsattv-gif/TacoGuard/releases/latest). Depois de instalado, o próprio app avisa quando há versão nova e instala com a sua autorização.

## O que o app faz

- **Jornada automática por GPS**: toque em *Iniciar jornada* de manhã e confirme no pop-up. Arrancou, conta condução. Parou, grava as coordenadas, a hora e o tempo parado.
- **Pop-up a cada parada**: depois de alguns minutos parado (1 a 5, você escolhe; o padrão é 2) aparece a pergunta *Pausa, Martelo ou Carga/Descarga?*, por cima do Google Maps ou de outro app. Sem resposta, a parada fica "a classificar" (conta como pausa até ser corrigida). Se arrancar antes de 15 minutos sem ter respondido, a parada vira **martelo** sozinha, porque menos de 15 minutos não conta como pausa pela lei.
- **Tela Hoje fácil de ler na cabine**: um número principal (o anel com o tempo que falta para a pausa), a faixa colorida do dia como o disco do tacógrafo (condução, pausa, martelo, carga/descarga) com os km, e todos os limites numa lista só, com barra verde, amarela ou vermelha.
- **Condução contínua**: anel com o tempo que falta para as 4h30 e controle da pausa de 45 min (ou 15 + 30).
- **Limites**: condução diária (9 h, 10 h duas vezes por semana), semanal (56 h), duas semanas (90 h), amplitude (13 h / 15 h), descansos diários reduzidos (3 entre descansos semanais) e prazo do descanso semanal.
- **Local das pausas e dos descansos**: cada pausa (15, 30, 45 min) e cada descanso (9 h, 11 h, 24 h, 45 h) fica com as coordenadas geográficas do local, com atalho para abrir no mapa e tabela no PDF.
- **Quilômetros**: distância rodada em condução, medida pelo GPS (costuma diferir 1 a 3% do hodômetro), por trecho, por jornada e por período.
- **Sair de carro na pausa**: toque em *Vou sair de carro* antes de sair (por exemplo, para almoçar). O trajeto de carro não conta como condução e a pausa continua; ao voltar para perto do caminhão o app retoma o controle normal.
- **Avisos por voz**: 30 e 15 minutos antes da pausa, pausa completa, limites do dia, da semana e da amplitude.
- **Descanso**: com a jornada encerrada, mostra o tempo de descanso e quando chega às 9 h e às 11 h.
- **Histórico**: todas as jornadas, com avisos de limite excedido. Cada trecho pode ser corrigido (tipo, nome do local) e aberto no mapa.
- **Relatórios em PDF**: diário, semanal, bissemanal e mensal. Abrir, salvar no telefone ou compartilhar.
- **Lei do tacógrafo**: resumo por tema, com o artigo, busca e funcionando sem internet.
- **Consulta**: 150 perguntas e respostas prontas (offline), agrupadas por assunto e com busca, e IA (Gemini), que responde só com base no resumo da lei que está no app.
- **Passar do tempo (art. 12.º)**: passo a passo para quando não há vaga no park ou para chegar a casa, com o que escrever atrás do talão.
- **Usar o tacógrafo**: passo a passo para começar o dia (cartão, entrada manual, país), mudar a atividade, fazer a pausa, fronteira, carga/descarga, ferry, acabar o dia, imprimir talões, trocar o papel, idioma, avisos, erros, dois motoristas e oficina.
- **Função OUT e hora do tacógrafo**: o que é o OUT (fora do âmbito), quando pode e não pode ser usado e como ligar/desligar; como mudar a hora local (verão/inverno, outro país) e o que é a hora UTC.
- **Backup**: salvar, compartilhar e restaurar as jornadas.

## Como usar

1. Abra o app e toque em **Iniciar jornada** e confirme no pop-up. Aceite as permissões de localização e de "Sobrepor a outros apps".
2. Em **Ajustes**, toque em *Abrir ajustes de bateria* e deixe o TacoGuard "Sem restrições", para o celular não cortar o GPS com a tela apagada.
3. Dirija normalmente. Quando parar, responda ao pop-up.
4. No fim do dia, toque em **Encerrar jornada**. Começa a contar o descanso.
5. Encerrou cedo demais? Toque em **Reabrir a jornada** (disponível até o descanso chegar a 9 h).
6. Apagou uma jornada sem querer? Toque em **DESFAZER** na barra que aparece (8 segundos).

## Regras usadas

| Regra | Limite |
|---|---|
| Condução contínua | 4h30, depois pausa de 45 min (ou 15 + 30) |
| Condução diária | 9 h (10 h duas vezes por semana) |
| Condução semanal | 56 h |
| Condução em duas semanas | 90 h |
| Descanso diário | 11 h (reduzido 9 h, 3 vezes entre descansos semanais) |
| Amplitude | 13 h (15 h com descanso reduzido) |
| Descanso semanal | 45 h (reduzido 24 h), no máximo 144 h depois do anterior |

A semana é contada em hora UTC (segunda 00:00 a domingo 24:00), como no tacógrafo. O app controla um motorista só (sem tripulação múltipla).

## Compilar

Cada envio para o `main` compila o APK no GitHub Actions, roda os testes das regras e publica numa Release com a versão do `pubspec.yaml`.

Segredos do repositório (Settings > Secrets and variables > Actions):

- `TACOGUARD_KEYSTORE`: qualquer texto longo, só seu. Serve de senha da chave de assinatura fixa do APK (sem ela as atualizações não instalam por cima).
- `GEMINI_API_KEY`: chave do Google Gemini para a consulta por IA. Opcional: sem ela o app compila e a consulta fica só offline.

## Versões

- **1.7.2**: Pausa completa (45 min, ou 15 + 30) zera a condução contínua e o contador volta às **4h30**, mesmo quando a pausa ficou gravada em pedaços seguidos ("a classificar" + pausa, ou partida por um pulo do GPS de poucos segundos). Martelo ou carga no meio continuam cortando a pausa, como na lei. O anel da tela Hoje mostra o que falta pelo limite que chega primeiro: a pausa, as **9 h/10 h do dia** ou a semana (ex.: depois de 9h de condução num dia de 10 h, mostra "Faltam 1h00 para as 10h do dia"), e há uma linha com a condução do dia e o que falta.
- **1.7.1**: Parada curta sem resposta: se o caminhão arrancar antes de 15 minutos e a parada ainda estiver "a classificar", ela vira **martelo** sozinha. Paradas de 15 minutos ou mais continuam "a classificar" (contam como pausa até corrigir). Paradas já respondidas não mudam.
- **1.7.0**: **Novo visual das telas** (revisão com a skill Impeccable, seguindo o Material 3 do Android). Tela *Hoje*: faixa do estado atual na cor da atividade, anel da pausa como número principal, nova **faixa do dia** colorida com os km, os quatro limites (condução, amplitude, semana, duas semanas) numa **lista só**, e escolha da atividade à mão num bloco único com a atual destacada. Tela de descanso: "Em descanso desde HH:MM", número grande e um só botão principal. **Pergunta da parada** dentro do app: três botões grandes, um embaixo do outro, com o que cada um quer dizer. O pop-up por cima dos outros apps continua do mesmo tamanho. As explicações de uso saíram da tela e foram para a Lei, no novo tema *Como o TacoGuard conta os tempos*. Leitores de tela (TalkBack) leem os limites e a atividade escolhida.
- **1.6.5**: **Confirmação ao iniciar a jornada**: ao tocar em *Iniciar jornada* aparece um pop-up perguntando se quer mesmo começar (com a hora), para não abrir a jornada por engano. Se o descanso ainda não chegou às 9 h, o pop-up avisa quanto falta. **Proteção contra acidentes nas edições**: trocar o tipo de um trecho ou mudar a nota pede confirmação. **Apagar com Desfazer**: ao apagar uma jornada aparece uma barra com DESFAZER e contagem de 8 segundos para recuperar tudo. Nova pergunta na Consulta sobre recuperar jornada apagada. 150 perguntas offline.
- **1.6.4**: **Cartão do tacógrafo: certo e errado**: novo tema na Lei (obrigações e cuidados) e novo assunto na Consulta (14 perguntas): obrigações do motorista, o que é proibido, cuidados com o cartão, lado certo de meter, um só cartão, pedido e validade, mudança de país ou de empresa, a empresa não pode ficar com o cartão, troca de caminhão a meio do dia, tacógrafo de disco, PIN, cartão encontrado depois de perdido e cartão preso. 149 perguntas offline.
- **1.6.3**: **Usar o tacógrafo**: dois assuntos novos na Consulta (29 perguntas) e novo tema na Lei, com o passo a passo do tacógrafo (começar e acabar o dia, entrada manual, atividades, pausa, fronteira, carga/descarga, ferry, talões, papel, idioma, avisos, erros, dois motoristas, oficina). **Função OUT e hora do tacógrafo**: novo tema na Lei e novo assunto na Consulta (7 perguntas). OUT explicado (fora do âmbito, quando pode usar, como ligar e desligar, conta como martelo) e passo a passo para mudar a hora local no tacógrafo (verão/inverno, outro país, hora UTC). 135 perguntas offline.
- **1.6.2**: email de contato (tecsattv@gmail.com) nos créditos da abertura, em Ajustes > Sobre e no README. Textos da tela Hoje (condução contínua e próxima pausa) já não quebram.
- **1.6.1**: **Multas e gravidade das infrações**: novo assunto na Consulta e novo tema na Lei, com os escalões da UE (leve, grave, muito grave, gravíssima). Ex.: em duas semanas, até menos de 100 h é leve e a partir de 100 h já é grave; na semana, de 60 h em diante é grave. 99 perguntas offline.
- **1.6.0**: **92 perguntas e respostas offline**, por assunto (condução, pausas, descansos, artigo 12.º, tacógrafo e cartão, tempo de trabalho, dois motoristas e ferry, uso do app), com busca enquanto escreve e sugestão de perguntas parecidas. **Passar do tempo (art. 12.º)** explicado passo a passo: procurar park depois de o horário acabar, hora ou 2 horas a mais para chegar a casa, como imprimir o talão e o que escrever atrás. Textos de botões e abas já não ficam partidos com letra grande no telefone.
- **1.5.0**: **Matrícula do veículo** em Ajustes > Relatórios: sai no cabeçalho dos relatórios PDF, junto com o nome do motorista, e vai no backup. Créditos em destaque na tela de abertura (splash), com a versão do app.
- **1.4.0**: **Reabrir a jornada**. Encerrou e surgiu uma viagem de última hora? Enquanto o descanso não chega a 9 h, a jornada pode ser reaberta: a amplitude e os tempos continuam contando desde o início original, e o intervalo fechado entra como pausa ou martelo.
- **1.3.0**: local de cada pausa e de cada descanso. As pausas aparecem com o tipo (15, 30 ou 45 min) e as coordenadas; os descansos (9 h, 11 h, 24 h, 45 h) aparecem com as coordenadas do local onde a jornada foi encerrada, na tela Hoje, no Histórico e numa tabela própria do PDF.
- **1.2.0**: quilômetros rodados pelo GPS: total do dia na tela Hoje, por jornada e por trecho no Histórico e nos relatórios PDF (com o total do período). O trajeto no modo "de carro" não entra na conta.
- **1.1.0**: botão **Vou sair de carro**. Com o caminhão parado (pausa, martelo ou carga/descarga), o motorista pode sair de carro sem o app contar condução: a parada continua e tudo volta ao normal sozinho quando ele chega de volta ao caminhão. Ao corrigir um trecho, trechos vizinhos do mesmo tipo são unidos (a pausa volta a somar inteira).
- **1.0.1**: a parada não era detectada quando o GPS "pulava" com o caminhão parado (o pop-up não aparecia); agora só conta como arranque se o caminhão sair do lugar. Novo cartão "Parado há…" na tela Hoje, para responder antes do pop-up. Aviso de GPS sem sinal. Cartões da tela Hoje alinhados.
- **1.0.0**: primeira versão.

Desenvolvido por Luiz Alberto Cardoso (tecsattv@gmail.com).
