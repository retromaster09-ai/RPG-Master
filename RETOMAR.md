# Retomar o RPG Master Set

Este arquivo resume as decisões para continuar a reconstrução em outro
chat. Leia também o README e o histórico Git.

## Situação

- O APK enviado pelo mestre é o RPG Master Set 0.16.2, Flutter Android
  ARM64, pacote `com.rpgmaster.rpg_master`. O original foi assinado com
  chave de depuração. O código Dart original ainda não foi localizado.
- O primeiro commit preservou os recursos visuais e as fontes do APK.
  O repositório agora contém a primeira implementação Flutter. O README
  explica como executá-la com o SDK fixado. Em 25/11/2026, a análise,
  os testes e a compilação web passaram.
- Os 24 commits do repositório público `retromaster09-ai/RPG-Master`
  contêm APKs, prévias e scripts do Supabase. Não apareceu o projeto
  Flutter original. Os scripts e guias foram preservados em
  `supabase/legado-0.16.2/`.
- O mestre tem acesso ao projeto Supabase de produção usado pelo APK.
  O banco tem dados de teste. O mestre exportou os cinco CSVs das tabelas
  conhecidas e os anexou em 25/11/2026. Os dados do mestre e da campanha
  ficam fora do Git. A conferência em 25/11/2026 confirmou que as contagens
  dos CSVs batem com o banco principal. A cópia restaurável das contas e
  dos arquivos continua pendente. Veja [Backup e restauração](supabase/BACKUP.md).
- O CSV de metadados em `supabase/inventario-0.16.2.csv` confirma cinco
  tabelas, 38 colunas, 22 assinaturas de funções e nove políticas.
  A lista de políticas mostra os nomes e as operações, sem a lógica das
  regras. A função `rpg_app_capabilities` aparece no APK e não aparece no
  inventário fornecido.
- O Supabase de produção ficou intacto. A migração
  `20261125123722_rpg_master_legacy_0162` foi aplicada ao projeto de teste.

## Contrato confirmado

| Tabela | Papel na reconstrução |
| --- | --- |
| rpg_campaigns | Campanha, criador e metadados da capa |
| rpg_members | Participação por ID de usuário, campanha e papel |
| rpg_notebooks | Caderno compartilhado em JSONB, com revisão e época |
| rpg_notebook_versions | Versões do caderno e autoria da gravação |
| rpg_gm_notes | Notas do mestre, com título, corpo, revisão e exclusão lógica |

O APK faz referência aos buckets `rpg-notes` e `rpg-gm-private`.
O caderno tem sincronização por revisão, com
`rpg_poll_notebook_v3` e `rpg_save_notebook_v3`. A lista privada tem
`rpg_gm_list_v2`. Preserve o controle de revisão ao reconstruir o fluxo
de gravação. O CSV `supabase/contrato-rpc-0.16.2.csv` confirma os nomes
usados pelo PostgREST e os tipos de retorno das cinco funções principais.

## Validação da área privada

Os nove scripts originais foram aplicados na ordem histórica, primeiro
em PostgreSQL descartável e depois no projeto Supabase de teste.
`supabase/teste-local/permissoes.sql` verifica notas e catálogo de
arquivos. O teste pelo SDK Flutter também passou com duas contas
fictícias. Ele confirmou login, entrada por convite, leitura do caderno
e das crônicas e bloqueio de notas e downloads privados para o jogador.

O teste encontrou que a RPC antiga `rpg_read_notebook` rejeita cadernos
depois de habilitada a organização da versão 0.16. O leitor usa
`rpg_poll_notebook_v3(p_campaign, -1)` para obter uma cópia completa
e `rpg_gm_list_v2(p_campaign)` para o roteiro do mestre.

As funções legadas com privilégios elevados foram mantidas para
compatibilidade. Antes de levar futuras mudanças à produção, revise
as autorizações de cada função tocada e rode os testes novamente.
[Orientação do Supabase sobre funções privilegiadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)

## Prioridades

A criação e edição de registros e crônicas usa `rpg_try_save_notebook_v3`,
que delega a gravação à função original e sinaliza revisões desatualizadas
para o editor. A migração foi aplicada no projeto de teste. A chamada
preserva `p_expected`, `p_epoch` e o JSON original. O editor preserva campos
legados e itens na lixeira. Em caso de conflito no mesmo campo, mantém
o rascunho e permite comparar com o texto salvo antes de reenviar.

O mestre confirmou no teste do APK ARM64 `0.17.0-dev.1` em dois
celulares que as alterações apareceram nos dois aparelhos e que a
aba **Mestre** ficou disponível só para a conta do mestre. O teste foi
feito no projeto Supabase separado. As credenciais ficam fora do Git.

### Login por usuário e recuperação de senha

A versão `0.17.0-dev.2` implementa o login por nome de usuário e
a recuperação sem e-mail. O usuário vincula um nome único à sua
conta existente, preservando o UUID. Em **Minha conta**, pode
autorizar o mestre de uma campanha em que participa como jogador
e pode gerar um código de reserva para si.

O mestre autorizado aprova o pedido e repassa o código por um
canal que escolher. O código vale 15 minutos, funciona uma vez e
tem limite de tentativas. O código de reserva permite recuperar
a conta do mestre pelo mesmo formulário. A alteração da senha
revoga as sessões anteriores.

A migração de contas e a função `rpg-account` foram aplicadas ao
projeto de teste. Os testes de integração verificaram o vínculo da
conta, a aprovação pelo mestre correto, a troca da senha, a revogação
de sessão e o código de reserva. No APK, o mestre confirmou o teste
com as duas contas em um celular. O jogador vinculou um nome de
usuário, solicitou o código, redefiniu a senha após a aprovação do
mestre e conseguiu entrar com o usuário e a senha nova. A geração
do código de reserva também funcionou no aparelho.

A ativação no projeto principal ainda está pendente. O procedimento
está em [CONTAS.md](supabase/CONTAS.md). O [APK ARM64 deste teste](downloads/RPG-Master-Set-0.17.0-dev.2-android-arm64-teste.apk)
atualiza o APK de teste anterior com a mesma assinatura.

Depois ficam iniciativa e condições, contagem de fúria, concentração,
fichas e VTT. No VTT, o jogador recebe somente as áreas autorizadas,
inclusive quando inspeciona o tráfego do próprio app.

## Guardar e continuar

- Registrar código, recursos, configurações de exemplo, migrações e
  instruções de compilação no GitHub do mestre. O repositório está
  público por escolha do mestre nesta etapa. Ao concluí-la, atualizar
  este arquivo e enviar o commit ao repositório.
- Seguir o [guia de backup e restauração](supabase/BACKUP.md) para guardar
  os dados do banco e os arquivos do Storage separadamente.
  Guardar credenciais e a chave de assinatura Android em lugar privado.
  Um backup só está verificado depois de uma restauração de teste.
- Para uma cópia histórica sem depender do servidor Git, executar
  `git bundle create RPG-Master-Set.bundle --all` na pasta do projeto.
  Para abrir depois, usar
  `git clone RPG-Master-Set.bundle rpg-master-set`.
- Em outro chat, anexar o ZIP do projeto ou abrir o repositório e pedir
  "Leia RETOMAR.md, confira o último commit e continue a próxima etapa."
