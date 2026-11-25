# Retomar o RPG Master Set

Este arquivo resume as decisões para continuar a reconstrução em outro
chat. Leia também o README e o histórico Git.

## Situação

- O APK enviado pelo mestre é o RPG Master Set 0.16.2, Flutter Android
  ARM64, pacote `com.rpgmaster.rpg_master`. O original foi assinado com
  chave de depuração. O código Dart original ainda não foi localizado.
- O primeiro commit preservou os recursos visuais e as fontes do APK.
  Este repositório ainda não contém um aplicativo Flutter executável.
- O mestre tem acesso ao projeto Supabase de produção usado pelo APK.
  O banco tem dados de teste. O mestre exportou os cinco CSVs das tabelas
  conhecidas. O download das imagens de teste ficou opcional.
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
de gravação. Os tipos dos argumentos aparecem no CSV, sem os nomes que
o PostgREST espera e sem os tipos de retorno.

## Prioridades

1. Executar `supabase/contrato-rpc.sql` no SQL Editor para confirmar nomes
   de argumentos e tipos de retorno. Se o retorno for JSONB, confirmar o
   formato com a definição apropriada ou uma amostra de teste. Preservar
   as definições do banco para poder restaurá-lo em um ambiente separado.
2. Reconstruir em Flutter a lista de campanhas, o caderno colaborativo,
   as crônicas e o roteiro privado. Usar contas de teste de mestre e
   jogador para verificar leitura e gravação concorrente no caderno e
   verificar a proteção de notas e imagens privadas no servidor.
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
