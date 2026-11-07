# Organização e lixeira — 0.16

Requer a configuração da versão 0.15 já aplicada.

1. No SQL Editor do mesmo projeto Supabase, abra uma nova consulta, cole todo o arquivo `organizacao-e-lixeira-0.16.sql` e clique em Run. Aguarde `Success. No rows returned`. Não precisa excluir consultas antigas. Este SQL não apaga nem reorganiza suas notas.
2. Todos os participantes devem atualizar para o APK 0.16 antes de usar os recursos. Instale como **Atualizar**, sem desinstalar. Após o primeiro salvamento novo, versões antigas ficam impedidas de sobrescrever os dados compartilhados.

## Organizar

Use Organizar na barra superior. Segure o marcador do cartão e arraste, ou use as setas. Toque em Concluir para salvar. Cada aba tem sua ordem; na Enciclopédia, cada categoria também. Limpe a busca e selecione Todas nas missões antes de organizar. Nas sessões, alterne entre Por data e Ordem manual.

O som discreto do sistema e a vibração podem ser desativados no organizador. A preferência fica neste aparelho e depende dos ajustes do sistema; não é uma trilha sonora personalizada.

## Lixeira

No menu ⋮ do cartão, escolha Duplicar ou Mover para a lixeira. A aba Lixeira permite restaurar. Não há prazo de exclusão automática. Na campanha compartilhada, somente o criador pode excluir definitivamente, após confirmação e sincronização bem-sucedida. No caderno pessoal, o próprio usuário pode excluir.

O roteiro privado possui sua própria lixeira, acessível apenas ao criador e protegida pelo bloqueio existente. Seus cartões e sua organização não são publicados no caderno dos jogadores.

A exclusão definitiva remove a nota do histórico compartilhado no servidor e mantém um marcador para impedir que uma cópia antiga seja reenviada automaticamente. Não apaga arquivos exportados, fotos originais ou cópias já existentes fora do app. Não representa apagamento físico de backups externos.

Organização, envio à lixeira e restauração do caderno compartilhado podem aguardar conexão. O roteiro privado continua exigindo conexão. Não use Resetar campanha para instalar esta atualização.

## Sincronização

Se aparecer Envio pendente, toque no botão de informações junto ao estado de sincronização para consultar a mensagem disponível. O app distingue problemas como SQL ausente, conexão e permissões sem expor o conteúdo das notas. Isso não confirma a causa de um erro anterior sem reproduzi-lo.

A configuração de recuperação por e-mail permanece pendente. Não é necessária para esta atualização. O instalador para PC também permanece como trabalho futuro.

Validação: 114 testes Flutter passaram, análise estática sem problemas e regras de organização, privacidade, restauração e exclusão verificadas em PostgreSQL descartável. Nenhuma campanha real foi apagada nos testes.
