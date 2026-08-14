# Obstaculos e overdrive

`ReplicatedStorage.Assets.Obstacles` aceita qualquer `BasePart` ou `Model` como template: blocos, arvores, cactos, caixas, rampas, rochas e outros formatos. `Damage` e `SpawnWeight` sao atributos opcionais; sem `Damage`, o obstaculo causa um ponto de dano. Scripts incluidos em assets importados nao sao copiados para os obstaculos gerados.

`ObstacleService.server.lua` prepara uma onda procedural para cada mundo que possui rampa. Os obstaculos sao instanciados com Tween apenas quando um carrinho ativo se aproxima da parte correspondente da pista, permanecem estaveis durante uma descida e somente sao substituidos depois que nao ha mais jogadores ativos naquele mundo.

Cada parte da rampa e dividida em segmentos curtos. Cada segmento recebe duas fileiras de duas ou tres faixas bloqueadas e a faixa segura muda de lado, eliminando trechos vazios e formando uma sequencia intensa de desvios. As posicoes recebem variacao lateral e longitudinal para formar uma distribuicao organica, sem uma grade visivel. Cada prop recebe uma escala aleatoria entre 1x e 2x. O mesmo servico cria moedas em `Workspace.GeneratedCollectibles`: seis trilhas por parte, com 8 a 20 moedas, curvas leves e escala variavel. As moedas ficam em pe, maiores e giram no cliente; uma area de coleta invisivel e mais larga acompanha cada moeda para a coleta permanecer confiavel em alta velocidade. A coleta e validada no servidor e credita `Coins` em pequenos lotes.

O carrinho usa `MaxCartHealth` como configuracao do asset. Em cada descida, o servidor aplica esse valor nos atributos `CartMaxHealth` e `CartHealth` do personagem-carrinho. Dano, intervalo de invulnerabilidade e eliminacao sao todos validados no servidor.

Depois de oito segundos em `Slide` sem colisao e sem usar Shift, o servidor define `CartOverdriveActive`. O cliente aplica a velocidade adicional e mostra particulas nas rodas. Shift continua sendo a entrada de inclinacao e tambem reinicia a sequencia limpa.
