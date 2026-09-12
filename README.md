# Noite da Pizza 🍷

App de uma noite entre amigos: cadastro com foto, um voto por nome, troca de voto e ranking com empate. HTML + CSS + JavaScript em `index.html`, sem build, npm ou framework. Precisa de internet; estar no mesmo Wi-Fi não substitui o acesso ao Supabase e ao CDN.

## Colocar no ar

1. **Supabase:** crie um projeto grátis em [supabase.com](https://supabase.com/dashboard). Guarde a senha do banco; ela não vai no HTML.
2. **Banco:** abra **SQL Editor → New query**, cole todo o arquivo `supabase.sql` e execute **Run**. O script cria tabelas, permissões anônimas, bucket e Realtime. Pode ser executado novamente.
3. **Fotos:** em **Storage**, confirme o bucket `fotos` como **Public**. O SQL já o cria. Se optar por criar pelo painel antes de rodar o SQL, use exatamente `fotos`, marque público, limite de 5 MB e MIME `image/jpeg`. Execute o SQL mesmo assim para criar a política de upload anônimo. O app converte a foto para JPEG, lado máximo de 800 px e qualidade 0.6. Fotos opcionais; formato não suportado pelo navegador pede outra imagem.
4. **Chaves:** no projeto, copie **Project URL** e a chave pública **anon** (em Settings → API / API Keys, seção de chaves legadas, ou no diálogo Connect). No início do script próprio de `index.html`, substitua:
   ```js
   const SUPABASE_URL = 'https://SEU-PROJETO.supabase.co';
   const SUPABASE_ANON_KEY = 'SUA-CHAVE-ANON';
   ```
   A anon key é pública e pode ficar no HTML. **Nunca cole `service_role`, chave secreta ou senha do banco.**
5. **GitHub Pages:** crie um repositório público novo chamado `noite-da-pizza`. Envie `index.html`, `supabase.sql` e `README.md` para a raiz da branch `main`. Em **Settings → Pages → Build and deployment**, selecione **Deploy from a branch**, branch **main**, pasta **/(root)** e salve. Abra a URL exibida pelo GitHub, normalmente `https://SEU-USUARIO.github.io/noite-da-pizza/`. Não há comando de build.
6. **Teste com a turma:** abra em dois celulares, entre com nomes diferentes, cadastre duas pizzas (uma com foto), vote e troque de voto. O resultado só aparece após votar. Faça um voto em cada pizza para conferir o empate. Recarregue para verificar a recuperação do nome e do voto. O botão Atualizar funciona mesmo sem Realtime.

## Como usar

- Cada pessoa usa o próprio nome; homônimos devem usar sobrenome. Maiúsculas e espaços repetidos são normalizados (ex.: ` ANA ` e `Ana` têm o mesmo voto). Acentos continuam diferentes.
- O nome fica no localStorage deste navegador; o voto fica no banco. Entrar com o mesmo nome em outro celular recupera e pode trocar esse voto.
- Cadastre a pizza do casal apenas uma vez. O cadastro preserva os campos quando há falha. Tentar novamente na mesma página reutiliza o id da pizza.
- O ranking mostra percentuais do total de votos, inclui pizzas sem votos e anuncia empate explicitamente. É parcial: não há encerramento automático. A turma combina quando parar de votar e como resolver o empate pelo vinho.
- O Realtime atualiza pizzas, votos e resultado revelado. Se desconectar, use **Atualizar**. Ao retornar à aba ou recuperar a internet, o app busca os dados novamente.

## Limites deste combinado

Sem login, o nome é um acordo entre amigos, não autenticação: alguém pode usar outro nome. As policies abertas solicitadas permitem consultar e alterar pizzas e votos via API. Esconder o resultado antes do voto é apenas uma regra de interface; o banco permite a leitura. Use somente para esta brincadeira e não inclua dados sensíveis. Falhas de cadastro ou troca de foto podem deixar imagens sem uso no bucket; ao final, exclua o projeto Supabase se não quiser manter os dados.

O projeto é entregue com placeholders: a conexão real e a publicação dependem de configurar seu Supabase e seu GitHub. Nenhum dado de demonstração é enviado ao banco.

Referências: [Supabase upsert](https://supabase.com/docs/reference/javascript/upsert), [upload de fotos](https://supabase.com/docs/reference/javascript/storage-from-upload), [Realtime](https://supabase.com/docs/guides/realtime/postgres-changes), [publicação no GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
