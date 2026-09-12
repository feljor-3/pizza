-- Noite da Pizza v2. Execute depois de supabase.sql em instalações novas.
-- Preserva pizzas; votos v1 são convertidos em primeira escolha (5 pontos).
begin;
create table if not exists public.participantes (
 nome text primary key check (char_length(nome) between 1 and 60),
 exibicao text not null check (char_length(trim(exibicao)) between 1 and 60),
 criado_em timestamptz not null default now()
);
alter table public.pizzas add column if not exists autores text[] not null default '{}';
create table if not exists public.rankings (
 votante text primary key references public.participantes(nome),
 escolhas uuid[] not null default '{}',
 atualizado_em timestamptz not null default now()
);
alter table public.participantes enable row level security;
alter table public.rankings enable row level security;
grant select,insert,update on public.participantes,public.rankings to anon;
grant delete on public.pizzas to anon;
drop policy if exists participantes_select on public.participantes;
create policy participantes_select on public.participantes for select to anon using(true);
drop policy if exists participantes_insert on public.participantes;
create policy participantes_insert on public.participantes for insert to anon with check(true);
drop policy if exists participantes_update on public.participantes;
create policy participantes_update on public.participantes for update to anon using(true) with check(true);
drop policy if exists rankings_select on public.rankings;
create policy rankings_select on public.rankings for select to anon using(true);
drop policy if exists rankings_insert on public.rankings;
create policy rankings_insert on public.rankings for insert to anon with check(true);
drop policy if exists rankings_update on public.rankings;
create policy rankings_update on public.rankings for update to anon using(true) with check(true);
drop policy if exists pizzas_delete_anon on public.pizzas;
create policy pizzas_delete_anon on public.pizzas for delete to anon using(true);
-- Remove também referências antigas quando uma pizza for excluída.
alter table public.votos drop constraint if exists votos_pizza_id_fkey;
alter table public.votos add constraint votos_pizza_id_fkey foreign key(pizza_id) references public.pizzas(id) on delete cascade;
-- Um único lock por declaração serializa mudanças de uma mesa de até 15 pessoas.
-- BEFORE STATEMENT evita inversão de locks entre linhas de pizzas e rankings.
create or replace function public.mesa_bloquear() returns trigger
language plpgsql security invoker set search_path='' as $$
begin perform pg_catalog.pg_advisory_xact_lock(748293016::bigint); return null; end $$;
drop trigger if exists mesa_pizzas_lock on public.pizzas;
create trigger mesa_pizzas_lock before insert or update or delete on public.pizzas for each statement execute function public.mesa_bloquear();
drop trigger if exists mesa_rankings_lock on public.rankings;
create trigger mesa_rankings_lock before insert or update or delete on public.rankings for each statement execute function public.mesa_bloquear();
create or replace function public.mesa_validar_participante() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.nome <> lower(trim(regexp_replace(normalize(new.nome,NFKC),'\s+',' ','g'))) then
  raise exception 'Use o nome normalizado ao entrar na mesa.';
 end if;
 return new;
end $$;
drop trigger if exists participantes_validar on public.participantes;
create trigger participantes_validar before insert or update on public.participantes for each row execute function public.mesa_validar_participante();
create or replace function public.mesa_validar_ranking() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.escolhas is null or cardinality(new.escolhas)>4
   or (cardinality(new.escolhas)>0 and (array_ndims(new.escolhas)<>1 or array_lower(new.escolhas,1)<>1))
   or exists(select 1 from unnest(new.escolhas) x where x is null)
   or cardinality(new.escolhas)<>(select count(distinct x) from unnest(new.escolhas) x) then
  raise exception 'Escolha até quatro pizzas diferentes, sem posições vazias.';
 end if;
 if exists(select 1 from unnest(new.escolhas) x where not exists(select 1 from public.pizzas p where p.id=x)) then
  raise exception 'Uma pizza foi excluída. Atualize e refaça suas escolhas.';
 end if;
 if exists(select 1 from public.pizzas p where p.id=any(new.escolhas) and new.votante=any(p.autores)) then
  raise exception 'Você não pode colocar sua própria pizza no ranking.';
 end if;
 new.atualizado_em=now();
 return new;
end $$;
drop trigger if exists rankings_validar on public.rankings;
create trigger rankings_validar before insert or update on public.rankings for each row execute function public.mesa_validar_ranking();
create or replace function public.mesa_validar_autores() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='UPDATE' and new.id<>old.id then raise exception 'O identificador da pizza não pode mudar.'; end if;
 if new.autores is null or cardinality(new.autores)>30
  or (cardinality(new.autores)>0 and (array_ndims(new.autores)<>1 or array_lower(new.autores,1)<>1))
  or exists(select 1 from unnest(new.autores) x where x is null)
  or cardinality(new.autores)<>(select count(distinct x) from unnest(new.autores) x)
  or exists(select 1 from unnest(new.autores) x where not exists(select 1 from public.participantes u where u.nome=x)) then
   raise exception 'Selecione participantes que já entraram na mesa.';
 end if;
 return new;
end $$;
drop trigger if exists pizzas_validar_autores on public.pizzas;
create trigger pizzas_validar_autores before insert or update on public.pizzas for each row execute function public.mesa_validar_autores();
create or replace function public.mesa_ajustar_rankings() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='DELETE' then
  update public.rankings set escolhas=array_remove(escolhas,old.id) where escolhas @> array[old.id];
 elsif new.autores is distinct from old.autores then
  update public.rankings set escolhas=array_remove(escolhas,new.id)
  where votante=any(new.autores) and escolhas @> array[new.id];
 end if;
 return null;
end $$;
drop trigger if exists pizzas_ajustar_rankings on public.pizzas;
create trigger pizzas_ajustar_rankings after update or delete on public.pizzas for each row execute function public.mesa_ajustar_rankings();
-- A aplicação usa apenas a chave anon e continua sem autenticação.
-- Funções são invoker, executadas pelos triggers; não há API com privilégio elevado.
revoke execute on function public.mesa_bloquear(), public.mesa_validar_participante(), public.mesa_validar_ranking(), public.mesa_validar_autores(), public.mesa_ajustar_rankings() from public,anon,authenticated;
insert into public.participantes(nome,exibicao)
select distinct on (lower(trim(regexp_replace(normalize(votante,NFKC),'\s+',' ','g'))))
 lower(trim(regexp_replace(normalize(votante,NFKC),'\s+',' ','g'))),trim(votante)
from public.votos order by lower(trim(regexp_replace(normalize(votante,NFKC),'\s+',' ','g'))),criado_em desc
on conflict(nome) do nothing;
insert into public.rankings(votante,escolhas)
select distinct on (lower(trim(regexp_replace(normalize(v.votante,NFKC),'\s+',' ','g'))))
 lower(trim(regexp_replace(normalize(v.votante,NFKC),'\s+',' ','g'))),array[v.pizza_id]
from public.votos v join public.pizzas p on p.id=v.pizza_id
where not (lower(trim(regexp_replace(normalize(v.votante,NFKC),'\s+',' ','g')))=any(p.autores))
order by lower(trim(regexp_replace(normalize(v.votante,NFKC),'\s+',' ','g'))),v.criado_em desc
on conflict(votante) do nothing;
-- Votos v1 ficam como histórico; clientes antigos devem recarregar a página.
revoke insert,update on public.votos from anon;
-- Remoção da imagem após excluir o cadastro (a API de Storage remove os bytes).
drop policy if exists fotos_delete_anon on storage.objects;
create policy fotos_delete_anon on storage.objects for delete to anon using(bucket_id='fotos');
drop policy if exists fotos_select_anon on storage.objects;
create policy fotos_select_anon on storage.objects for select to anon using(bucket_id='fotos');
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='participantes') then alter publication supabase_realtime add table public.participantes; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rankings') then alter publication supabase_realtime add table public.rankings; end if;
end $$;
commit;
