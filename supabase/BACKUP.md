# Backup e restauração do RPG Master Set

Antes de alterar o Supabase principal, faça uma cópia e teste a restauração em
um ambiente separado. Use o mesmo procedimento antes de mudanças no banco e
periodicamente quando houver dados de campanha em uso.

## Conferência de 25/11/2026

Os cinco CSVs exportados são legíveis. As quantidades correspondem à consulta
de leitura feita no banco principal.

| Conteúdo | Registros no banco | Cópia conferida |
| --- | ---: | --- |
| Campanhas | 1 | CSV |
| Participações | 4 | CSV |
| Cadernos compartilhados | 1 | CSV |
| Versões dos cadernos | 20 | CSV |
| Notas do mestre | 2 | CSV |
| Contas do Supabase Auth | 4 | Pendente |
| Arquivos em `rpg-notes` | 9 | Pendente |
| Arquivos em `rpg-gm-private` | 3 | Pendente |

A conferência compara quantidades. Uma cópia restaurável inclui o esquema,
as regras de acesso, os UUIDs das contas e o conteúdo dos arquivos. O código
e as migrações ficam no Git. As cópias da campanha ficam em local privado.
As 12 imagens de teste são descartáveis segundo o mestre. O download delas
é opcional para desenvolver e testar o novo app.

## Fazer a cópia

1. Crie uma pasta datada fora do repositório. Guarde nela os CSVs, a cópia
   do banco e o Storage. Mantenha uma segunda cópia cifrada em outro local.
2. Gere os três arquivos `roles.sql`, `schema.sql` e `data.sql` conforme o
   [guia oficial da CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore#back-up-database-using-the-cli).
   Use **Connect → Session pooler** no painel do projeto principal e informe
   a senha do banco no seu computador. Preserve o conteúdo de `auth.users` no
   dump, pois os UUIDs ligam as contas às participações da campanha.
3. Guarde as personalizações de `auth` e `storage`, em particular as políticas
   de `storage.objects`. Siga o
   [procedimento para esquemas gerenciados](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore#schema-changes-to-auth-and-storage)
   e mantenha as alterações do projeto nas migrações do Git.
4. No painel, abra **Storage → Files**. Entre em `rpg-notes` e em
   `rpg-gm-private`, abra as subpastas e use **Download** em cada arquivo.
   Preserve o nome do bucket e o caminho completo de cada objeto. Guarde
   também as opções dos buckets, incluindo a visibilidade privada, os limites
   de tamanho e os tipos de arquivo. Confira a contagem no painel e abra uma
   amostra dos arquivos baixados.
5. Registre as configurações do painel necessárias ao app, como as opções de
   Auth e Realtime. Guarde os valores de segredos usados pelas funções e a
   chave de assinatura Android no seu gerenciador de senhas. O código da
   função `rpg-account` está em `supabase/functions/`. Veja [CONTAS.md](CONTAS.md)
   para reimplantá-la se ela estiver ativa na versão restaurada.

Os três arquivos SQL podem conter dados de autenticação. Guarde-os com a
mesma proteção das notas privadas e mantenha-os fora do GitHub e do chat.

## Testar a restauração

1. Num projeto descartável, restaure os arquivos SQL com o
   [procedimento oficial](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore#restore-backup-using-cli).
   Restaure as regras dos esquemas gerenciados e reconfigure Auth e Realtime.
2. Restaure o conteúdo pela API do Storage, nos mesmos buckets e caminhos.
   Confira que os dois buckets continuam privados.
3. Compare o número de campanhas, participações, cadernos, versões, notas,
   contas e arquivos com o inventário feito na hora da cópia.
4. Abra o app apontando para o ambiente restaurado. Confirme o acesso do
   jogador ao caderno e o acesso exclusivo do mestre às notas e imagens
   privadas. Use contas controladas pelo mestre para testar essa diferença.
5. Registre a data e o resultado do teste junto da cópia privada.
