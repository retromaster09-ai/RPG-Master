# RPG Master Set — códigos e participantes (0.12)

1. Abra [o SQL de códigos e participantes](https://raw.githubusercontent.com/retromaster09-ai/RPG-Master/main/downloads/configuracao/codigos-e-participantes.sql), selecione e copie todo o texto.
2. No mesmo projeto Supabase, abra SQL Editor, crie uma consulta com +, cole o texto e clique Run. Aguarde `Success. No rows returned`. Não precisa excluir consultas anteriores.
3. Instale o APK 0.12 como atualização, sem desinstalar. Nome novo: **RPG Master Set**. A identidade interna é a mesma para preservar contas e anotações.
4. Entre na conta do mestre. Em Suas campanhas, toque **Acesso e participantes** na campanha.
5. Digite um código de 10 a 48 caracteres, com letras sem acentos, números, hífen ou sublinhado. Exemplo de formato: `CorvosDaBarovia27`. Escolha seu próprio código. Toque **Salvar código** e **Copiar código** para compartilhar com o grupo.
6. Cada jogador atualiza o aplicativo, entra na própria conta e toca **Entrar por código**. O código da campanha é diferente da senha pessoal da conta.

O código pode ser usado por vários jogadores. Maiúsculas e minúsculas são equivalentes. Se já estiver em uso por outra campanha, escolha outro. Guardamos somente a impressão digital do código, sem permitir recuperar o texto: depois de fechar a janela, se esquecer, defina outro.

**Desativar código** impede novas entradas por ele. Salvar outro código substitui o anterior. Quem já entrou continua participante. Os convites antigos de 64 caracteres continuam válidos até seu uso ou expiração original; desligar o código novo não cancela esses convites antigos.

Há limite de cinco tentativas por conta a cada quinze minutos, inclusive entradas bem-sucedidas. A pessoa entra sempre como jogador; não recebe o papel de mestre. A lista com e-mails e papéis fica disponível somente para o criador daquela campanha.

## Onde consultar todas as contas

No painel Supabase, **Authentication → Users** lista as contas cadastradas. Uma conta ainda sem campanha também aparece ali. O aplicativo não possui perfis adicionais separados: cada conta pode participar de várias campanhas e ter papéis diferentes em cada uma.

Para contagens gerais, o administrador do projeto pode executar separadamente esta consulta de leitura no SQL Editor:

```sql
select
 (select count(*) from auth.users) as contas_cadastradas,
 (select count(*) from public.rpg_campaigns) as campanhas,
 (select count(distinct user_id) from public.rpg_members where role='gm') as contas_que_mestram,
 (select count(distinct user_id) from public.rpg_members where role='player') as contas_que_jogam;
```

As duas últimas contagens podem se sobrepor: a mesma pessoa pode mestrar uma campanha e jogar em outra. Esses totais não ficam acessíveis aos jogadores pelo aplicativo.

Esta atualização não ativa recuperação de senha por e-mail e não cria a área privada de anotações do mestre. A sincronização das anotações compartilhadas e as capas continuam como antes. Não é necessário configurar o Gmail para usar os códigos.
