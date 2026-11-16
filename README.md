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

- **1.0.0**: primeira versão.

Desenvolvido por Luiz Alberto Cardoso.
