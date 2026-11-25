# Login e recuperação de conta

## Usar no app

1. Quem já tem conta entra uma vez em **Primeiro acesso com a conta
   antiga** usando o e-mail e a senha que já conhece.
2. Em **Minha conta**, escolhe um nome de usuário e salva. Quem joga
   em uma campanha pode escolher o mestre dessa campanha para
   autorizar recuperações. A escolha pode ficar vazia.
3. Em **Minha conta**, a pessoa também pode gerar um código de
   reserva de uso único para guardar. Um novo código substitui o
   anterior. Isso permite que o próprio mestre recupere a conta.
4. Em **Esqueci minha senha**, o jogador informa seu usuário e pede
   o código. O mestre autorizado abre **Minha conta**, toca em
   **Atualizar pedidos**, confirma o pedido com o jogador e aprova.
   O código aparece uma vez e expira em 15 minutos. O mestre o
   repassa pelo canal escolhido, como WhatsApp.
5. O jogador usa **Já tenho um código** para escolher a nova senha.
   As sessões antigas são revogadas. Cinco tentativas incorretas
   bloqueiam novas tentativas pelo restante da janela de 15 minutos.

O vínculo usa o UUID existente do Supabase Auth. Se a API de Auth
falhar depois de aceitar um código, ele já terá sido consumido. Para
o jogador, é possível pedir outro código. Guarde o código de reserva
e confirme o acesso à conta antes de substituir um código anterior.

## Implantar em um projeto de teste

O projeto precisa dos scripts históricos e das migrações do
repositório na ordem registrada em `supabase/teste-local/`. A Edge
Function usa as chaves padrão injetadas pelo Supabase no servidor.
Use no Flutter somente a chave pública do projeto.

```sh
supabase functions deploy rpg-account --project-ref REFERENCIA_DO_PROJETO_DE_TESTE --no-verify-jwt
```

A função recebe chamadas de login e recuperação antes da sessão.
As operações de configuração, aprovação e geração de reserva
validam o token do usuário no Supabase Auth. A função de banco
`rpg_account` é acessível apenas ao papel de serviço no servidor.
O banco guarda os hashes dos códigos e aplica expiração e uso único.
O projeto de produção precisa da mesma migração e da função para
adotar este login.

## Teste de integração

Em um projeto de teste separado, prepare três contas fictícias
confirmadas com e-mails de exemplo. O jogador deve participar como
`player` de uma campanha criada pelo mestre. Para testar um mestre
alternativo, adicione o jogador a uma segunda campanha criada pela
terceira conta. O teste troca as senhas de duas contas, portanto
use apenas contas descartáveis.

Crie um JSON privado, fora do Git, com `url`, `test_project_ref`,
`publishable_key`, `campaign` e `accounts`. A lista `accounts` contém
os campos `id`, `email`, `password` e `role` (`gm`, `player`, `outside`).

```sh
python3 supabase/teste-local/contas_test.py /caminho/privado/contas.json
```
