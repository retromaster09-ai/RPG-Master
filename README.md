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
crônicas e as notas do mestre. A leitura do roteiro só é solicitada
pelo aplicativo para o criador da campanha. O Supabase ainda precisa
ser testado com duas contas reais em ambiente de teste para confirmar
que bloqueia a leitura e as imagens para jogadores.

Essa versão não grava no banco. O formato dos objetos dentro de
`entries` ainda precisa ser confirmado no Supabase. O leitor foi
testado com respostas simuladas. O login com nome de usuário, a
recuperação por código, a edição colaborativa e os recursos de jogo
continuam pendentes.

Em `supabase/` ficam as consultas de inventário, as assinaturas
confirmadas e a inspeção do formato das entradas. Backups com registros,
arquivos do Storage, senhas e chaves ficam fora do repositório.
