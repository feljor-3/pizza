-- Execute após aprovar e aplicar atualizacao-ranking.sql. Tudo é revertido.
begin;
set local role anon;
do $$
declare
 u text := 'teste-'||gen_random_uuid()::text;
 a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
 d uuid:=gen_random_uuid(); e uuid:=gen_random_uuid(); f uuid:=gen_random_uuid();
 rejected boolean;
 actual uuid[];
begin
 insert into public.participantes(nome,exibicao) values(u,'Teste transacional');
 insert into public.pizzas(id,nome,casal,autores) values
 (a,'Teste própria','Teste',array[u]),(b,'Teste B','Teste','{}'),
 (c,'Teste C','Teste','{}'),(d,'Teste D','Teste','{}'),
 (e,'Teste E','Teste','{}'),(f,'Teste F','Teste','{}');
 rejected:=false;
 begin
  insert into public.rankings(votante,escolhas) values(u,array[a]);
 exception when raise_exception then rejected:=true; end;
 if not rejected then raise exception 'FAIL: voto próprio aceito'; end if;
 rejected:=false;
 begin
  insert into public.rankings(votante,escolhas) values(u,array[b,b]);
 exception when raise_exception then rejected:=true; end;
 if not rejected then raise exception 'FAIL: pizza repetida aceita'; end if;
 rejected:=false;
 begin
  insert into public.rankings(votante,escolhas) values(u,array[b,c,d,e,f]);
 exception when raise_exception then rejected:=true; end;
 if not rejected then raise exception 'FAIL: quinta posição aceita'; end if;
 insert into public.rankings(votante,escolhas) values(u,array[b,c,d,e])
 on conflict(votante) do update set escolhas=excluded.escolhas;
 if (select sum(6-ord) from public.rankings r cross join lateral unnest(r.escolhas) with ordinality p(id,ord) where r.votante=u)<>14 then
  raise exception 'FAIL: pontuação não soma 14';
 end if;
 update public.pizzas set autores=array[u] where id=b;
 select escolhas into actual from public.rankings where votante=u;
 if actual<>array[c,d,e] then raise exception 'FAIL: novo vínculo não ajustou ranking'; end if;
 delete from public.pizzas where id=d;
 select escolhas into actual from public.rankings where votante=u;
 if actual<>array[c,e] then raise exception 'FAIL: exclusão não compactou ranking'; end if;
 rejected:=false;
 begin
  update public.rankings set escolhas=array[d] where votante=u;
 exception when raise_exception then rejected:=true; end;
 if not rejected then raise exception 'FAIL: pizza excluída aceita'; end if;
 select escolhas into actual from public.rankings where votante=u;
 if actual<>array[c,e] then raise exception 'FAIL: erro não preservou ranking anterior'; end if;
 update public.rankings set escolhas='{}' where votante=u;
 if (select cardinality(escolhas) from public.rankings where votante=u)<>0 then raise exception 'FAIL: limpeza falhou'; end if;
 raise notice 'PASS: voto próprio, repetição, limite, soma, vínculo, exclusão, atomicidade e limpeza';
end $$;
rollback;
