-- EZE Viabilidade — estrutura do banco (rode uma vez no Supabase: SQL Editor → New query → colar → Run)

create table if not exists public.acessos (
  email text primary key check (email = lower(email)),
  papel text not null check (papel in ('admin','editor','leitor')),
  criado_em timestamptz not null default now(),
  criado_por text
);

create table if not exists public.estudos (
  id text primary key,
  nome text,
  dados jsonb not null,
  publico boolean not null default false,
  rev integer not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por text
);

create table if not exists public.estudo_versoes (
  id uuid primary key default gen_random_uuid(),
  estudo_id text not null references public.estudos(id) on delete cascade,
  nome text not null,
  dados jsonb not null,
  criado_em timestamptz not null default now(),
  criado_por text
);
create index if not exists estudo_versoes_estudo_idx on public.estudo_versoes (estudo_id, criado_em desc);

-- papel de quem está logado (null = sem acesso)
create or replace function public.meu_papel() returns text
language sql stable security definer set search_path = public as $$
  select papel from public.acessos where email = lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

-- a tela de entrada pergunta se o e-mail está liberado (só responde sim/não)
create or replace function public.email_liberado(p_email text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.acessos where email = lower(trim(p_email)))
$$;

-- lista de acessos com situação (só admin)
create or replace function public.acessos_status()
returns table (email text, papel text, criado_em timestamptz, tem_conta boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if public.meu_papel() is distinct from 'admin' then raise exception 'Apenas o administrador'; end if;
  return query
    select a.email, a.papel, a.criado_em,
           exists (select 1 from auth.users u where lower(u.email) = a.email)
    from public.acessos a order by a.criado_em;
end $$;

-- bloqueia cadastro de e-mail não liberado (garantia no servidor)
create or replace function public.bloquear_cadastro() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.acessos where email = lower(new.email)) then
    raise exception 'Este e-mail não tem acesso liberado.';
  end if;
  return new;
end $$;
drop trigger if exists bloquear_cadastro on auth.users;
create trigger bloquear_cadastro before insert on auth.users
  for each row execute function public.bloquear_cadastro();

-- regras de acesso
alter table public.acessos enable row level security;
alter table public.estudos enable row level security;
alter table public.estudo_versoes enable row level security;

drop policy if exists acessos_ler on public.acessos;
create policy acessos_ler on public.acessos for select to authenticated
  using (email = lower(auth.jwt() ->> 'email') or public.meu_papel() = 'admin');
drop policy if exists acessos_inserir on public.acessos;
create policy acessos_inserir on public.acessos for insert to authenticated
  with check (public.meu_papel() = 'admin');
drop policy if exists acessos_alterar on public.acessos;
create policy acessos_alterar on public.acessos for update to authenticated
  using (public.meu_papel() = 'admin' and email <> lower(auth.jwt() ->> 'email'))
  with check (public.meu_papel() = 'admin');
drop policy if exists acessos_remover on public.acessos;
create policy acessos_remover on public.acessos for delete to authenticated
  using (public.meu_papel() = 'admin' and email <> lower(auth.jwt() ->> 'email'));

drop policy if exists estudos_ler on public.estudos;
create policy estudos_ler on public.estudos for select to authenticated
  using (public.meu_papel() is not null);
drop policy if exists estudos_publicos on public.estudos;
create policy estudos_publicos on public.estudos for select to anon
  using (publico);
drop policy if exists estudos_inserir on public.estudos;
create policy estudos_inserir on public.estudos for insert to authenticated
  with check (public.meu_papel() in ('admin','editor'));
drop policy if exists estudos_alterar on public.estudos;
create policy estudos_alterar on public.estudos for update to authenticated
  using (public.meu_papel() in ('admin','editor')) with check (public.meu_papel() in ('admin','editor'));
drop policy if exists estudos_excluir on public.estudos;
create policy estudos_excluir on public.estudos for delete to authenticated
  using (public.meu_papel() in ('admin','editor'));

drop policy if exists versoes_ler on public.estudo_versoes;
create policy versoes_ler on public.estudo_versoes for select to authenticated
  using (public.meu_papel() is not null);
drop policy if exists versoes_inserir on public.estudo_versoes;
create policy versoes_inserir on public.estudo_versoes for insert to authenticated
  with check (public.meu_papel() in ('admin','editor'));
drop policy if exists versoes_excluir on public.estudo_versoes;
create policy versoes_excluir on public.estudo_versoes for delete to authenticated
  using (public.meu_papel() in ('admin','editor'));

-- administrador inicial
insert into public.acessos (email, papel, criado_por)
values ('maiko.gkengenharia@gmail.com', 'admin', 'instalação')
on conflict (email) do update set papel = 'admin';
