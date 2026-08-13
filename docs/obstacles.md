# Obstaculos e overdrive

`ReplicatedStorage.Assets.Obstacles` contem os templates brancos `Small`, `Medium` e `Large`. Cada template possui `Damage`, `SizeType` e `SpawnWeight`.

`ObstacleService.server.lua` cria uma onda procedural em `Workspace.GeneratedObstacles` para cada mundo que possui rampa. Os obstaculos nascem e somem com Tween, permanecem estaveis durante uma descida e somente sao substituidos depois que nao ha mais jogadores ativos naquele mundo.

Cada parte da rampa e dividida em segmentos curtos. Em todo segmento, duas ou tres faixas recebem bloqueios e a faixa segura muda de lado, eliminando trechos vazios e formando uma sequencia de desvios. O mesmo servico cria moedas em `Workspace.GeneratedCollectibles`: seis trilhas por parte, com 8 a 20 moedas, curvas leves e escala variavel. A coleta e validada no servidor e credita `Coins` em pequenos lotes.

O carrinho usa `MaxCartHealth` como configuracao do asset. Em cada descida, o servidor aplica esse valor nos atributos `CartMaxHealth` e `CartHealth` do personagem-carrinho. Dano, intervalo de invulnerabilidade e eliminacao sao todos validados no servidor.

Depois de oito segundos em `Slide` sem colisao e sem usar Shift, o servidor define `CartOverdriveActive`. O cliente aplica a velocidade adicional e mostra particulas nas rodas. Shift continua sendo a entrada de inclinacao e tambem reinicia a sequencia limpa.
