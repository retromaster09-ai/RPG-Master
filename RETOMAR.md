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
  os testes e a compilação web passaram. A compilação Android e o teste
  com duas contas no Supabase ainda estão pendentes.
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
- Nenhuma modificação foi aplicada ao Supabase durante a análise.

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

Os nove scripts originais, em ordem histórica, foram aplicados em
PostgreSQL descartável. O teste `supabase/teste-local/permissoes.sql`
confirmou que mestre e jogador leem o caderno e que apenas o mestre
lê as notas e o catálogo dos arquivos privados. O banco de produção
não foi usado. O teste pelo SDK Flutter e pelas APIs de Auth e Storage
está preparado em `supabase/teste-local/`; a execução completa ficou
pendente por falta de espaço no Docker do ambiente Codex.

## Prioridades

1. A primeira implementação já usa `rpg_read_notebook(p_campaign)` e
   `rpg_gm_list_v2(p_campaign)` para leitura, além da lista de campanhas.
   O export atual tem 98 entradas em array de objetos; 17 têm categoria
   `Sessão`, das quais quatro estão na lixeira. O leitor usa `category`,
   `title`, `body`, `answer`, `confidence` e `deletedAt`. O SQL original
   confirma o envelope `{"entries": [...]}`. Falta testar no servidor.
2. Testar em ambiente separado a leitura com contas de mestre e jogador.
   Preservar as migrações do banco e verificar as políticas e a
   autorização das funções com ambas as contas. Implementar a edição
   com `p_expected`, `p_epoch` e `p_entries` e testar gravações
   concorrentes antes de habilitar gravação de conteúdo existente.
3. Adicionar login por nome de usuário e senha preservando o UUID de quem
   já tem conta. Na recuperação, o mestre autorizado aprova o pedido e
   envia o código pelo canal que desejar. O código expira, só pode ser
   usado uma vez e tem limite de tentativas. Definir a recuperação do
   próprio mestre antes de substituir o fluxo antigo.
4. Implementar depois iniciativa e condições, contagem de fúria,
   concentração, fichas e VTT. No VTT, o jogador recebe somente as áreas
   autorizadas, incluindo quando inspecionar o tráfego do próprio app.

## Guardar e continuar

- Manter um repositório privado sob controle do mestre e registrar nele
  código, recursos, configurações de exemplo, migrações e instruções
  de compilação. Ao concluir uma etapa, atualizar este arquivo e enviar
  o commit ao repositório privado.
- Guardar backups dos dados e dos arquivos do Storage separadamente.
  Guardar credenciais e a chave de assinatura Android em lugar privado.
  Um backup só está verificado depois de uma restauração de teste.
- Para uma cópia histórica sem depender do servidor Git, executar
  `git bundle create RPG-Master-Set.bundle --all` na pasta do projeto.
  Para abrir depois, usar
  `git clone RPG-Master-Set.bundle rpg-master-set`.
- Em outro chat, anexar o ZIP do projeto ou abrir o repositório e pedir
  "Leia RETOMAR.md, confira o último commit e continue a próxima etapa."
