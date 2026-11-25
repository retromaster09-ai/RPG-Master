# RPG Master 0.11 — identidade visual e capas

A entrada ganhou uma ilustração original, emblema com livro e dado, novo ícone e cartões ilustrados. Os temas existentes continuam disponíveis. A recuperação por e-mail permanece em preparação; esta atualização não depende da configuração do Gmail.

## Ativar as capas

1. No mesmo projeto Supabase que já usa para as campanhas, abra uma **nova consulta** no SQL Editor.
2. Copie TODO o conteúdo de [capas-das-campanhas.sql](capas-das-campanhas.sql), cole e clique em **Run**. Aguarde `Success. No rows returned`.
3. Instale a versão 0.11 sobre a versão atual, sem desinstalar. Entre com a mesma conta.
4. Na tela **Suas campanhas**, localize o cartão e toque em **Adicionar capa**. O botão aparece apenas para o criador da campanha.
5. Escolha uma imagem do aparelho. Ajuste o zoom/foco com **Preencher a capa**, ou desative essa opção para mostrar a imagem inteira.
6. Confira a prévia e toque em **Salvar capa**. Cancelar não muda a capa nem envia a imagem selecionada para o servidor.
7. Os membros veem a mesma capa e enquadramento. A lista verifica novidades a cada 20 segundos em primeiro plano; o botão **Atualizar campanhas** permite conferir imediatamente. A imagem fica no armazenamento privado da campanha, sem URL pública.
8. Para mudar depois, use **Editar capa**. Remover uma capa muda o cartão para a ilustração padrão, mantendo arquivos e anotações existentes. A troca exige conexão; se não houver confirmação, atualize a lista para conferir antes de tentar novamente.

O SQL adiciona campos de capa e uma operação protegida por permissões; não altera notas, senhas ou membros e não ativa recuperação de senha. A função de salvamento permite somente o criador e rejeita edições desatualizadas de outro aparelho. As imagens usam o bucket privado de notas que já existe.

Se ainda não executar o SQL, o novo visual continua funcionando e as campanhas antigas continuam legíveis; salvar capas dependerá dessa preparação. Todos os jogadores só precisam do APK mais recente e da própria conta/convite — o SQL é executado uma vez pelo responsável pelo projeto.

## Marca e compatibilidade

O emblema e a ilustração de entrada foram gerados para este projeto, sem usar retratos prontos de Strahd. Você pode escolher sua própria imagem para a capa da campanha. O ícone Android foi substituído e o recurso de ícone Windows foi preparado; o instalador Windows continua pendente. Os layouts foram conferidos em celular e PC, incluindo texto ampliado.

As regras foram testadas num PostgreSQL descartável com auth/storage simulados. O domínio do Supabase continua bloqueado no ambiente de desenvolvimento; o envio real da capa deve ser conferido após aplicar o SQL, pelo aplicativo instalado.
