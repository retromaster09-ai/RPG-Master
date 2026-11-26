# Modelo do caderno compartilhado

O Word dos jogadores serviu de referência para organizar o caderno.
O Caderno abre no índice de seções. Cada seção tem sua própria lista
e busca. Todo registro continua com título, texto livre e nível de
confiança quando fizer sentido.

| Seção | Como registrar |
| --- | --- |
| Objetivos e missões | Um cartão por objetivo, com caixa de conclusão, etapas opcionais e detalhes em cada etapa. O grupo pode concluir a missão mesmo com etapas opcionais em aberto. |
| Mistérios e pistas | Uma pergunta, pista ou hipótese por cartão. Use a resposta para o que o grupo descobriu. Ative **Só hipóteses** para ver os registros marcados com confiança **Hipótese**. |
| Pessoas importantes | Nome e notas sobre a pessoa. |
| Lugares importantes | Nome do local e o que o grupo encontrou lá. |
| Relíquias, objetos e sinais | Nome, descrição e contexto da descoberta. |
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

## Importar um documento Word

Abra **Caderno → ⋮ → Importar Word** e escolha um arquivo `.docx` de até 12 MB.
A prévia mostra a campanha de destino e as seções sugeridas. Toque no
registro para revisar título, texto, seção, datas e etapas quando cabível.
Selecione os registros desejados e confirme em **Importar para a campanha**.
Só a confirmação envia os registros selecionados aos participantes da mesa.
A prévia funciona localmente e o envio precisa de conexão.

O leitor interpreta cabeçalhos, linhas de tabelas, recuos, caixas de
seleção e datas explícitas. Conclusão da missão e conclusão dos passos
são independentes. Hipóteses ficam com confiança **Hipótese**. Trechos
sem seção, intervalos de datas e títulos repetidos começam desmarcados.
Registros idênticos são ignorados. Os registros existentes são preservados
mesmo quando você escolhe importar outro de título semelhante.

Esta etapa importa o conteúdo textual, a estrutura e as datas do Word.
A diagramação e as imagens incorporadas ficam no documento de origem.
Use amostras fictícias nos testes do repositório público.

## Referência para implementar a importação PDF

Em PDF com texto, usar a disposição da página como pista para a ordem
e a hierarquia. Tratar páginas digitalizadas como dependentes de OCR e
permitir revisar o resultado antes de importar. Reutilizar a prévia do
Word para conferir a campanha e a seção de destino.
