# Armas de arremesso

As armas ficam em `ReplicatedStorage.Assets.Weapons`. `WeaponConfig.lua` concentra alcance, duração do voo, cooldown e efeitos; `ProjectileUtility.lua` compartilha o mesmo cálculo balístico entre a prévia local e o projétil autoritativo.

## Fluxo

Ao equipar `Granade` ou `Banana` durante a descida, o botão direito do mouse, `L2` ou o botão de contexto inicia a mira. O cliente desenha a trajetória e o marcador em X, reproduz as animações com prioridade `Action4` e preserva as juntas inferiores do carrinho. Ao soltar, o cliente envia somente o identificador e o ponto desejado.

`WeaponService.server.lua` confirma que a ferramenta está equipada, que o jogador está descendo, que o alvo está dentro do alcance e que existe uma superfície válida. O servidor remove a ferramenta e movimenta o projétil ancorado por uma trajetória balística em coordenadas do mundo. Assim, a velocidade do carrinho não é herdada e o ponto final coincide com o marcador validado.

## Granada

`Granade` executa `PinAnimation`, mantém `AimAnimation` em loop e usa `ThrowAnimation` ao lançar. Ao chegar ao alvo, a explosão visual não aplica física automática: o servidor calcula os outros carrinhos dentro do raio e aplica um lançamento horizontal e vertical controlado. O dono não é atingido.

## Banana

`Banana` usa somente `AimAnimation` e `ThrowAnimation`. Ao chegar ao alvo, vira uma armadilha com tempo de vida limitado. O primeiro outro carrinho que tocar nela recebe `CartSpinUntil`; durante esse período o controlador mantém a velocidade existente, bloqueia direção, inclinação e pulo, e força a rotação do carrinho.

## Assets necessários

- `Weapons.Granade`: `Handle`, `PinAnimation`, `AimAnimation` e `ThrowAnimation`.
- `Weapons.Banana`: `Handle`, `AimAnimation` e `ThrowAnimation`.
- `Weapons.Projectiles.BananaPeel`: peça visual da armadilha.

As ferramentas usam o atributo `WeaponId`. Os IDs atuais são `Grenade` e `Banana`.
