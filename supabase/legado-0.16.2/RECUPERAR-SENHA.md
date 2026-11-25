# Recuperação de senha — aplicativo 0.10

## O que já está preparado

O botão **Esqueci minha senha** usa três passos: solicitar um código, digitar o código recebido no e-mail e definir uma nova senha (mínimo de 8 caracteres, com confirmação). O aplicativo usa o fluxo de recuperação do Supabase e só libera a troca após validar o código. Não guarda a senha em arquivos locais.

O botão mostra **Recuperação por e-mail em preparação** enquanto o envio não for ativado no projeto. Instalar a atualização não ativa o envio nem modifica senhas existentes. A ativação posterior é feita no servidor, sem reinstalar os aplicativos dos jogadores.

## Por que precisamos de um remetente

O Supabase precisa de um serviço SMTP para enviar mensagens de recuperação aos jogadores. O serviço padrão de testes tem restrições a destinatários, então não é suficiente para a mesa. O código deve chegar à caixa de entrada do dono da conta; o mestre não recebe o código dos jogadores.

Para uso pequeno e privado, uma opção sem domínio próprio é Gmail. Pode ser o seu Gmail ou um Gmail separado para RPG Master. Usar uma conta separada mantém a integração do aplicativo separada do seu e-mail pessoal. A conta Google precisa permitir **senhas de aplicativo**, que dependem da verificação em duas etapas e podem não estar disponíveis em alguns tipos de conta. O Gmail tem limites de envio; essa opção não é uma promessa de envio ilimitado ou de adequação a um produto comercial.

## Configuração — fazer somente quando escolher o remetente

1. Na conta Google escolhida, ative a verificação em duas etapas, se ainda não estiver ativa. Consulte a [ajuda oficial sobre senhas de aplicativo](https://support.google.com/accounts/answer/185833?hl=pt-BR).
2. Gere uma senha de aplicativo para a conexão com o Supabase. Ela é diferente da senha normal do Google. Guarde-a e preencha-a somente no painel do Supabase. Não envie essa senha no chat, no GitHub, no aplicativo ou aos jogadores.
3. No Supabase, abra **Authentication → Emails** e a configuração de SMTP (o nome da aba pode variar). Preencha o remetente com o Gmail escolhido, nome `RPG Master`, host `smtp.gmail.com`, porta `587`, usuário igual ao endereço completo do Gmail e a senha de aplicativo gerada. Salve. Não é necessário comprar domínio para esse endereço Gmail.
4. Na mesma área de e-mails, abra o modelo **Reset Password / Recovery**. Use o assunto `RPG Master — código de recuperação` e copie o conteúdo de [modelo-email-recuperacao.html](modelo-email-recuperacao.html) para o corpo. O modelo precisa manter literalmente `{{ .Token }}`: esse campo vira o código enviado ao usuário. O fluxo do app utiliza código digitado, não uma página de redirecionamento.
5. **Somente depois de configurar e salvar o remetente e o modelo**, execute [ativar-recuperacao-apos-configurar-email.sql](ativar-recuperacao-apos-configurar-email.sql) numa nova consulta do SQL Editor. Esse arquivo apenas publica o estado de ativação; não altera senhas ou campanhas e não contém credenciais SMTP.
6. Com a versão 0.10 instalada, saia da conta e toque em **Esqueci minha senha**. Teste primeiro com o seu próprio e-mail: solicite o código, confira o spam, digite o código no app e escolha uma nova senha. Não compartilhe o código. Depois confirme que consegue entrar com a nova senha.

O teste com uma mensagem real deve ocorrer após essa configuração. Se o e-mail não chegar, confira SMTP, modelo de recuperação e limites de envio. Não remova contas nem anotações para testar.

## Limites da validação feita no desenvolvimento

As telas, o tratamento de código expirado e a confirmação de senha foram testados. Também há teste com a biblioteca oficial, simulando as respostas de rede: pedido de recuperação, verificação do código do tipo `recovery` e atualização autenticada da senha. Nenhum e-mail real foi enviado nos testes. As regras do estado de ativação foram testadas num PostgreSQL descartável: o app pode ler apenas um booleano; somente o administrador pode alterá-lo. O domínio do projeto segue bloqueado no ambiente de desenvolvimento.
