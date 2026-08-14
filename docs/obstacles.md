# Obstaculos e overdrive

`ReplicatedStorage.Assets.Obstacles` aceita qualquer `BasePart` ou `Model` como template: blocos, arvores, cactos, caixas, rampas, rochas e outros formatos. `Damage` e `SpawnWeight` sao atributos opcionais; sem `Damage`, o obstaculo causa pelo menos um ponto de dano. Um `Damage` maior continua aumentando o impacto. Scripts incluidos em assets importados nao sao copiados para os obstaculos gerados.

Todas as peças dos templates devem permanecer ancoradas. O serviço também força `Anchored`, zera velocidades linear e angular e configura colisão, toque e consulta nas cópias geradas antes de ativá-las.

`ObstacleService.server.lua` prepara a onda procedural da rampa do `World1`. Os obstáculos são instanciados com Tween apenas quando um carrinho ativo se aproxima da parte correspondente da pista, permanecem estáveis durante uma descida e somente são substituídos depois que não há mais jogadores ativos.

Cada parte da rampa é dividida em encontros de aproximadamente `86` studs. O diretor aumenta a complexidade ao longo da descida e escolhe entre cinco padrões: `Slalom`, `Fork`, `Chicane`, `JumpGate` e `Breather`. Padrões iguais têm peso reduzido quando acabaram de aparecer, barreiras de pulo mantêm pelo menos três encontros de distância e um trecho de respiro aparece periodicamente.

As faixas bloqueadas recebem pequenos grupos de props, evitando os grandes espaços vazios da distribuição anterior. Templates muito complexos têm peso reduzido para preservar desempenho. `JumpGate` utiliza preferencialmente assets baixos e simples e forma uma barreira contínua que deve ser pulada.

O tamanho comunica o impacto: todo obstáculo causa pelo menos um ponto; obstáculos grandes causam dois e os maiores causam três. Um atributo `Damage` definido no template continua tendo prioridade, mas nunca reduz o impacto abaixo de um ponto.

As moedas em `Workspace.GeneratedCollectibles` agora pertencem aos encontros. Trechos de respiro oferecem sequências seguras de valor baixo; slaloms, bifurcações e chicanes posicionam sequências na rota mais exigente; barreiras de pulo criam arcos de moedas. Moedas de risco valem `2`, moedas douradas valem `5` e completar a sequência concede um bônus adicional. A coleta e os bônus são validados no servidor e persistidos em pequenos lotes.

O template `Barrel` é tratado como obstáculo móvel quando aparece na descida. Depois do aviso de spawn, ele cai alguns studs acima da pista, toca o chão e rola na direção da descida com giro contínuo por alguns segundos. A trajetória é cinemática e autoritativa no servidor, mantém colisão e dano por toque e desaparece sozinha para não acumular na onda.

O carrinho usa `MaxCartHealth` como configuracao do asset. Em cada descida, o servidor aplica esse valor nos atributos `CartMaxHealth` e `CartHealth` do personagem-carrinho. Dano, intervalo de invulnerabilidade e eliminacao sao todos validados no servidor.

O Overdrive não depende mais de esperar sem agir. Moedas, sequências completas, inclinações, aterrissagens limpas e o salto inicial alimentam `CartFlow`; colisões zeram o medidor. Ao atingir o máximo, o servidor mantém `CartOverdriveActive` por cinco segundos.
