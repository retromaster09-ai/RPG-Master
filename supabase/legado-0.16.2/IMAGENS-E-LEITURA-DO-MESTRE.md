# RPG Master Set 0.14 — leitura e imagens privadas

## Como atualizar

1. Requer a configuração anterior do [Roteiro do Mestre](ROTEIRO-DO-MESTRE.md), já usada na versão 0.13.
2. Abra [imagens-e-leitura-do-mestre.sql](https://raw.githubusercontent.com/retromaster09-ai/RPG-Master/main/downloads/configuracao/imagens-e-leitura-do-mestre.sql), copie todo o texto para uma nova consulta no SQL Editor do mesmo projeto Supabase e clique Run. Aguarde `Success. No rows returned`. Não exclua consultas anteriores.
3. Instale **RPG-Master-Set-0.14.0-android64.apk** como atualização, sem desinstalar.
4. Entre com a conta que criou a campanha e abra **Roteiro do Mestre**. O cartão da campanha e o menu dentro dela levam à mesma área privada. A antiga aba de demonstração chamada apenas “Mestre” foi removida.
5. Digite a senha da sua conta para desbloquear. O código de convite da campanha não serve para desbloquear o roteiro.

## Ler e editar

Ao tocar numa anotação, ela abre primeiro para leitura. As notas antigas continuam disponíveis e recebem o estilo Pergaminho como padrão.

- Toque no lápis **Editar anotação privada** para alterar o conteúdo.
- Em **Estilo da página**, escolha Pergaminho, Diário de Baróvia, Futurista ou Leitura simples. Salve para manter o estilo nessa anotação.
- Na leitura, você pode aumentar/diminuir o texto e alternar temporariamente para Leitura simples.
- Selecione um trecho de texto e use a barra para aplicar negrito, itálico, cor, destaque, títulos ou lista. A formatação acompanha a edição do texto.

## Capa, miniatura e imagens entre parágrafos

- **Adicionar imagem de capa privada** escolhe a imagem que aparece ao lado da nota e na página de leitura.
- **Enquadramento da capa e miniatura** permite escolher moldura arredondada, retangular, quadrada arredondada ou circular. Você também pode mostrar a imagem inteira, preencher a moldura e ajustar zoom/posição/borda.
- **Inserir imagens privadas no texto** aceita uma ou várias imagens. Cada uma pode receber legenda e uma posição: antes do parágrafo 1 ou depois de um dos parágrafos. Separe os parágrafos com uma linha em branco.
- As setas mudam a ordem das imagens; a posição escolhida determina entre quais parágrafos elas aparecem.
- Ao ler, toque numa imagem para ampliar. Você pode aproximar com o gesto de pinça.
- A galeria pode colocar o aplicativo em segundo plano. Por segurança, ao retornar o roteiro pode pedir novamente a senha da sua conta. A seleção e o rascunho continuam na memória.

Toque **Salvar no roteiro privado** para enviar as imagens e a anotação. Até salvar, as novas imagens ficam apenas na sessão de edição. São permitidas até 12 imagens no texto, mais a capa; arquivos selecionados até 20 MB, convertidos para PNG estático com lado maior até 1600 pixels e limite final de 10 MB por imagem.

## Proteção e limites

As imagens usam o bucket privado `rpg-gm-private`, separado das imagens compartilhadas dos jogadores. O servidor confere se a conta é a criadora da campanha para permitir leitura ou envio. Conhecer o nome/endereço do objeto não concede acesso. Uma nota não pode referenciar uma imagem pertencente a outra campanha.

O aplicativo baixa imagens autenticadas para memória; não gera links públicos nem copia as imagens para a biblioteca compartilhada ou para o arquivo local do caderno. A galeria pode usar cache temporário do seletor do sistema, cuja limpeza é solicitada pelo aplicativo. O arquivo original escolhido permanece na sua galeria.

O roteiro e suas imagens continuam fora das buscas, PDFs, exportações e backups do caderno compartilhado. Não há publicação automática para jogadores. O bloqueio ao ir para segundo plano e a proteção Android de captura/gravação da janela privada continuam ativos, inclusive durante a ampliação de imagens.

Salvamento e desbloqueio dependem de internet. Remover uma imagem da nota retira a referência; o arquivo pode permanecer no armazenamento privado para preservar seu uso em outras anotações. Não há limpeza automática de arquivos sem referências nesta versão.

Não é criptografia de ponta a ponta: o administrador do seu projeto Supabase mantém acesso técnico pelo painel. A proteção Android não impede fotografar a tela com outra câmera. Não compartilhe a conta do mestre nem o acesso administrativo ao projeto.

Se houver falha ou conflito ao salvar, o editor mantém o rascunho. Confira a mensagem antes de sair. Aplique o SQL desta versão antes de salvar: o novo aplicativo verifica o novo ponto de salvamento para não anunciar formatação salva num banco antigo que ainda não a aceita.

## Primeiro teste

Use uma anotação fictícia, sem spoilers. Adicione capa, duas imagens e um trecho em negrito, salve, feche e reabra o roteiro. Confira também no segundo aparelho usando a mesma conta do mestre. Com uma conta de jogador, o roteiro não deve aparecer. Teste o bloqueio ao sair do aplicativo e durante a ampliação de uma imagem.

Os testes de banco foram executados em PostgreSQL descartável e incluíram acesso direto por jogador, visitante e mestre de outra campanha. As imagens reais no seu projeto e a proteção de captura precisam ser conferidas no aparelho após aplicar o SQL. A prévia de leitura distribuída é um exemplo fictício, sem conteúdo privado da campanha.
