# Noite da Pizza 🍕🍷

App para uma noite entre amigos, em um único `index.html`: HTML, CSS e JavaScript puro, Supabase pelo CDN e GitHub Pages, sem build, framework ou npm.

## Como usar a versão 2

1. Entre com seu nome. Quem entra passa a aparecer na lista de participantes. Use sobrenome se houver homônimos; maiúsculas e espaços extras não criam outro usuário.
2. Cadastre a pizza com nome, casal e, opcionalmente, ingredientes e foto. A imagem é convertida para JPEG de até 800 px de lado, qualidade 0.6. Quem cadastra fica automaticamente vinculado à pizza.
3. Em cada pizza, **Vincular participantes** permite marcar quem a fez, incluindo o outro integrante do casal. Nas pizzas já existentes, os vínculos precisam ser feitos manualmente. A pessoa precisa ter entrado no app para aparecer na lista.
4. Em **Meu ranking**, escolha até quatro pizzas diferentes. A primeira vale **5 pontos**, a segunda **4**, a terceira **3** e a quarta **2**. Pode salvar menos de quatro quando houver poucas pizzas. As posições se compactam ao remover uma escolha. Toque em **Salvar meu ranking** para confirmar ou trocar as escolhas; mudanças no formulário ainda não contam.
5. Uma pessoa vinculada à pizza não pode colocá-la no próprio ranking. A interface e um trigger do banco aplicam a regra. Se o vínculo for feito depois de votar, essa pizza sai do ranking da pessoa e as seguintes sobem de posição automaticamente.
6. Depois de salvar um ranking não vazio, **Revelar o resultado** mostra a soma geral dos pontos, as barras proporcionais e a líder. Empates em pontos continuam empatados, sem desempate arbitrário. O resultado é parcial enquanto a turma pode alterar suas escolhas.
7. **Excluir pizza** pede confirmação, remove a pizza dos rankings e promove as posições seguintes. Depois, tenta apagar a foto do Storage. Se só essa última etapa falhar, a exclusão da pizza continua válida e o app avisa.

O botão **Atualizar**, o Realtime e o retorno à aba sincronizam a mesa. Alterações ainda não salvas no ranking são preservadas quando possível; escolhas que ficaram inválidas são removidas com aviso. **Limpar escolhas** só retira os pontos depois de salvar o ranking vazio.

## Configurar do zero

1. Crie um projeto grátis em [Supabase](https://supabase.com/dashboard).
2. No SQL Editor, execute **supabase.sql** e depois **atualizacao-ranking.sql**, nesta ordem. O primeiro é a base v1; o segundo instala a versão atual. Não execute novamente a base v1 depois da atualização, pois ela reabre as permissões dos votos antigos.
3. Em Storage, confirme o bucket público **fotos** (criado pelo SQL), com JPEG e limite de 5 MB.
4. No início do JavaScript em `index.html`, configure `SUPABASE_URL` e `SUPABASE_ANON_KEY`, usando a URL e a chave pública `anon` do seu projeto. Nunca use `service_role`, secret key ou senha do banco.
5. Envie os arquivos ao GitHub. Em **Settings → Pages**, selecione **Deploy from a branch → main → /(root)** e salve. Não há build; o app precisa de internet.

## Atualizar a instalação existente

Aplique somente **atualizacao-ranking.sql** e depois publique o novo `index.html`. As pizzas existentes permanecem. O script adiciona `pizzas.autores`, `participantes` e `rankings`; converte eventuais votos v1 em primeira escolha (5 pontos) e bloqueia gravações anônimas na tabela legada `votos`. Não reaplique a atualização para recuperar votos apagados: ela é uma migração, não rotina de operação.

Após publicar, peça à turma para recarregar a página. Clientes antigos precisam da versão nova para votar. O script usa funções `security invoker`, RLS e um lock transacional por mesa para serializar votos, vínculos e exclusões. Os pontos são derivados das posições, sem pontuação arbitrária enviada pelo cliente.

## Acesso entre amigos

A identificação continua sendo por nome, sem senha ou login. **Qualquer visitante pode excluir pizzas, alterar vínculos e rankings pela API**; os botões estão disponíveis a todos. A confirmação de exclusão protege contra toque acidental, não é uma permissão administrativa. Trocar de nome ou desvincular um participante permite contornar a identidade combinada. O bloqueio de voto próprio vale para os vínculos atualmente registrados. Fotos e dados são públicos; o resultado oculto antes do ranking é uma regra visual. Use apenas para esta brincadeira e desative o projeto ao final se não quiser manter os dados.

## Verificação

- `node tests/ranking.cjs`: teste de lógica com DOM e Supabase simulados, sem instalar dependências. Cobre pontos, empate, escolhas inválidas, edição/salvamento, falhas, exclusão cancelada, limpeza e vínculos. Node é usado apenas para desenvolvimento, não pelo app.
- `tests/banco-ranking.sql`: verificações transacionais sob a role `anon`, com fixtures temporárias e `ROLLBACK`; aplicar somente depois da migração aprovada. Cobre voto próprio, duplicidade, limite, mudança de vínculo e exclusão.
- A migração e os testes no banco aguardam aprovação das permissões de exclusão e alteração anônima. A inspeção visual ficou pendente porque o download do navegador de testes não foi concluído.

Referências: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [upsert](https://supabase.com/docs/reference/javascript/upsert), [Realtime](https://supabase.com/docs/guides/realtime/postgres-changes).
