# Preparar contas e campanhas — versão 0.8

Este arquivo configura somente campanhas, membros e convites. Não envia as anotações do aparelho e não cria tabelas de segredos do mestre.

1. Abra `preparar-campanhas.sql`, copie todo o texto e cole em uma nova consulta no **SQL Editor** do seu projeto Supabase.
2. Clique em **Run**. O resultado esperado é `Success. No rows returned`.
3. Em **Authentication → Sign In / Providers → Email** (o nome pode variar), mantenha login por e-mail e novos cadastros habilitados. Para testes com a mesa sem serviço de envio de e-mail, desative **Confirm email** e salve. Use senhas de pelo menos 8 caracteres no aplicativo.
4. Nessa configuração inicial, o e-mail identifica a conta, mas sua posse não é verificada. Convites secretos são necessários para entrar nas campanhas; jogadores não ganham acesso por saber um endereço de e-mail. Guarde a senha: recuperação por e-mail depende de configurar SMTP posteriormente.
5. Instale a versão 0.8 como atualização, sem desinstalar. A primeira tela oferece **Criar uma conta** e **Entrar**, além do acesso offline ao **Caderno deste aparelho**.
6. Crie uma campanha. O criador é mestre. Em **Convidar jogador**, copie um convite para cada pessoa (7 dias, uso único). Quem usa o convite entra como jogador.

**Limites desta etapa:** contas e lista de campanhas são online. As anotações ainda são locais e separadas por conta e campanha; não aparecem automaticamente no aparelho de outro jogador. O caderno anterior continua acessível sem login e não é movido nem enviado. A área secreta do mestre e a sincronização de notas ainda não foram ativadas.

**Validação:** migração aplicada e reaplicada num PostgreSQL 17 descartável, com testes de isolamento entre campanhas, acesso anônimo negado, papéis de mestre/jogador, escalada de privilégios, privacidade dos convites, uso único e expiração. A autenticação remota precisa ser conferida após a configuração do projeto: o ambiente de desenvolvimento bloqueia esse domínio por política de rede. Não é necessário fornecer senha do banco ou chave secreta para executar este procedimento.
