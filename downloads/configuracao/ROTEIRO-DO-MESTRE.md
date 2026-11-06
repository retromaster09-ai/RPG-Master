# Roteiro do Mestre — versão 0.13

## Ativação

1. Abra [roteiro-do-mestre.sql](https://raw.githubusercontent.com/retromaster09-ai/RPG-Master/main/downloads/configuracao/roteiro-do-mestre.sql). Copie todo o texto.
2. No mesmo projeto Supabase usado pelo aplicativo, abra SQL Editor, crie uma consulta com +, cole e clique Run. Aguarde `Success. No rows returned`. Não exclua consultas anteriores.
3. Instale o APK 0.13 como atualização, sem desinstalar a versão anterior.
4. Entre na conta que criou a campanha. Toque **Roteiro do Mestre**, no cartão da campanha ou no menu dentro dela.
5. Digite a senha da sua conta para desbloquear. Não é o código usado para convidar jogadores.
6. Toque **Nova anotação privada**, escreva um título e seu texto e toque **Salvar no roteiro privado**. O salvamento depende de conexão e exibe confirmação quando concluído.

Não é necessário configurar o Gmail para usar o roteiro. A recuperação de senha por e-mail continua em preparação.

## Organização

- **Caixa de ideias:** anote rapidamente sem preencher os campos opcionais.
- **Cenas:** diálogos, encontros e possibilidades para o futuro.
- **Bastidores:** verdades do mundo, motivações e planos secretos.
- **Próxima sessão:** seleção das mesmas notas; marque o interruptor dentro de uma anotação. Não cria cópias.

Título e texto livre são a base. Etiquetas, condições/testes, referências de música, categoria e estado da ideia são opcionais. Você pode mudar a categoria e marcar uma ideia como preparada, utilizada ou descartada. O texto pode misturar falas e instruções sem exigir estrutura fixa. Use etiquetas como `final possível` ou `pista não revelada` se ajudar sua organização.

O título é obrigatório. A busca procura nos títulos, textos, etiquetas e condições do roteiro, sem misturar resultados da enciclopédia compartilhada.

## Confidencialidade e limites desta versão

- As notas privadas ficam numa tabela separada, com permissão no servidor somente para o criador da campanha. Um jogador não recebe acesso mesmo conhecendo o identificador da nota ou tentando chamar a API diretamente. Ser mestre de outra campanha não dá acesso.
- Esta área não usa o arquivo local, a tabela, o histórico, as buscas, os backups ou as exportações do caderno compartilhado. Não há botão de publicação automática para jogadores.
- **Não há cópia local automática nem acesso offline.** Rascunhos ficam na memória enquanto a tela está aberta, até você salvar online. Ao sair com alterações não salvas, há confirmação para descartar. Fechar o aplicativo à força pode perder um rascunho.
- O roteiro pede a senha da própria conta ao abrir e depois de ir para segundo plano. A senha digitada é enviada somente à autenticação do Supabase e não é gravada nas notas.
- No Android, a janela privada usa FLAG_SECURE para bloquear capturas/gravação de tela pelo sistema e sua prévia nos aplicativos recentes. A proteção deve ser conferida no aparelho; não substitui o bloqueio do celular nem impede uma foto feita com outra câmera. No Windows ainda não há instalador distribuído nem proteção nativa de captura implementada.
- As permissões protegem contra contas de jogadores. O administrador do projeto Supabase ainda tem acesso técnico pelo painel; esta versão não usa criptografia de ponta a ponta. Não compartilhe sua conta de mestre nem acesso administrativo ao projeto.
- Imagens/anexos privados e exportação própria do roteiro ficam para uma atualização posterior. Nesta versão, use texto e referências de música; não envie imagens secretas para a enciclopédia compartilhada.
- Duas edições simultâneas da mesma nota não se substituem silenciosamente. Em caso de conflito ou envio com confirmação perdida, o editor mantém o rascunho e orienta atualizar a lista. Copie o texto que precisar preservar antes de descartar o rascunho.

## Conferência no seu grupo

Use primeiro uma nota fictícia, sem spoilers: crie e salve com a conta do mestre. Com uma conta de jogador no outro celular, confirme que o botão Roteiro do Mestre não aparece. No celular do mestre, coloque o app em segundo plano e confirme que o retorno exige senha. Confira também se a nota fictícia continua disponível ao fechar e reabrir o roteiro.

As regras foram testadas em PostgreSQL descartável com acesso direto e por funções, incluindo jogador da mesma campanha, mestre de outra campanha, visitante sem conta e conflito de edição. Os testes de interface verificam senha, bloqueio e preservação do rascunho. O funcionamento no seu projeto depende de aplicar o SQL acima.
