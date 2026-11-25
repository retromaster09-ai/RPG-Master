# RPG Master Set

Reconstrução em Flutter do aplicativo de campanha Android 0.16.2.
Leia [RETOMAR.md](RETOMAR.md) para continuar o trabalho em outra máquina
ou em outro chat.

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
do pacote original `com.rpgmaster.rpg_master`. Antes de publicar,
configure a assinatura de distribuição e guarde a chave em local privado.

## Estado da reconstrução

A primeira implementação usa o login legado para permitir entrada com
as contas existentes. Ela lista campanhas e tenta ler o caderno, as
crônicas e as notas do mestre. Em um Supabase separado, duas contas
fictícias confirmaram que a API bloqueia a leitura e os downloads
privados para o jogador, enquanto o mestre mantém acesso ao roteiro.

Essa versão não grava no banco. O formato dos objetos em `entries` foi
confirmado com os CSVs da campanha. O leitor passou nos testes com
respostas simuladas e processou o caderno atual e suas 20 versões
exportadas. A leitura usa a função v3 para abrir os cadernos com
organização e lixeira da versão 0.16. O login com nome de usuário, a
recuperação por código, a edição colaborativa e os recursos de jogo
continuam pendentes.

Em `supabase/` ficam as consultas de inventário, as assinaturas
confirmadas e a inspeção do formato das entradas. A pasta `supabase/legado-0.16.2/` preserva
os scripts e os guias do Supabase publicados com o APK original.
Backups com registros,
arquivos do Storage, senhas e chaves ficam fora do repositório.
