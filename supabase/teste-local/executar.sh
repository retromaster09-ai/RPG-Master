#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
project_root=$PWD
mkdir -p .dart_tool
test_dir=$(mktemp -d "$project_root/.dart_tool/rpg-supabase-XXXXXXXX")

cleanup() {
  supabase --workdir "$test_dir" stop --no-backup >/dev/null 2>&1 || true
  rm -rf -- "$test_dir"
}
trap cleanup EXIT

supabase --workdir "$test_dir" init
migrations="$test_dir/supabase/migrations"
mkdir -p "$migrations"
touch "$test_dir/supabase/seed.sql"

legacy="$project_root/supabase/legado-0.16.2"
mapfile -t scripts < supabase/teste-local/ordem.txt

for i in "${!scripts[@]}"; do
  printf -v timestamp '202610010000%02d' "$((i + 1))"
  cp "$legacy/${scripts[i]}.sql" "$migrations/${timestamp}_${scripts[i]}.sql"
done
cp "$project_root"/supabase/migrations/*.sql "$migrations/"

supabase --workdir "$test_dir" start \
  -x realtime,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor \
  >"$test_dir/start.log" 2>&1 || {
    tail -40 "$test_dir/start.log" >&2
    exit 1
  }

status=$(supabase --workdir "$test_dir" status -o env)
key=$(sed -n 's/^ANON_KEY="\([^"]*\)"$/\1/p' <<<"$status")
if [[ -z $key ]]; then
  echo 'A chave pública do Supabase local não foi encontrada.' >&2
  exit 1
fi

flutter test supabase/teste-local/leitura_test.dart \
  --dart-define="SUPABASE_TEST_KEY=$key"
