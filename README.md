# RPG Master Set

Base de recuperação do aplicativo Android 0.16.2. A pasta `assets/` reúne a
arte de interface, as fontes e os arquivos de licença e atribuição
extraídos do APK enviado pelo mestre. O aplicativo Flutter ainda precisa
ser recuperado a partir do projeto original ou reconstruído.

O aplicativo 0.16.2 tem o identificador Android
`com.rpgmaster.rpg_master` e foi assinado com uma chave de depuração.
Arquive o APK original e, se disponível, guarde a chave de assinatura em
um local privado. Uma reconstrução sem essa chave pode ser instalada
separadamente com outro identificador para testar a migração.

## Supabase

Os CSVs da campanha podem ficar fora do repositório, em uma cópia privada.
`supabase/inventario.sql` lista as colunas, assinaturas de funções e nomes
de políticas do projeto existente. Execute no SQL Editor para documentar
o contrato do app antes de alterar o banco. Importar novamente os CSVs,
por si só, não recria as funções, permissões ou contas.

A primeira versão reconstruída deve provar que consegue abrir a campanha,
editar o caderno e separar as notas e imagens privadas no servidor.
Ao adicionar login por nome de usuário, preserve os IDs de conta usados
pelas campanhas. A recuperação de senha deve usar um código expirável,
de uso único, aprovado pelo mestre autorizado.

Versione o código, os recursos e as futuras migrações em um repositório
privado sob controle do mestre. Guarde cópias dos dados e dos arquivos do
Storage em outro local privado e teste a restauração em ambiente separado
antes de mudar o banco de produção.
