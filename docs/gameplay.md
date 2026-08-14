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

## Inclinação do carrinho

Durante a descida e com o carrinho em contato com a rampa, o jogador pode incliná-lo para uma das laterais. No teclado, segure `Shift` e pressione `A`/`D` ou `←`/`→`. Em dispositivos móveis, segure o botão de contexto `VIRAR` e direcione o analógico virtual para a esquerda ou direita.

Enquanto está inclinado, o carrinho solta faíscas pelas rodas do lado encostado no chão e sua força de direção é multiplicada por `3.25`, tornando as curvas muito mais rápidas e menos previsíveis. Ao soltar o comando, ele retorna ao chão com uma pequena animação de impacto; a manobra fica indisponível por `2` segundos e exige que o jogador solte o comando antes de usá-la novamente.

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

Os mesmos valores do carrinho `Default` são usados como fallback caso o asset ou algum atributo ainda não exista.
