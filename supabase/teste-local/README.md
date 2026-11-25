# Teste local de leitura e privacidade

Execute a partir da raiz do projeto com Flutter 3.50.1, Supabase CLI
2.75.0 e Docker em execução. O ambiente precisa das portas locais padrão
do Supabase disponíveis e espaço em disco para as imagens Docker.

```sh
bash supabase/teste-local/executar.sh
```

O script sobe um Supabase descartável, carrega os scripts originais na
ordem histórica, aplica as migrações da reconstrução e executa um
teste de integração com duas contas
fictícias. A configuração de recuperação por e-mail fica fora deste
teste. O banco local é descartado ao final.

O teste usa o mesmo repositório Dart que o app para consultar campanhas,
caderno, crônicas e roteiro. Também verifica as regras do PostgREST e do
Storage chamando as APIs com a conta de jogador. Os dados de produção,
as contas existentes e os backups da mesa ficam fora desse processo.

## Verificação pelo PostgreSQL

Para verificar as políticas sem os serviços do Supabase, use um
PostgreSQL descartável e vazio, com permissão para criar roles e
schemas. A partir da raiz do projeto:

```sh
(
  set -e
  psql -v ON_ERROR_STOP=1 -f supabase/teste-local/bootstrap-postgres.sql
  while IFS= read -r script; do
    psql -v ON_ERROR_STOP=1 -f "supabase/legado-0.16.2/$script.sql"
  done < supabase/teste-local/ordem.txt
  psql -v ON_ERROR_STOP=1 -f supabase/teste-local/permissoes.sql
)
```

Aponte o `psql` para o banco descartável antes de executar. O bootstrap
simula apenas os objetos de Auth e Storage usados pelas políticas.
Esse teste verifica as funções SQL, as regras de leitura de linhas e
o catálogo de objetos do Storage. O teste das APIs confirma também
o login, a consulta pelo SDK Flutter e a transferência dos arquivos.

## Executar em um projeto Supabase de teste hospedado

Aplique os scripts de `ordem.txt` e as migrações em
`supabase/migrations/` em um projeto separado para testes. Crie duas
contas fictícias confirmadas pelo painel de Auth. Guarde
um JSON em uma pasta privada com os seguintes campos:

- `SUPABASE_TEST_URL` e `SUPABASE_TEST_PROJECT_REF`, com a URL HTTPS e a
  referência do mesmo projeto de teste.
- `SUPABASE_TEST_KEY`, com a chave pública do projeto.
- `SUPABASE_TEST_GM_EMAIL` e `SUPABASE_TEST_GM_PASSWORD`.
- `SUPABASE_TEST_PLAYER_EMAIL` e `SUPABASE_TEST_PLAYER_PASSWORD`.

```sh
flutter test supabase/teste-local/leitura_test.dart --dart-define-from-file=/caminho/privado/contas.json
```

Cada execução cria uma campanha e arquivos fictícios no projeto de
teste. O teste local continua criando suas próprias contas no banco
descartável. Guarde o JSON com as credenciais fora do Git.
