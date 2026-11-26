# Funções da versão 0.16.2 e da reconstrução

Levantamento feito em 25/11/2026. A referência é o APK Android `0.16.2`,
o [histórico de versões](downloads/LEIA-ME.md) e os
[guias originais](supabase/legado-0.16.2/). O estado atual foi conferido no
código do `0.17.0-dev.4`. Os itens abaixo registram as diferenças confirmadas
e servem como roteiro para retomar o trabalho.

O `0.17.0-dev.5` completa a primeira etapa da ordem proposta. Para o uso
diário, a versão `0.17.0-dev.6` recupera a cópia local, os rascunhos e a
fila de envio dos textos compartilhados. A versão `0.17.0-dev.7` recupera as
capas de campanha e a busca no caderno e nas crônicas, com filtro de categoria
no caderno. A versão `0.17.0-dev.8` recupera datas múltiplas e a ordem
cronológica nas crônicas. A versão `0.17.0-dev.9` recupera mover e restaurar
na lixeira compartilhada e na privada. A versão `0.17.0-dev.10` recupera
organização manual e duplicação. Lixeira offline e exclusão definitiva
continuam pendentes.
O `0.17.0-dev.11` recupera as etapas, os estados e o progresso das missões.
O `0.17.0-dev.12` deixa as caixas e as etapas acionáveis nos cartões e
permite arrastar os cartões na própria lista. O `0.17.0-dev.13` abre o Caderno em um índice e
separa missões ativas das concluídas. A referência para importar Word
e PDF está em [MODELO_CADERNO.md](MODELO_CADERNO.md). O `0.17.0-dev.14`
adiciona capas compartilhadas, índice ilustrado e páginas de leitura.
O `0.17.0-dev.15` recupera estilos de página, formatação de trechos,
imagens no texto e enquadramento dos cartões no Caderno e nas Crônicas.
O `0.17.0-dev.16` recupera tamanho, posicionamento e remoção de fundo
por cor nas imagens do texto, com restauração do original.
O `0.17.0-dev.17` restaura a importação de Word com prévia e confirmação.

| Área | Na versão 0.16.2 | No 0.17.0-dev.4 |
| --- | --- | --- |
| Conta | Cadastro e login por e-mail. Recuperação por e-mail em preparação. | Login por usuário, vínculo de conta antiga, recuperação por código do mestre e código de reserva. Falta o cadastro de novas contas na interface. |
| Campanhas | Criação de mesa, convite individual, entrada por código compartilhado e lista de participantes. Só o criador define ou desativa o código. | Lista e abertura de campanhas existentes, com papel por campanha. Faltam as telas de criação, entrada por código ou convite e gestão de participantes. As funções legadas estão nos scripts. |
| Caderno | Busca e filtros, enciclopédia de personagens/lugares/itens, investigações e descobertas, missões com etapas, prioridade e progresso. | Índice com seções e busca por seção, criação e edição de registros com resposta e nível de confiança, missões ativas e concluídas. A enciclopédia ainda pode ganhar páginas mais completas. |
| Crônicas | Datas editáveis, ordem por data ou manual, imagens e exportação em PNG/PDF. | Aba compartilhada com criação e edição de texto. Faltam controles de datas, ordenação, imagens no texto e exportação. |
| Sincronização compartilhada | Cópia local, fila persistente, sinalização de envio pendente, reenvio após reconexão e atualização periódica da lista aberta. | Salvamento online com revisão, combinação de mudanças em campos diferentes e rascunho aberto quando há conflito. Faltam a cópia local, a fila persistente e a atualização periódica. |
| Organização | Ordenação por arrasto ou setas, duplicação, lixeira e restauração. Exclusão definitiva compartilhada reservada ao criador. | As listas ocultam notas na lixeira, mas ainda faltam os controles de ordenação, duplicação, lixeira e restauração. |
| Roteiro do mestre | Ideias, Cenas, Bastidores e Próxima sessão, com busca, etiquetas, estado, condições e música. Imagens entre parágrafos, estilos e formatação. | Ideias, Cenas e Bastidores, edição por revisão, leitura separada e uma capa privada. Personagens, Reinos e Organizações ganharam grupos próprios. Faltam os campos de preparação e as opções avançadas de leitura e edição. |
| Proteção no aparelho | Senha para abrir ou retomar o roteiro e proteção de captura no Android, além das permissões no servidor. | A sessão permanece aberta e o servidor verifica o papel em cada campanha. A proteção de captura do roteiro ainda está pendente. Preservar a experiência aprovada de abrir a área Mestre sem pedir senha a cada acesso. |
| Capas e apresentação | Capas de campanha e miniaturas, estilos de página, texto formatado, enquadramento de imagens, zoom e remoção de fundo por cor. | Capa simples nas páginas privadas. Faltam as capas de campanha e os controles de formatação e imagem do app antigo. |
| Portabilidade | Caderno pessoal no aparelho, cópia para o caderno compartilhado, backup/restauração ZIP, importação DOCX, exportação PNG/PDF e reset confirmado da campanha. | Existe um procedimento de backup fora do app. Faltam as ferramentas equivalentes na interface. Qualquer restauração compartilhada deve preservar a separação do roteiro do mestre. |

## Ordem proposta

1. **Montar uma mesa inteira pelo app.** Cadastrar uma conta nova, criar uma
   campanha, gerar um código, entrar com uma conta convidada e consultar os
   participantes como mestre. Validar os dois papéis sem preparação manual
   de campanha no painel. Implementado no `0.17.0-dev.5`.
2. **Recuperar o uso diário do caderno.** Priorizar segurança do rascunho e
   sincronização após reconexão, busca e filtros, datas de crônicas,
   organização e lixeira. Usar duas contas exclusivas dos testes automáticos.
3. **Recuperar portabilidade e edição avançada.** Priorizar backup e
   restauração antes de reset, seguido de importação, exportação, etapas de
   missões, formatação e controles de imagem. Manter funções específicas na
   tela onde são usadas para preservar a organização da reconstrução.

Iniciativa, condições de combate, fichas e VTT continuam no roteiro de
funcionalidades novas. A recuperação de senha por código continua sendo o
fluxo escolhido para o novo app.
