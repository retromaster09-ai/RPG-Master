# Compartilhar as notas — versão 0.9

Requer o projeto já preparado para contas e campanhas na versão 0.8.

1. Abra [compartilhar-notas.sql](compartilhar-notas.sql), copie TODO o texto e cole numa nova consulta do SQL Editor do seu projeto Supabase. Clique em Run. O resultado esperado é `Success. No rows returned`.
2. Instale a versão 0.9 sobre a anterior, sem desinstalar. Use sua conta e a campanha que já criou.
3. Dentro da campanha, abra o menu ☰ → **Trazer anotações locais**. Escolha **Caderno deste aparelho** para as notas antigas. Se escreveu notas na campanha da versão 0.8, escolha a outra opção para copiá-las também.
4. Confira o nome da campanha, a quantidade de registros, imagens e cópias ignoradas. A transferência compartilha conteúdo, histórico e imagens com TODOS os membros da campanha. Não inclua segredos do mestre. Cancelar não envia nada.
5. Confirme em **Copiar e compartilhar**. O original continua no aparelho; cópias idênticas são ignoradas, versões diferentes são acrescentadas. A primeira cópia não é automática.
6. Volte à lista e aguarde **Sincronizado com a campanha**, ou toque no botão de sincronizar no rodapé. As listas verificam mudanças a cada 8 segundos quando o aplicativo está em primeiro plano; não há atualização durante a leitura ou edição de uma nota. Para enviar as alterações, volte à lista.
7. Cada jogador instala a mesma versão 0.9, cria sua própria conta e entra pelo convite da campanha. O mestre gera um convite por jogador (uso único, 7 dias), como antes.
8. Teste uma nota simples entre dois aparelhos. Para testar um conflito, abra a mesma nota nos dois, altere em ambos antes de sincronizar, e volte às listas. As duas versões serão preservadas; uma terá **(versão para revisar)** no título.

## Dados e conexão

Alterações são gravadas no aparelho antes do envio. Se a rede cair ou a confirmação de envio se perder, a fila fica guardada para uma nova tentativa. Abrir uma campanha conhecida sem internet depende da sessão e da cópia local já existentes. A indicação **Aguardando envio** não confirma que outro jogador já recebeu o conteúdo. Só **Sincronizado** confirma a comunicação com o servidor naquela tentativa.

As imagens são guardadas num bucket privado, com acesso restrito aos membros da campanha. Não são links públicos. O aplicativo não sobrescreve nem remove imagens já enviadas. Imagens podem ter até 20 MB e o caderno compartilhado tem limite de 8 MiB de JSON no servidor. Os últimos 20 salvamentos compartilhados ficam registrados para recuperação técnica; não há botão de restauração desse histórico ainda. Backup ZIP e PDF continuam disponíveis.

A área privada do mestre continua como prévia e não deve receber segredos. Nesta atualização todas as notas compartilhadas são visíveis aos membros da campanha. Capas, logo e instalador Windows continuam para etapas futuras.

## Verificação

62 testes do aplicativo passaram. Há testes com dois clientes para alterações distintas, conflitos na mesma nota, falhas depois do commit, retomada offline, imagens entre diretórios, dados locais preservados, prévia/cancelamento e transferências repetidas. A migração foi aplicada e reaplicada num PostgreSQL 17 descartável com stubs de auth/storage. Os testes SQL verificam acesso por membros, bloqueio de anônimos e outras campanhas, revogação de membro, CAS, validação dos dados, versões e privacidade das imagens. O serviço de armazenamento real e o fluxo entre celulares precisam de teste após aplicar o SQL, pois o domínio do Supabase continua bloqueado pela política de rede do ambiente de desenvolvimento.
