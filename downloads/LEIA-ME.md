# RPG Master — versões de teste Android

## 0.11.1 — aventureiros e dragão

Nova ilustração anime original no cabeçalho de Suas campanhas: guerreiro, maga, paladino e clériga enfrentando um dragão. Prévia: [campanhas](previas/campanhas-0.11.1.png).
Instale RPG-Master-prototipo-0.11.1-android64.apk como atualização, sem desinstalar. Não exige SQL adicional; contas, notas e capas continuam preservadas.

## 0.11.0 — identidade RPG Master e capas de campanha

- Novo emblema de livro e dado, ícone Android e entrada ilustrada com arte original de fantasia.
- Cartões grandes para campanhas, com papel de mestre/jogador e imagem de capa compartilhada.
- Criador escolhe a imagem, ajusta zoom/foco ou mostra a imagem inteira; prévia antes de salvar e opção de remover a capa.
- Jogadores podem ver a capa, mas só o criador pode trocá-la. Arquivos permanecem privados aos membros da campanha.
- Atualização de campanhas no topo e verificação de novidades na lista a cada 20 segundos em primeiro plano.
- Demonstração, caderno local, contas e sincronização continuam preservados. A recuperação por e-mail permanece em preparação, sem depender do Gmail para esta atualização.

Aplique somente [capas-das-campanhas.sql](configuracao/capas-das-campanhas.sql) no projeto para salvar capas. Veja [as instruções](configuracao/CAPAS-E-VISUAL.md). O novo visual funciona antes de aplicar o SQL.
Instale como atualização, sem desinstalar. Android 7+ ARM64. Recurso de ícone Windows preparado; instalador Windows ainda pendente.
84 testes passaram, incluindo enquadramento, cancelamento, falhas, upload repetido e layouts em celular/PC com fontes ampliadas. As regras foram testadas num PostgreSQL descartável. O envio real de capa deve ser conferido no aplicativo após aplicar o SQL.
Prévias: [entrada](previas/entrada-0.11.png) e [campanhas](previas/campanhas-0.11.png).

## 0.10.0 — caderno vazio, demonstração e recuperação preparada

- Instalações novas começam com o caderno pessoal vazio, sem carregar exemplos automaticamente.
- Explorar demonstração abre exemplos temporários em memória, separados do caderno pessoal e das campanhas. Alterações da demonstração são descartadas ao sair.
- Registros já salvos no aparelho são preservados, inclusive exemplos que foram editados. Não há remoção automática de notas.
- Botão Esqueci minha senha com etapas de código por e-mail e nova senha. O envio fica **em preparação** até configurar o remetente, o modelo e a ativação no servidor.
- A ativação posterior do e-mail é reconhecida pelo aplicativo sem reinstalar nos celulares. Consulte [o guia de recuperação](configuracao/RECUPERAR-SENHA.md) antes de executar qualquer SQL de ativação.
- A sincronização e as campanhas existentes continuam com a mesma estrutura.

Para os ajustes do caderno basta instalar como atualização, sem desinstalar. Android 7+ ARM64, mesma assinatura da versão 0.9.
74 testes passaram, incluindo preservação de dados, demonstração isolada, código expirado, confirmação de senha e chamadas da biblioteca oficial com rede simulada. Os testes não enviaram e-mails reais; SMTP ainda precisa ser escolhido/configurado pelo responsável. As permissões da ativação foram testadas num PostgreSQL descartável.

## Correção de sincronização — imagens antes do texto

A validação do banco da versão 0.9 rejeitava `afterParagraph = -1`, posição usada pelo editor para **Antes do parágrafo 1**. A rejeição impedia o salvamento do caderno inteiro e mantinha a indicação de envio pendente.

Aplique [corrigir-imagens-antes-do-texto.sql](configuracao/corrigir-imagens-antes-do-texto.sql) no SQL Editor do projeto, numa nova consulta, e clique em Run. Depois volte à lista da campanha e toque em sincronizar. O aplicativo 0.9 usa a nova regra automaticamente; a transferência original e a fila local são mantidas.

A correção altera somente a função de validação. Não muda permissões nem regrava notas ou imagens. O SQL completo de instalação também foi atualizado. Regressão reproduzida antes do ajuste e aprovada após o ajuste, incluindo salvamento pela RPC com usuário autenticado, rejeição de posições menores que -1 e testes de isolamento/permissões.

## 0.9.0 — notas compartilhadas e transferência

- Notas e imagens compartilhadas entre os membros da campanha, com gravação local antes do envio.
- Sincronização automática nas listas em primeiro plano, a cada 8 segundos, e botão manual no rodapé. Volte à lista depois de ler ou editar uma nota para enviar alterações.
- Prévia de transferência do caderno antigo e das notas locais da versão 0.8, mantendo o original. Cópias idênticas são ignoradas.
- Edições simultâneas em notas diferentes são juntadas. Na mesma nota, duas versões são preservadas para revisão.
- Imagens num bucket privado por campanha; sem links públicos. Atualizações sem mudanças retornam apenas a revisão para reduzir tráfego.
- Fila local persistente e reenvio seguro, inclusive após perda da confirmação do servidor.

**Antes de usar:** aplique o SQL adicional [compartilhar-notas.sql](configuracao/compartilhar-notas.sql) no mesmo projeto Supabase. Veja o [passo a passo](configuracao/COMPARTILHAR-NOTAS.md).
Instale a atualização sem desinstalar a versão anterior. Android 7+ ARM64, mesma assinatura.
63 testes passaram. As regras do banco foram testadas num PostgreSQL 17 descartável com auth/storage simulados; o serviço real entre celulares precisa ser conferido após aplicar o SQL.
A área privada do mestre continua desativada: todas as notas desta atualização são compartilhadas com os membros da campanha. Logo, capas e instalador Windows ficam para etapas futuras.

## 0.8.0 — contas e campanhas (configuração necessária)

- Login e cadastro reais com e-mail/senha no projeto Supabase, com sessão persistente.
- Lista de campanhas, criação como mestre e entrada como jogador por convites de uso único (7 dias).
- Caderno anterior acessível sem login; não é movido nem enviado automaticamente.
- Notas de campanhas novas são locais, separadas por conta e campanha. Ainda não há sincronização de notas ou área secreta do mestre ativa.
- Configure primeiro o projeto conforme [estas instruções](configuracao/LEIA-ME.md), com o SQL testado e as opções de autenticação.

Instale como atualização, sem desinstalar. Android 7+ ARM64, assinatura compatível com 0.7.
48 testes passaram e as regras SQL foram testadas num PostgreSQL 17 descartável.
O login remoto ainda depende da configuração do projeto e precisa de teste em aparelho real.
O domínio do Supabase está bloqueado pela política de rede do ambiente de desenvolvimento;
essa limitação não valida nem invalida a chave pública fornecida.

## 0.7.0

- Temas gerais Baróvia, Bosque arcano e Horizonte, com cabeçalhos ilustrados, molduras,
  tipografia, cores e ícones harmonizados.
- Escolha pelo ícone de paleta no topo ou por Temas do aplicativo no menu.
- Preferência salva por aparelho, separada das notas e do estilo de cada diário.
- Componentes adaptáveis a celular e PC; instalador Windows ainda não disponível.
- Conteúdo, fotos, missões e estilos individuais preservados.

42 testes passaram, incluindo escolha persistente do tema, layout em celular e PC, backups e exportações.
Instale como atualização, sem desinstalar. Android 7+ ARM64.
Dados continuam locais, sem login ou sincronização entre jogadores.

## 0.6.0

- Enciclopédia separada em Personagens, Lugares e Itens, com busca na categoria escolhida.
- Missões com etapas, detalhes/resultados, ordenação, prioridade e progresso.
- Filtros Todas, Abertas, Em andamento e Concluídas.
- Concluir a última etapa oferece concluir a missão; reabrir preserva resultados e histórico.
- Missões antigas mantidas sem criar etapas automaticamente.
- Backups novos usam formato 2 e preservam as etapas. Backups antigos continuam aceitos;
  restaure backups novos na versão 0.6 ou posterior.

39 testes passaram, incluindo migração, etapas, filtros, busca por categoria, backups e exportações.
Instale como atualização, sem desinstalar. Android 7+ ARM64.
Em Missões, abra um registro → Editar → Adicionar etapa, ou toque em Nova missão.
Dados continuam locais; não há login ou sincronização entre jogadores.

## 0.5.0

- Ajustar imagem com configurações independentes para miniatura e página: formato, imagem inteira
  ou preencher, zoom, posição e moldura. As imagens originais do aplicativo não são recortadas.
- Formatos retângulo, arredondado, quadrado arredondado e círculo, com prévia.
- Formatação de trechos: negrito, itálico, cores, destaque, títulos, listas e limpar formatação.
- Formatação preservada na leitura e nas exportações PNG/PDF, com variantes de fonte incluídas offline.
- Criar backup completo em ZIP com textos, histórico, fotos e personalizações.
- Restaurar o ZIP mantém os registros atuais, ignora cópias idênticas e conserva versões diferentes.
- Dados da versão anterior são lidos sem perder o conteúdo.

APK otimizado (22,2 MB), Android 7+ ARM64, assinatura compatível com 0.4.
Instale como atualização, sem desinstalar. Para Victoria: Ajustar imagem → Miniatura na lista →
Arredondado ou Quadrado arredondado, com Preencher moldura ativado.

29 testes passaram, incluindo backup entre diretórios, falhas de gravação, formatação por seleção,
fontes de negrito/itálico no PDF, PNG e personalização das imagens. O picker e o compartilhamento
de ZIP ainda precisam ser conferidos em aparelho real. Dados continuam locais; não há login ou sincronização.


## 0.4.0

- Imagens antes do primeiro parágrafo, seleção múltipla, legendas e ordenação.
- Enquadramento inteiro de fotos, retratos e miniaturas, sem recorte automático.
- Pergaminho envelhecido com fonte cursiva Courgette; Baróvia com Crimson Text e moldura vinho;
  novo Futurista com grade ciano e Share Tech Mono. Fontes livres incluídas offline.
- Compartilhar a folha completa da sessão como PNG pelo botão ao lado do lápis.
- Exportar todos os resumos em PDF pelo botão na lista de Sessões, em ordem de data, com imagens.
- Folhas muito longas indicam o uso de PDF em vez de cortar o texto.

APK otimizado (20,4 MB), Android 7+ ARM64, assinatura compatível com 0.3.
Instale como atualização, sem desinstalar. As fotos existentes não precisam ser recolocadas.

21 testes distintos passaram, incluindo migração, posições de imagens, captura longa e PDF
paginado (33 páginas no teste, com última linha verificada). O compartilhador do sistema e o envio
por WhatsApp precisam de conferência em aparelho real. O aplicativo não envia mensagens sozinho.
As anotações continuam locais; login, sincronização e instalador Windows ainda pendentes.


## 0.3.0

- Retratos escolhidos pelo usuário, miniaturas nas listas e páginas completas dos registros.
- Imagens no diário com legenda e posição após um parágrafo.
- Datas em destaque dentro dos cartões de sessões.
- Investigações confirmadas passam para Descobertas; hipóteses refutadas ficam identificadas em Investigações.
- Resposta obrigatória ao concluir; cancelar não altera o registro; reabrir mantém o histórico.
- Visual em vinho, controles A−/A+ agrupados e indicador de salvamento sem duplicação.
- Leitura dos dados da versão 0.2, preservando as anotações existentes.

APK otimizado (18,5 MB), Android 7+ ARM64, com assinatura de teste compatível com
0.2. Instale como atualização, sem desinstalar. As imagens e anotações ficam
somente no aparelho. Não há login, sincronização nem proteção dos segredos do mestre.

15 testes passaram, análise estática sem problemas, APK compilado e assinatura
verificada. O seletor nativo de imagens ainda precisa ser conferido em aparelho real.
Login, seleção de campanhas, ícones personalizados e instalador Windows seguem pendentes.


## 0.2.0

- Salvamento local de anotações, respostas, conclusões e histórico.
- Resumos de sessões com uma ou várias datas editáveis.
- Página de diário com papel envelhecido, tema de Baróvia e leitura simples.
- Ajuste do tamanho do texto e indicação de falhas ao salvar.

Android 7 ou superior, processador ARM64. Assinatura de desenvolvimento compatível
com a versão 0.1.0: instalar como atualização, sem desinstalar.

Aguarde a indicação “Salvo neste aparelho” antes de fechar. Os arquivos são locais:
não existe sincronização entre jogadores nem recuperação em outro aparelho.
Não há autenticação ou proteção da área do mestre. Não inserir segredos.
Imagens de personagens, personalização dos menus e instalador Windows ainda pendentes.

Nove testes automatizados passaram; APK compilado e assinatura verificada.
Ainda não foi instalado e testado em aparelho físico ou emulador.

## 0.1.0

Versão anterior: alterações somente em memória, perdidas ao fechar.

As versões contêm exemplos do caderno A Maldição de Strahd cuja disponibilização
foi autorizada pelo mestre. Não são versões finais para substituir o caderno.
