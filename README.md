# TacoGuard

App Android para o motorista de caminhão controlar a jornada pela lei do tacógrafo na Europa (Regulamento (CE) n.º 561/2006, com as alterações do Regulamento (UE) 2020/1054).

> O TacoGuard é um auxiliar. O registro oficial é o do tacógrafo, e pode haver pequenas diferenças de minutos entre os dois.

## Baixar

O APK mais novo fica em [Releases](https://github.com/tecsattv-gif/TacoGuard/releases/latest). Depois de instalado, o próprio app avisa quando há versão nova e instala com a sua autorização.

## O que o app faz

- **Jornada automática por GPS**: toque em *Iniciar jornada* de manhã. Arrancou, conta condução. Parou, grava as coordenadas, a hora e o tempo parado.
- **Pop-up a cada parada**: depois de alguns minutos parado (1 a 5, você escolhe; o padrão é 2) aparece a pergunta *Pausa, Martelo ou Carga/Descarga?*, por cima do Google Maps ou de outro app. Sem resposta, a parada fica "a classificar" (conta como pausa até ser corrigida).
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
- **Consulta**: perguntas e respostas prontas (offline) e IA (Gemini), que responde só com base no resumo da lei que está no app.
- **Backup**: salvar, compartilhar e restaurar as jornadas.

## Como usar

1. Abra o app e toque em **Iniciar jornada**. Aceite as permissões de localização e de "Sobrepor a outros apps".
2. Em **Ajustes**, toque em *Abrir ajustes de bateria* e deixe o TacoGuard "Sem restrições", para o celular não cortar o GPS com a tela apagada.
3. Dirija normalmente. Quando parar, responda ao pop-up.
4. No fim do dia, toque em **Encerrar jornada**. Começa a contar o descanso.

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

- **1.3.0**: local de cada pausa e de cada descanso. As pausas aparecem com o tipo (15, 30 ou 45 min) e as coordenadas; os descansos (9 h, 11 h, 24 h, 45 h) aparecem com as coordenadas do local onde a jornada foi encerrada, na tela Hoje, no Histórico e numa tabela própria do PDF.
- **1.2.0**: quilômetros rodados pelo GPS: total do dia na tela Hoje, por jornada e por trecho no Histórico e nos relatórios PDF (com o total do período). O trajeto no modo "de carro" não entra na conta.
- **1.1.0**: botão **Vou sair de carro**. Com o caminhão parado (pausa, martelo ou carga/descarga), o motorista pode sair de carro sem o app contar condução: a parada continua e tudo volta ao normal sozinho quando ele chega de volta ao caminhão. Ao corrigir um trecho, trechos vizinhos do mesmo tipo são unidos (a pausa volta a somar inteira).
- **1.0.1**: a parada não era detectada quando o GPS "pulava" com o caminhão parado (o pop-up não aparecia); agora só conta como arranque se o caminhão sair do lugar. Novo cartão "Parado há…" na tela Hoje, para responder antes do pop-up. Aviso de GPS sem sinal. Cartões da tela Hoje alinhados.
- **1.0.0**: primeira versão.

Desenvolvido por Luiz Alberto Cardoso.
