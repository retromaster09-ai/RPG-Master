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
  os testes e a compilação web passaram. A compilação Android ainda
  está pendente.
- Os 24 commits do repositório público `retromaster09-ai/RPG-Master`
  contêm APKs, prévias e scripts do Supabase. Não apareceu o projeto
  Flutter original. Os scripts e guias foram preservados em
  `supabase/legado-0.16.2/`.
- O mestre tem acesso ao projeto Supabase de produção usado pelo APK.
  O banco tem dados de teste. O mestre exportou os cinco CSVs das tabelas
  conhecidas e os anexou em 25/11/2026. Os dados do mestre e da campanha
  ficam fora do Git. O download das imagens de teste ficou opcional.
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

1. Gerar um APK de teste com o identificador separado e testar num
   aparelho. A compilação web e os testes Dart já foram verificados.
2. Adicionar login por nome de usuário e senha preservando o UUID de quem
   já tem conta. Na recuperação, o mestre autorizado aprova o pedido e
   envia o código pelo canal que desejar. O código expira, só pode ser
   usado uma vez e tem limite de tentativas. Definir a recuperação do
   próprio mestre antes de substituir o fluxo antigo.
3. Implementar depois iniciativa e condições, contagem de fúria,
   concentração, fichas e VTT. No VTT, o jogador recebe somente as áreas
   autorizadas, incluindo quando inspecionar o tráfego do próprio app.

## Guardar e continuar

- Registrar código, recursos, configurações de exemplo, migrações e
  instruções de compilação no GitHub do mestre. O repositório está
  público por escolha do mestre nesta etapa. Ao concluí-la, atualizar
  este arquivo e enviar o commit ao repositório.
- Guardar backups dos dados e dos arquivos do Storage separadamente.
  Guardar credenciais e a chave de assinatura Android em lugar privado.
  Um backup só está verificado depois de uma restauração de teste.
- Para uma cópia histórica sem depender do servidor Git, executar
  `git bundle create RPG-Master-Set.bundle --all` na pasta do projeto.
  Para abrir depois, usar
  `git clone RPG-Master-Set.bundle rpg-master-set`.
- Em outro chat, anexar o ZIP do projeto ou abrir o repositório e pedir
  "Leia RETOMAR.md, confira o último commit e continue a próxima etapa."
