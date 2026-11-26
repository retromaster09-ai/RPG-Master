# Retomar o RPG Master Set

Este arquivo resume as decisões para continuar a reconstrução em outro
chat. Leia também o README e o histórico Git. Desde 0.17.0-dev.13,
o caderno abre em um índice do [modelo dos jogadores](MODELO_CADERNO.md)
e separa missões ativas das concluídas pelo estado já salvo.
O mesmo arquivo documenta a importação de Word e o roteiro para PDF.

A versão 0.17.0-dev.14 acrescenta índice ilustrado, capas nos registros
compartilhados e páginas de leitura. Os dados de capa reutilizam
`imagePath` e o bucket de membros existente, sem migração. O 0.17.0-dev.15 recupera no Caderno e nas Crônicas
os estilos de página, a formatação de texto e as imagens entre parágrafos.
O enquadramento fica em `thumbLook` e a página de leitura mostra a capa
inteira. As marcas usam posições UTF-16 e os campos `bodyMarks` e
`answerMarks`. A formatação no roteiro privado ainda é uma etapa à parte.

O 0.17.0-dev.16 acrescenta remoção de fundo por cor e ajuste de tamanho,
zoom e posição nas imagens do texto. A imagem original mantém o campo
`path` e o derivado usa `cutoutPath`, ambos no mesmo bucket privado.
O ajuste usa `look` e preserva os campos legados não editados.

O 0.17.0-dev.17 restaura a importação de Word no Caderno. O leitor
local prepara a prévia, que deixa ambiguidade e títulos repetidos para
revisão. O envio confirmado usa a revisão existente do caderno para incluir
apenas os registros escolhidos, preservando o conteúdo anterior. PDF ainda
é uma etapa futura. O Word dos jogadores fica fora do repositório.

O 0.17.0-dev.18 move a importação de Word para as ferramentas no índice
do Caderno. Hipóteses aparecem como filtro em Mistérios e pistas, usando
o campo de confiança que já existe nos registros.

O 0.17.0-dev.19 acrescenta conclusão confirmada ou refutada nas
hipóteses, com motivo e reabertura. O caderno usa `resolution` e
`resolutionReason`, preservando o texto da nota e a resposta. O mesmo
APK exporta o conjunto de crônicas em PDF e a crônica aberta em PNG.

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
  dos CSVs batem com o banco principal. O mestre decidiu pular o download
  das imagens descartáveis para priorizar o app. O procedimento para
  dados em uso está em [Backup e restauração](supabase/BACKUP.md).
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

O [levantamento das funções do app anterior](PARIDADE.md) registra o que
falta na reconstrução e a ordem proposta. O `0.17.0-dev.5` implementa
cadastro por usuário e senha, criação de mesa, entrada por código ou convite
e consulta de participantes. As próximas etapas do uso diário do caderno
incluem formatação e imagens entre parágrafos.

O `0.17.0-dev.6` guarda localmente a lista de campanhas, a última revisão
do caderno compartilhado e os rascunhos de texto. A chave é separada por
projeto, conta e campanha. No Android, os dados são escritos em arquivos
privados do app com substituição após gravação; na web, são armazenados no
navegador. A primeira cópia exige conexão e uma sessão ativa. A fila guarda
apenas edições em que a pessoa tocou **Salvar**. Com a campanha aberta, o app
volta a verificar o servidor a cada oito segundos e ao retomar a tela.
Uma entrada em envio fica disponível para editar após confirmação ou conflito.
Rascunhos de uma geração anterior a um reset ficam para revisão. A aba Mestre
continua online e usa apenas a sessão existente. O recurso usa as RPCs já
implantadas no ambiente de teste.

O `0.17.0-dev.7` recupera os cartões com capa de campanha e usa a arte
original dos aventureiros como padrão. Somente o mestre salva ou troca
a capa. Os membros usam o Storage autenticado do bucket `rpg-notes`.
Já foram preservados o caminho, a revisão e o enquadramento legados.
A migração `20261125220138_rpg_try_set_campaign_cover`, aplicada no projeto
de teste, permite tratar conflitos de revisão na troca de capa. Também
entraram busca por texto no caderno e nas crônicas e filtro por categoria
no caderno. Funcionam sobre as notas e os rascunhos no aparelho.

O `0.17.0-dev.8` recupera as datas das crônicas. É possível adicionar,
editar e remover várias datas no calendário em português. O campo legado
`dates` continua armazenando timestamps ISO. A interface usa o dia civil
que consta do timestamp, preservando datas legadas e evitando deslocamento
de fuso na exibição. O app ordena pela primeira data de cada crônica, com
opção de inverter e crônicas sem data no fim. A fila local também guarda as
datas. Alterações concorrentes nesse campo vão para **Revisar edição**.
O recurso usa as RPCs já presentes no projeto de teste.

O `0.17.0-dev.9` recupera mover para a lixeira e restaurar. O Caderno e as
Crônicas usam uma lixeira compartilhada, e a aba Mestre abre sua lixeira
privada. Alterar o estado exige conexão nesta etapa. No caderno, a operação
preserva os campos da revisão mais recente e confere a geração da campanha.
Na área privada, a migração `20261126090345_rpg_try_set_gm_trash` delega à
função legada que restringe o acesso ao criador da campanha. Foi aplicada
ao projeto de teste. Exclusão definitiva ainda está pendente.

O `0.17.0-dev.10` recupera a duplicação e a ordem manual no Caderno,
nas Crônicas e nos grupos da aba Mestre. Duplicar usa um novo ID e conserva
o conteúdo e as referências de imagem da nota. O organizador compartilha
a ordem salva com os participantes autorizados e confere o estado que
a pessoa viu ao abrir a lista. As Crônicas seguem com opção de ordem por
data. As operações exigem conexão. A migração
`20261126091536_rpg_order_gm_group` protege a organização dos grupos privados
e está aplicada ao projeto de teste.

O `0.17.0-dev.11` recupera prioridade, estados, etapas e progresso das
missões. O app reaproveita os campos legados `priority`, `started`,
`completed` e `steps` no caderno compartilhado. A fila preserva esses campos
em rascunhos offline e reconcilia prioridade, estado e etapas de forma
independente. Edições incompatíveis na lista de etapas ficam para revisão.
O filtro por estado aparece ao selecionar **Missão** no Caderno. A busca
inclui títulos e detalhes das etapas. Usa as RPCs existentes do caderno.

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

No teste, o cadastro e as novas telas de campanha usam as migrações
`20261125210922_rpg_registration_and_campaign_access` e
`20261125211411_rpg_register_profile_on_auth_metadata`, e a versão 3 da
função `rpg-account`. O cadastro cria um identificador interno de Auth e o associa
ao nome de usuário na mesma transação. A tela de participantes usa o nome de
usuário quando disponível. As ações de gerenciamento ficam dentro da mesa,
reservadas ao mestre e disponíveis com a sessão já autenticada.

O roteiro privado ganhou criação e edição de texto na versão
`0.17.0-dev.3`, em Ideias, Cenas e Bastidores. A migração
`20261125181256_rpg_try_save_gm_note` trata conflitos pela revisão e delega
ao `rpg_gm_save_visual`. Foi aplicada no projeto de teste.
O mestre confirmou no celular que a aba **Mestre** aparece na campanha
criada por ele e fica indisponível nas campanhas em que joga como convidado.

A versão `0.17.0-dev.4` inclui páginas de leitura de Personagem, Reino e
Organização. A classificação fica em `presentation.entryKind`, dentro da
nota privada. As capas são convertidas em PNG, limitadas a 1.400 pixels no
lado maior e salvas no bucket `rpg-gm-private` no caminho legado da campanha.
O app baixa as imagens pela API autenticada do Storage. As notas anteriores
continuam nos grupos Ideias, Cenas e Bastidores. As permissões do banco e
do bucket são as já usadas pelo roteiro. As contas do teste automatizado
são exclusivas dele, sem vincular as contas usadas pelo mestre no celular.

Também ficam iniciativa e condições, contagem de fúria, concentração,
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
