-- Execute inteiro no SQL Editor de um projeto Supabase novo.
-- Modelo de confiança entre amigos: qualquer visitante pode ler e alterar dados.
begin;
create table if not exists public.pizzas (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(trim(nome)) between 1 and 100),
  casal text not null check (char_length(trim(casal)) between 1 and 100),
  ingredientes text check (char_length(ingredientes) <= 1000),
  foto_url text,
  criada_em timestamptz not null default now()
);
create table if not exists public.votos (
  id uuid primary key default gen_random_uuid(),
  votante text not null check (char_length(trim(votante)) between 1 and 60),
  pizza_id uuid not null references public.pizzas(id),
  criado_em timestamptz not null default now(),
  unique(votante)
);
create index if not exists votos_pizza_id_idx on public.votos(pizza_id);
alter table public.pizzas enable row level security;
alter table public.votos enable row level security;
grant usage on schema public to anon;
grant select, insert, update on public.pizzas, public.votos to anon;
-- DROP + CREATE permite executar o script novamente sem duplicar policies.
drop policy if exists pizzas_select_anon on public.pizzas;
create policy pizzas_select_anon on public.pizzas for select to anon using (true);
drop policy if exists pizzas_insert_anon on public.pizzas;
create policy pizzas_insert_anon on public.pizzas for insert to anon with check (true);
drop policy if exists pizzas_update_anon on public.pizzas;
create policy pizzas_update_anon on public.pizzas for update to anon using (true) with check (true);
drop policy if exists votos_select_anon on public.votos;
create policy votos_select_anon on public.votos for select to anon using (true);
drop policy if exists votos_insert_anon on public.votos;
create policy votos_insert_anon on public.votos for insert to anon with check (true);
drop policy if exists votos_update_anon on public.votos;
create policy votos_update_anon on public.votos for update to anon using (true) with check (true);
-- Cria o bucket público; a leitura pública não exige policy SELECT em objects.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', true, 5242880, array['image/jpeg'])
on conflict (id) do update set public=true, file_size_limit=5242880, allowed_mime_types=array['image/jpeg'];
drop policy if exists fotos_upload_anon on storage.objects;
create policy fotos_upload_anon on storage.objects for insert to anon with check (bucket_id = 'fotos');
-- Realtime (o app também funciona com atualização manual).
do $$
begin
 if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pizzas') then
   alter publication supabase_realtime add table public.pizzas;
 end if;
 if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='votos') then
   alter publication supabase_realtime add table public.votos;
 end if;
end $$;
commit;
