# Modelo do caderno compartilhado

O Word dos jogadores serviu de referência para organizar o caderno.
O Caderno abre no índice de seções. Cada seção tem sua própria lista
e busca. Todo registro continua com título, texto livre e nível de
confiança quando fizer sentido.

| Seção | Como registrar |
| --- | --- |
| Objetivos e missões | Um cartão por objetivo, com caixa de conclusão, etapas opcionais e detalhes em cada etapa. O grupo pode concluir a missão mesmo com etapas opcionais em aberto. |
| Mistérios e pistas | Uma pergunta ou pista por cartão. Use o texto para registrar o que apareceu em jogo e o campo de resposta para o que o grupo descobriu. |
| Pessoas importantes | Nome e notas sobre a pessoa. |
| Lugares importantes | Nome do local e o que o grupo encontrou lá. |
| Relíquias, objetos e sinais | Nome, descrição e contexto da descoberta. |
| Mural de hipóteses | Mostra os registros de Mistérios e pistas marcados com confiança **Hipótese**. O mesmo registro pode aparecer nas duas seções. |
| Crônicas | Uma entrada por sessão ou resumo, com datas opcionais e ordenação por data ou manual. |

A seção **Cartas** também está disponível. Abra **Objetivos e missões**
para acompanhar o que está em **Ativas**. Ao marcar a caixa do objetivo,
o cartão passa para **Concluídas**. Reabrir devolve o cartão a **Ativas**
e preserva as etapas marcadas. Segure o título de um
cartão publicado e arraste para reorganizar. Ao reorganizar, os cartões que estiverem em outra seção ou
fora da busca mantêm suas posições. Nas Crônicas, arrastar muda para
ordem manual. No Mestre, o gesto reorganiza as notas dentro da seção.

## Capas e páginas de leitura

O índice tem uma ilustração por seção. Toque no título de um registro
ou na capa para abrir a página completa. Na edição, abra **Capa do registro**
para escolher, trocar ou remover um PNG ou JPEG. A capa é opcional e usa
o mesmo armazenamento privado da campanha que a capa da mesa. Os dados
usam o campo legado `imagePath`. A imagem selecionada fica no rascunho
local até o envio, junto do texto. A área Mestre usa armazenamento separado.

A prévia usa a mesma proporção do cartão. **Mostrar a imagem inteira**
é o padrão quando o registro ainda não tem um enquadramento salvo. Em
**Preencher o cartão**, ajuste zoom e posição horizontal e vertical.
A página de leitura mostra a capa inteira.

Em **Estilo da página**, escolha Leitura simples, Pergaminho com letra
manuscrita, Diário de Baróvia ou Futurista. Selecione um trecho no texto
ou na resposta para aplicar negrito, itálico, títulos, cor ou destaque.
A barra também insere marcadores na linha ou nas linhas selecionadas.
Em **Imagens no texto**, escolha uma imagem, toque nela para editar sua
legenda e posicione-a antes do texto ou depois de um parágrafo. Separe
os parágrafos com uma linha em branco. Os estilos e imagens usam os
campos legados do caderno e acompanham a fila de sincronização.

### Ajustar uma imagem do texto

Em **Editar → Imagens no texto**, toque na imagem. Ajuste o tamanho, o
zoom e as posições horizontal e vertical na prévia. O ajuste fica salvo
na imagem e aparece na página de leitura.

Para um fundo uniforme, abra **Remover fundo**, escolha a cor e use
**Gerar prévia**. A tolerância controla quais cores próximas das bordas
ficam transparentes. Compare com **Ver imagem original**. Para voltar à
versão sem recorte, use **Restaurar fundo**. Toque em **Aplicar** e salve
o registro para compartilhar. O processamento é local e somente a
versão recortada adicional é enviada quando o registro é salvo.

## Referência para implementar a importação Word e PDF

- Reconhecer títulos de seção por estilo e texto, inclusive variações de
  grafia como “Objetivos, Missões e Quests”. Preencher uma prévia editável
  com o tipo sugerido para cada registro e manter o texto original quando a
  estrutura for ambígua.
- Em Word, usar a estrutura de parágrafos, tabelas e listas, com seus
  níveis e recuos. Reconhecer caixas marcadas e vazias em Unicode, nos
  controles de formulário e nos símbolos cuja fonte identifica a marca.
  Associar etapas e detalhes a uma missão quando a hierarquia estiver
  clara. Preservar a marca da missão separadamente das marcas das etapas.
- Identificar datas de sessão com formato inequívoco e manter o texto de
  origem quando a data for ambígua. Na prévia, preservar linhas de tabelas,
  contexto de pistas e distinção entre hipóteses e descobertas confirmadas.
- Em PDF com texto, usar a disposição da página como pista para a ordem e
  a hierarquia. Tratar páginas digitalizadas como dependentes de OCR e
  permitir revisar o resultado antes de importar.
- Mostrar a campanha e a área de destino antes de salvar. O mestre pode
  revisar o destino de conteúdo privado antes de qualquer gravação.
  Usar amostras fictícias para os testes no repositório público.
