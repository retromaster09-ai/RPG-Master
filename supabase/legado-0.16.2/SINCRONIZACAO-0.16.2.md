# Sincronização sem bloquear a tela — 0.16.2

Instale o APK 0.16.2 usando Atualizar, sem desinstalar. Se o SQL da versão 0.16 já foi aplicado, não há outro SQL para executar.

## O que mudou

No caderno compartilhado, o envio e o recebimento pela rede não desativam mais toda a interface. Você pode rolar, navegar pelas abas, abrir anotações, editar, salvar e reorganizar os cartões enquanto aparece Sincronizando.

O texto salvo fica primeiro no aparelho. Caso você faça outra alteração durante um envio, ela permanece pendente para a próxima sincronização automática. A verificação automática continua acontecendo com a campanha aberta, aproximadamente a cada oito segundos quando a lista está disponível. Não são iniciados dois envios simultâneos para a mesma campanha.

Se uma resposta chegar enquanto o editor estiver aberto, ela não substitui o que está sendo digitado. As mudanças são reconciliadas no salvamento e na atualização da lista. Edições diferentes da mesma nota podem produzir uma versão para revisar, preservando ambas. Reinícios de campanha e exclusões definitivas continuam sendo respeitados.

## Limites

Segundo plano aqui significa que a rede funciona sem bloquear o uso do app aberto. Esta versão não cria um serviço Android que garanta envio com o aplicativo fechado ou suspenso pelo sistema. Ao voltar ao app, ele tenta retomar a sincronização. Confira Sincronizado com a campanha antes de depender do conteúdo em outro aparelho.

A saída da campanha ainda aguarda uma sincronização já iniciada, para não abrir duas sessões locais sobre o mesmo cache. Isso não impede editar, organizar ou trocar de aba dentro da campanha. O roteiro privado mantém seu salvamento online com confirmação. Operações especiais, como transferência e restauração de backup, preservam seus próprios bloqueios para evitar mudanças no conjunto de dados durante a operação. Falhas de gravação local continuam sinalizadas e devem ser resolvidas antes de sair do caderno.

Para testar, abra a mesma campanha em dois aparelhos, faça uma alteração durante o indicador Sincronizando e confirme depois que ela aparece no outro. Se ficar Envio pendente, use o botão de informações da sincronização para consultar a mensagem disponível. Não desinstale o aplicativo para tentar corrigir um envio pendente.

Validação: 123 testes passaram, incluindo salvamento durante rede lenta, resposta atrasada ao envio, rascunho anterior à resposta, falha de rede, retomada de cache, nova tentativa após erro em disco e reset durante sincronização. Análise estática sem problemas. Não foi necessário alterar o banco para esta correção.
