-- Public bucket for admin-managed game thumbnail uploads.
-- games.thumbnail_url continues to store the public URL used by the portal UI.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'game-thumbnails',
  'game-thumbnails',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'public read game thumbnails'
  ) then
    create policy "public read game thumbnails"
      on storage.objects for select
      using (bucket_id = 'game-thumbnails');
  end if;
end;
$$;
