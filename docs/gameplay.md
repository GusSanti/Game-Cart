# Mecânica de descida

## Dados do jogador

O perfil persistente mantém estes campos no nível raiz:

| Campo | Tipo | Padrão | Uso |
| --- | --- | --- | --- |
| `World` | número inteiro positivo | `1` | mundo atual e autorização para entrar na rampa |
| `Coins` | número inteiro não negativo | `0` | saldo de moedas |
| `EquippedCart` | texto não vazio | `Default` | identificador do carrinho equipado |

O servidor replica os três valores também como atributos do `Player`. Alterações persistentes continuam sendo feitas somente no servidor por `DataUtility.server.set`.

## Configuração da área de salto

Em `Workspace.World1`, a peça `JumpArea` é a área de interação do salto. O servidor também aceita `JumpArea` dentro de um `Model` com esse nome. O mundo é lido do atributo numérico `World` ou de um ancestral chamado `World1`, `World_2`, `Mundo1` e variações equivalentes; se nada for definido, a área pertence ao mundo `1`.

Quando o personagem toca a `JumpArea` do mesmo mundo salvo no perfil, o servidor ativa o modo de carga. O cliente remove as animações, bloqueia caminhada e pulo e mantém o carrinho completamente parado. A barra horizontal oscila continuamente entre cheia e vazia; o jogador pode pressionar Espaço em qualquer momento para confirmar o valor atual, sem lançamento automático por tempo.

Ao entrar na área, o modelo em `ReplicatedStorage.Assets.Carts.<EquippedCart>.PlayerModel` já foi preparado e replicado e vira o `Character` do jogador sem ser construído durante o toque. O carrinho é posicionado sobre a `JumpArea` e permanece parado enquanto a barra horizontal de `JUMP` é exibida. O corpo do carrinho em `Model` é soldado como visual sem massa, colisão, toque ou consulta física. Um único colisor invisível acompanha a base visual para impedir que as rodas atravessem a pista. Roupas, cores, rosto e acessórios atuais são copiados sem uma requisição assíncrona. Uma cópia congelada do personagem original permanece somente no servidor e é restaurada na posição atual do carrinho ao sair. A câmera acompanha o `Humanoid` ativo nas duas trocas.

Ao pressionar Espaço, o servidor valida o salto; o carrinho recebe o impulso vertical/frontal configurado no modelo equipado, executa um giro cartunesco interpolado e segue a física de descida após o lançamento.

## Salto turbo durante a descida

Enquanto o carrinho está em `Slide`, segure Espaço para carregar o pulo e solte para saltar. Em dispositivos móveis, use o botão de contexto `PULAR`. A carga leva `1.2` segundos para atingir 100% e define a altura, o impulso para frente e o custo de energia.

Cada descida começa com `100` pontos de energia de pulo. Um salto custa entre `35` e `60` pontos conforme a carga e a energia recupera `24` pontos por segundo somente com o carrinho no chão. Uma aterrissagem sem colisão devolve `15` pontos. O servidor valida a energia, a carga e o intervalo mínimo de `0.35` segundos entre pedidos. Durante a subida, o carrinho empina para cima; ao cair, inclina o nariz para baixo antes de retomar a pista.

## Inclinação do carrinho

Durante a descida e com o carrinho em contato com a rampa, o jogador pode incliná-lo para uma das laterais. No teclado, segure `Shift` e pressione `A`/`D` ou `←`/`→`. Em dispositivos móveis, segure o botão de contexto `VIRAR` e direcione o analógico virtual para a esquerda ou direita.

Enquanto está inclinado, o carrinho solta faíscas pelas rodas do lado encostado no chão e sua força de direção é multiplicada por `3.25`, tornando as curvas mais rápidas e menos previsíveis. A barra de inclinação permite `1.7` segundos de uso contínuo e recarrega em `1.1` segundos ao soltar o comando. Ao soltar o comando, ele retorna ao chão com uma pequena animação de impacto; a manobra fica indisponível por `0.35` segundos e exige que o jogador solte o comando antes de usá-la novamente. Iniciar uma inclinação válida também concede Flow, com proteção contra repetição rápida.

## Flow e Overdrive

Flow recompensa decisões ativas durante a descida. O medidor aumenta ao acertar o salto inicial, coletar moedas, completar sequências arriscadas, iniciar uma inclinação válida e realizar uma aterrissagem limpa. Depois de `2.5` segundos sem recompensa, o medidor perde `5` pontos por segundo. Qualquer colisão zera o Flow.

Ao atingir `100`, o carrinho entra em Overdrive por `5` segundos. O estado aumenta velocidade, aceleração e resposta da direção, muda o HUD e intensifica FOV, vibração de câmera, desfoque e partículas de velocidade. Usar inclinação ou pulo não cancela o Overdrive.

## Configuração dos carrinhos

O controlador procura o modelo indicado por `EquippedCart` dentro de `ReplicatedStorage.Assets.Carts`. Cada modelo pode definir estes atributos numéricos positivos:

| Atributo | `Default` | Uso |
| --- | --- | --- |
| `MaxCartHealth` | `1` | quantidade de impactos com dano que o carrinho suporta |
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

Os HUDs de vida/Flow e de inclinação/pulo ficam em `StarterGui.CartHealthGui` e `StarterGui.CartTiltMeter`. Os controladores apenas atualizam os elementos clonados em `PlayerGui`, permitindo editar layout, cores e textos diretamente no Studio.
