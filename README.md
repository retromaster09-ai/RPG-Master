# RPG Master Set

Reconstrução em Flutter do aplicativo de campanha Android 0.16.2.
Leia [RETOMAR.md](RETOMAR.md) para continuar o trabalho em outra máquina
ou em outro chat. A estrutura do caderno e a referência para o importador
estão em [MODELO_CADERNO.md](MODELO_CADERNO.md).

## Compilar e executar

Use Flutter **3.50.1**, que inclui o Dart 3.14.0. Para Android, configure
também o Android SDK e aceite suas licenças com `flutter doctor
--android-licenses`. Na pasta do projeto, execute:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define=SUPABASE_URL=https://SEU_PROJETO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_SUA_CHAVE
```

Preencha a URL e a chave *publishable* do projeto de teste em **Connect**
no painel Supabase. Para testar em um aparelho Android conectado, omita
`-d chrome` ou use o identificador de `flutter devices`. Para gerar um
APK de teste, troque `flutter run -d chrome` por
`flutter build apk --debug`. Chaves administrativas devem ficar no servidor.

A versão de desenvolvimento usa o identificador Android
`com.rpgmaster.recovery.rpg_master_set`, para poder ser instalada ao lado
do pacote original `com.rpgmaster.rpg_master`. No Android, procure
**RPG Master Set Teste**. O APK ARM64 de teste é gerado com
`flutter build apk --release --target-platform android-arm64 --split-per-abi`
e os mesmos parâmetros `--dart-define` do projeto Supabase de teste.
O APK usa assinatura de teste. Antes de publicar uma versão de
distribuição, configure sua assinatura e guarde a chave em local privado.

## Pacote de teste para PC

No Windows de 64 bits, extraia o ZIP inteiro e abra
**Abrir RPG Master Set.exe**. O executável abre a edição web no navegador.
O lançador mostra a versão, abre um endereço diferente para cada edição e
usa a mesma origem local para manter sessão e rascunhos. A janela precisa
ficar aberta enquanto o app estiver em uso. Ao atualizar, feche a janela
do lançador anterior antes de abrir a nova. A tela **Suas campanhas**
mostra o número da versão.

Para refazer o pacote, execute `tools/pc/build-web.sh` na raiz do projeto
com os mesmos parâmetros `--dart-define` do APK. Copie o conteúdo de
`build/web` para a pasta `web` do pacote. Compile `tools/pc/main.go` com
o Go para Windows amd64 e coloque o executável ao lado dessa pasta.

## Montar uma mesa no app

Uma pessoa nova entra por **Criar uma conta**, com nome de usuário e senha.
Em **Suas campanhas**, ela pode criar uma mesa ou entrar com um código ou
convite recebido. Na mesa, **Acesso e participantes** fica disponível ao
criador. Ali ele define ou troca o código compartilhado, gera convites
individuais e consulta a lista de pessoas. O código compartilhado só aparece
para copiar depois de ser definido. O convite individual vale sete dias.

O papel é definido por campanha. O criador vê **Mestre** e **Acesso e
participantes**. Quem entra por código ou convite recebe o papel de jogador.
As duas áreas do mestre usam a sessão atual e as permissões do servidor.

Na lista **Suas campanhas**, o mestre pode tocar no ícone de imagem
no cartão para escolher a capa e ajustar o enquadramento. A imagem
salva é compartilhada com os membros da campanha pelo Storage autenticado.
O cartão usa a ilustração original do app quando a campanha está sem capa.

## Estado da reconstrução

A tela de entrada usa nome de usuário e senha. Para vincular uma conta
existente, use **Primeiro acesso com a conta antiga**, entre com o e-mail
de sempre e escolha o nome na tela **Minha conta**. As campanhas e as
permissões continuam associadas à conta original. O app lista campanhas
e lê o caderno, as crônicas e as notas do mestre. Em um Supabase separado, duas contas
fictícias confirmaram que a API bloqueia a leitura e os downloads
privados para o jogador, enquanto o mestre mantém acesso ao roteiro.

Mestre e jogadores podem criar e editar registros e crônicas. O salvamento
usa a revisão e a época da campanha. Alterações concorrentes em registros
ou campos diferentes são combinadas. Se as duas versões mudarem o mesmo
campo, o editor mantém o rascunho aberto e mostra a versão salva para
revisão. A formatação de trechos intactos é preservada no salvamento.
Para editar o caderno, o projeto Supabase precisa da migração de
sincronização em `supabase/migrations/`, já aplicada no projeto de teste.

Quando você já entrou na conta e abriu a campanha com internet, o app pode
reabrir a última cópia do caderno e das crônicas sem conexão. O editor guarda
rascunhos locais enquanto você digita. **Salvar** coloca a edição em
**Aguardando envio**. O app verifica o servidor enquanto a campanha está
aberta e ao voltar para ela. Se outra pessoa alterou o mesmo campo, a edição
fica em **Revisar edição** com o texto preservado. A aba Mestre permanece online.
As buscas do **Caderno** e das **Crônicas** encontram palavras com ou sem
acentos no título, no texto e nas respostas, inclusive na cópia local.
O **Caderno** também pode ser filtrado por categoria.

Em **Crônicas**, use **Adicionar data** para registrar uma ou várias datas
da sessão. Toque numa data para editar e use o **×** para removê-la do
relato. A lista usa a primeira data de cada crônica para ordenar e exibe
primeiro as sessões mais recentes. O botão de ordenação inverte a ordem.
Crônicas sem data aparecem no fim. As datas também entram nos rascunhos
locais e seguem as regras de revisão da sincronização.

No **Caderno** ou nas **Crônicas**, abra **Opções do registro → Mover para
a lixeira**. O ícone **Lixeira** no topo abre a lista e permite restaurar.
Na aba **Mestre**, a página privada tem seu próprio botão para mover, e o
topo da aba abre a lixeira privada. Mover e restaurar precisam de conexão.

Use **Duplicar** no menu de um registro, crônica ou nota privada para
criar uma cópia. Use **Organizar cartões** para arrastar os itens e
salvar a ordem. No Caderno e nas Crônicas, a ordem vale para a aba inteira.
Na área Mestre, cada grupo é organizado separadamente. As Crônicas também
podem voltar à ordem por data pelo botão de ordenação.

Para acompanhar uma **Missão**, escolha essa categoria no editor do Caderno.
Defina prioridade e estado, adicione etapas e registre detalhes ou resultados.
Ao marcar a última etapa, o editor oferece **Concluir missão**. Alterar o
estado de uma missão concluída preserva suas etapas. O cartão mostra o progresso.
Filtre o Caderno por **Missão** para escolher o estado e use a busca para
encontrar títulos e detalhes das etapas. O progresso segue a fila de rascunhos
e sincronização do Caderno.

Na aba **Mestre**, o criador da campanha pode criar e editar notas
privadas em **Ideias**, **Cenas** e **Bastidores**. O app usa a revisão
de cada nota para impedir que duas edições se sobrescrevam. O título,
o texto e a seção são editáveis. As funções legadas do Supabase
autorizam a leitura e a gravação, sem exigir senha extra dentro do app.
Em **Nova nota ou página**, escolha **Personagem**, **Reino** ou
**Organização** para incluir uma página no grupo correspondente. É possível
escolher uma capa PNG ou JPEG no dispositivo. A capa fica no bucket privado
da campanha e aparece ao abrir a página.

A recuperação de senha pelo mestre e pelo código de reserva está ativa
no Supabase de teste. Os passos de configuração, implantação e teste
estão em [Recuperação de conta](supabase/CONTAS.md). Os recursos de jogo
continuam pendentes.

Em `supabase/` ficam as consultas de inventário, as assinaturas
confirmadas e a inspeção do formato das entradas. A pasta `supabase/legado-0.16.2/` preserva
os scripts e os guias do Supabase publicados com o APK original.
Backups com registros,
arquivos do Storage, senhas e chaves ficam fora do repositório.
O procedimento de cópia e conferência está em
[Backup e restauração](supabase/BACKUP.md).
