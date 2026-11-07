# RPG Master Set 0.15 — imagens, Word, reset e remoção de fundo

## Atualizar

1. Esta atualização pressupõe as configurações anteriores, incluindo imagens e leitura do mestre da versão 0.14.
2. Abra [ativar-ferramentas-0.15.sql](https://raw.githubusercontent.com/retromaster09-ai/RPG-Master/main/downloads/configuracao/ativar-ferramentas-0.15.sql), copie todo o texto para uma nova consulta no SQL Editor do mesmo projeto Supabase e clique Run. Aguarde `Success. No rows returned`. Não exclua as consultas antigas.
3. Instale **RPG-Master-Set-0.15.0-android64.apk** como atualização, sem desinstalar. Quem participar da campanha deve atualizar antes de vocês usarem o reset.

**Executar esse SQL não importa documentos nem apaga nenhuma anotação.** Ele atualiza as funções e permissões. A limpeza só acontece quando o mestre usa e confirma a ação dentro do aplicativo.

## 1. Ajustar imagens

No roteiro privado, edite a anotação e abra **Ajustar capa e miniatura** ou **Ajustar imagem do texto**. No caderno compartilhado, use Ajustar imagem na página de um registro; em sessões, edite o resumo e use Ajustar imagem do texto.

Controles: tamanho na página, alinhamento esquerdo/central/direito, retângulo, cantos arredondados, quadrado arredondado, círculo e oval, imagem inteira/preencher, zoom, posição, giro de 90 graus, espelhamento, sombra, cor e espessura da borda. Restaurar aparência original desfaz esses ajustes visuais. As miniaturas mantêm seu tamanho na lista; o controle de tamanho muda a imagem da página.

Os estilos das imagens de sessões também acompanham a exportação em imagem/PDF. O roteiro privado continua sem exportação para os jogadores. A escolha do alinhamento não faz o texto contornar a imagem: ela continua entre os parágrafos.

## 2. Importar o Word

No menu dentro da campanha, toque **Importar documento Word** e escolha um `.docx` de até 12 MB.

O aplicativo lê localmente títulos, tabelas, caixas de conclusão, respostas e datas. Reconhece o formato do caderno fornecido e alguns títulos comuns sem numeração. Sugere missões, investigações, cartas, personagens, lugares, itens e sessões. O processamento não usa um serviço externo de IA.

Antes de importar, aparece uma revisão:

- Selecione ou desmarque registros.
- Corrija título, conteúdo, aba de destino, conclusão e etapas quando necessário.
- Confira as datas de sessões; várias datas no início de um resumo são mantidas juntas.
- Registros idênticos são ignorados. Registros com o mesmo título ficam desmarcados para conferir; não substituímos os existentes automaticamente.
- Trechos sem classificação ficam desmarcados. Escolha uma aba antes de importá-los para uma campanha compartilhada.
- Hipóteses não são promovidas automaticamente a fatos confirmados.
- Confirme que compreende o destino compartilhado e toque **Importar registros selecionados**. Só então o caderno é alterado.

A importação preserva o que está escrito; não corrige nomes, parentescos ou informações de lore automaticamente.

A importação reconhece estrutura; não reproduz a diagramação do Word e pode precisar de correções manuais. A primeira versão importa textos, não as imagens incorporadas ao documento; caso existam, aparece um aviso para adicioná-las pelo editor depois. Arquivos `.doc` antigos, macros e instruções do documento não são executados.

No caderno desta campanha, os registros importados são visíveis aos participantes. O importador não envia conteúdo para o roteiro privado do mestre. O documento fornecido para teste não está incluído no aplicativo nem é enviado a outros usuários.

## 3. Resetar conteúdo

Somente o criador da campanha vê e pode executar: **Suas campanhas → Acesso e participantes → Resetar conteúdo da campanha**.

A tela mostra as quantidades de registros. Por padrão, limpa apenas o caderno compartilhado e seu histórico, preservando o roteiro privado. A opção **Apagar também as notas privadas do mestre** é separada e vem desmarcada.

Antes de confirmar, guarde o backup que quiser pelo menu do caderno. O backup compartilhado não inclui o roteiro privado. Para executar, é necessário reconhecer a exclusão, digitar o nome exato da campanha e a senha da própria conta. Há opção de cancelar.

A campanha, as contas, os participantes e a capa permanecem. Aplicar o SQL não executa o reset. Nenhuma campanha real foi resetada durante o desenvolvimento.

**Atualize os aparelhos do grupo antes de usar.** O servidor marca uma nova geração do caderno. Clientes atualizados descartam o envio automático de rascunhos da geração anterior ao sincronizar, impedindo que tragam de volta o conteúdo antigo. Versões anteriores deixam de poder enviar alterações à campanha após um reset e precisam ser atualizadas. Aparelhos offline podem continuar mostrando sua cópia antiga até se conectarem e sincronizarem.

Combine com o grupo para sair dos editores antes do reset. A ação não pode ser desfeita pelo aplicativo. Fotos originais, arquivos exportados e backups já existentes fora do caderno não são apagados. Arquivos de imagens no armazenamento podem permanecer sem referência; esta limpeza é dos registros e do histórico, não uma eliminação física de todos os arquivos e cópias existentes.

## 4. Remover fundo por cor

No roteiro privado, edite a nota e use **Remover fundo da capa** ou **Remover fundo desta imagem**. Na enciclopédia, há Remover fundo por cor na página da imagem; em resumos, a opção fica no editor das imagens do texto.

Escolha Automático pelos cantos, Branco, Preto ou Verde, ajuste a tolerância e toque **Gerar prévia**. Confira o resultado sobre o fundo cinza e use **Aplicar nova versão** ou Cancelar. Depois salve a anotação.

O processamento é local e cria transparência apenas em áreas semelhantes ao fundo conectadas às bordas. Isso ajuda a preservar áreas internas cercadas por contornos. O arquivo original da galeria não é sobrescrito. Restaurar aparência original é um ajuste de moldura, não uma restauração dos pixels após aplicar a remoção; para recuperar a imagem sem remoção, selecione novamente o original.

**Não é uma IA de segmentação.** Funciona melhor com fundos uniformes; fundos complexos e cores próximas às do personagem podem exigir outra edição. Nenhuma imagem é enviada a um serviço externo para remover o fundo.

A senha, o bloqueio em segundo plano, a proteção Android de captura e o armazenamento separado das imagens do mestre permanecem. Comece por uma anotação e um documento de teste, antes de usar o reset em conteúdo importante.
