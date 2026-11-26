-- UniStudio 16: apply in a private Supabase project before enabling sync.
begin;
create table if not exists public.unistudio_snapshots (
 user_id uuid primary key references auth.users(id) on delete cascade,
 revision bigint not null check(revision > 0),
 payload jsonb not null check(jsonb_typeof(payload)='object'),
 updated_at timestamptz not null default now()
);
alter table public.unistudio_snapshots enable row level security;
revoke all on public.unistudio_snapshots from anon, authenticated;
grant select, insert, update on public.unistudio_snapshots to authenticated;
drop policy if exists uni_read on public.unistudio_snapshots;
create policy uni_read on public.unistudio_snapshots for select to authenticated using (auth.uid()=user_id);
drop policy if exists uni_insert on public.unistudio_snapshots;
create policy uni_insert on public.unistudio_snapshots for insert to authenticated with check (auth.uid()=user_id);
drop policy if exists uni_update on public.unistudio_snapshots;
create policy uni_update on public.unistudio_snapshots for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create or replace function public.unistudio_push(expected_revision bigint, new_payload jsonb)
returns bigint language plpgsql security invoker set search_path = '' as $$
declare n bigint;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if expected_revision < 0 or expected_revision is null or jsonb_typeof(new_payload) is distinct from 'object' then raise exception 'Invalid snapshot'; end if;
 if expected_revision=0 then
   insert into public.unistudio_snapshots(user_id,revision,payload) values(auth.uid(),1,new_payload)
   on conflict(user_id) do nothing returning revision into n;
 else
   update public.unistudio_snapshots set revision=revision+1,payload=new_payload,updated_at=now()
   where user_id=auth.uid() and revision=expected_revision returning revision into n;
 end if;
 if n is null then raise exception 'REVISION_CONFLICT' using errcode='40001'; end if;
 return n;
end; $$;
revoke all on function public.unistudio_push(bigint,jsonb) from public,anon;
grant execute on function public.unistudio_push(bigint,jsonb) to authenticated;
commit;
