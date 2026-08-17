# Mecânica de descida

## Dados do jogador

O perfil persistente mantém estes campos no nível raiz:

| Campo | Tipo | Padrão | Uso |
| --- | --- | --- | --- |
| `World` | número inteiro positivo | `1` | mundo atual e autorização para entrar na rampa |
| `Coins` | número inteiro não negativo | `0` | saldo de moedas |
| `EquippedCart` | texto não vazio | `Default` | identificador do carrinho equipado |

O servidor replica os três valores também como atributos do `Player`. Alterações persistentes continuam sendo feitas somente no servidor por `DataUtility.server.set`.

## Recompensas diárias

`StarterGui.Main.Frames.DailyRewards.Content.Days` contém os sete cards fixos `Day_1` a `Day_7`. `DailyRewards.client.lua` lê `DayIndex` de cada card, configura o valor em `Reward`, aplica o ícone de moedas em `RewardIcon` e alterna `Status` entre `CLAIM!`, `CLAIMED` e `LOCKED`, sem alterar os textos estáticos dos dias.

As recompensas são definidas em `ReplicatedStorage.Modules.DailyRewardDefinitions.lua`. Nesta primeira versão todos os cards concedem moedas: 100, 150, 250, 350, 500, 750 e 1000. O estado persistente `DailyRewards` guarda o dia atual, a última coleta, os dias resgatados, `Streak` e `LastLoginDay`. A `Streak` aumenta uma vez quando o jogador entra em um novo dia consecutivo; se houver um dia de ausência, ela volta para `1`.

O servidor valida a coleta por `DailyRewardRemotes.ClaimReward`, exige o dia atualmente liberado, permite uma coleta por dia do calendário e concede a moeda usando `DataUtility.server.set`. A inicialização do jogador não coleta nenhuma recompensa: o card permanece `CLAIM!` até o jogador clicar nele. Ao completar o sétimo dia, o ciclo reinicia no primeiro dia após o próximo dia do calendário.

## Missões

`StarterGui.Main.Frames.Quests` é controlada no cliente por `Quests.client.lua`. As abas filtram as missões diária, semanal e mensal; o cliente reconstrói o `ScrollingFrame` `Content` usando seu `Template` e `UIListLayout` para cada filtro. Cada card atualiza `Progress.Fill`, mostra a contagem em `Progress.Label`, exibe a recompensa em `Reward.Label` e remove o card após um claim confirmado.

As missões são definidas separadamente nas listas `Daily`, `Weekly` e `Monthly` de `ReplicatedStorage.Modules.QuestDefinitions.lua` e validadas pelo servidor em `ServerStorage.Modules.QuestService.lua`. O progresso é alimentado somente por eventos de mecânicas autorizadas: pulos válidos, moedas coletadas, corridas limpas que ativam overdrive e chegada ao final da descida. O remote `QuestRemotes.ClaimQuest` valida a conclusão, impede claims duplicados e concede a recompensa em moedas.

As missões atuais são:

- Diária: pular 3 vezes.
- Semanais: coletar 100 moedas, chegar ao final de 3 mundos e ativar overdrive 5 vezes sem impactos.
- Mensais: coletar 500 moedas, chegar ao final de 10 mundos e pular 25 vezes.

## Configurações da interface

`StarterGui.Main.Frames.Settings` é controlada no cliente por `Settings.client.lua`. Os toggles sincronizam o estado visual do botão com a opção escolhida, os sliders atualizam `Fill`, `Knob` e o percentual em tempo real, e cada alteração é enviada ao servidor por `SettingsService.server.lua` após validação.

As preferências persistentes ficam em `Settings` no perfil do jogador:

| Campo | Tipo | Padrão | Uso |
| --- | --- | --- | --- |
| `MusicEnabled` | booleano | `true` | habilita ou silencia a música |
| `SFXEnabled` | booleano | `true` | habilita ou silencia efeitos sonoros |
| `MusicVolume` | número entre `0` e `1` | `0.5` | volume do grupo de música |
| `SFXVolume` | número entre `0` e `1` | `0.5` | volume do grupo de efeitos sonoros |
| `ShadowsEnabled` | booleano | `true` | controla `Lighting.GlobalShadows` |
| `VFXEnabled` | booleano | `true` | controla as partículas, highlights e flashes locais |

## Configuração da área de salto

Em `Workspace.World1`, a peça `JumpArea` é a área de interação do salto. O servidor também aceita `JumpArea` dentro de um `Model` com esse nome. O mundo é lido do atributo numérico `World` ou de um ancestral chamado `World1`, `World_2`, `Mundo1` e variações equivalentes; se nada for definido, a área pertence ao mundo `1`.

Quando o personagem toca a `JumpArea` do mesmo mundo salvo no perfil, o servidor ativa o modo de carga. O cliente remove as animações, bloqueia caminhada e pulo e mantém o carrinho completamente parado. A barra horizontal oscila continuamente entre cheia e vazia; o jogador pode pressionar Espaço em qualquer momento para confirmar o valor atual, sem lançamento automático por tempo.

Ao entrar na área, o modelo em `ReplicatedStorage.Assets.Carts.<EquippedCart>.PlayerModel` já foi preparado e replicado e vira o `Character` do jogador sem ser construído durante o toque. O carrinho é posicionado sobre a `JumpArea` e permanece parado enquanto a barra horizontal de `JUMP` é exibida. O corpo do carrinho em `Model` é soldado como visual sem massa, colisão, toque ou consulta física. Um único colisor invisível acompanha a base visual para impedir que as rodas atravessem a pista. Roupas, cores, rosto e acessórios atuais são copiados sem uma requisição assíncrona. Uma cópia congelada do personagem original permanece somente no servidor e é restaurada na posição atual do carrinho ao sair. A câmera acompanha o `Humanoid` ativo nas duas trocas.

Ao pressionar Espaço, o servidor valida o salto; o carrinho recebe o impulso vertical/frontal configurado no modelo equipado, executa um giro cartunesco interpolado e segue a física de descida após o lançamento.

## Salto turbo durante a descida

Enquanto o carrinho esta em `Slide`, segure Espaço para carregar a barra de `SALTO TURBO` e solte para pular. Em dispositivos moveis, use o botao de contexto `PULAR`. A carga leva `1.2` segundos para atingir 100% e o servidor valida o pedido, aplica um impulso vertical de acordo com a carga e respeita um intervalo de `1.35` segundos entre saltos. Durante a subida, o carrinho empina para cima; ao cair, inclina o nariz para baixo antes de retomar a pista.

## Inclinação do carrinho

Durante a descida e com o carrinho em contato com a rampa, o jogador pode incliná-lo para uma das laterais. No teclado, segure `Shift` e pressione `A`/`D` ou `←`/`→`. Em dispositivos móveis, segure o botão de contexto `VIRAR` e direcione o analógico virtual para a esquerda ou direita.

Enquanto está inclinado, o carrinho solta faíscas pelas rodas do lado encostado no chão e sua força de direção é multiplicada por `3.25`, tornando as curvas muito mais rápidas e menos previsíveis. A barra de inclinação permite `1.7` segundos de uso continuo e recarrega em `1.1` segundos ao soltar o comando. Ao soltar o comando, ele retorna ao chão com uma pequena animação de impacto; a manobra fica indisponível por `0.35` segundos e exige que o jogador solte o comando antes de usá-la novamente.

## Configuração dos carrinhos

O controlador procura o modelo indicado por `EquippedCart` dentro de `ReplicatedStorage.Assets.Carts`. Cada modelo pode definir estes atributos numéricos positivos:

| Atributo | `Default` | Uso |
| --- | --- | --- |
| `MaxSpeed` | `45` | velocidade máxima durante a descida |
| `Acceleration` | `16` | aumento de velocidade enquanto o jogador usa o controle de movimento |
| `CoastingAcceleration` | `8` | aumento natural de velocidade sem acelerar |
| `SteeringAcceleration` | `16` | força usada pelo controle para mudar a direção do carrinho |
| `LaunchUpwardBoost` | `90` | impulso vertical do salto |
| `LaunchForwardBoost` | `58` | impulso para frente do salto |
| `AirSpinDuration` | `1.05` | duração do giro cartunesco no ar |
| `AirRollAngle` | `14` | amplitude do balanço lateral durante o giro |
| `TiltAngle` | `40` | limite de inclinação lateral em graus |

Os mesmos valores do carrinho `Default` são usados como fallback caso o asset ou algum atributo ainda não exista.
