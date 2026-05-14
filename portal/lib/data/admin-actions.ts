'use server'

import { createClient } from '@/lib/supabase/server-admin'
import { revalidatePath } from 'next/cache'
import type { Game } from './games'

const THUMBNAIL_BUCKET = 'game-thumbnails'
const MAX_THUMBNAIL_BYTES = 2 * 1024 * 1024
const ALLOWED_THUMBNAIL_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
])

type GameStatus = 'coming_soon' | 'live' | 'retired'

function getRequiredText(formData: FormData, key: string) {
  const value = formData.get(key)
  return typeof value === 'string' ? value.trim() : ''
}

function getStatus(formData: FormData): GameStatus {
  const status = getRequiredText(formData, 'status')
  return status === 'live' || status === 'retired' ? status : 'coming_soon'
}

function getFileExtension(file: File) {
  const extension = file.name.split('.').pop()?.toLowerCase()
  if (extension && /^[a-z0-9]+$/.test(extension)) return extension
  if (file.type === 'image/jpeg') return 'jpg'
  if (file.type === 'image/png') return 'png'
  if (file.type === 'image/webp') return 'webp'
  if (file.type === 'image/gif') return 'gif'
  return 'bin'
}

function getThumbnailFile(formData: FormData) {
  const file = formData.get('thumbnail_file')
  return file instanceof File && file.size > 0 ? file : null
}

async function uploadThumbnail(file: File | null, slug: string) {
  if (!file) return { url: null as string | null, error: null as string | null }
  if (!ALLOWED_THUMBNAIL_TYPES.has(file.type)) {
    return { url: null, error: 'Thumbnail must be a PNG, JPG, WebP, or GIF image' }
  }
  if (file.size > MAX_THUMBNAIL_BYTES) {
    return { url: null, error: 'Thumbnail must be 2 MB or smaller' }
  }

  const supabase = createClient()
  const safeSlug = slug.toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-|-$/g, '') || 'game'
  const path = `${safeSlug}/${crypto.randomUUID()}.${getFileExtension(file)}`
  const { error } = await supabase.storage.from(THUMBNAIL_BUCKET).upload(path, file, {
    contentType: file.type,
    upsert: false,
  })
  if (error) return { url: null, error: error.message }

  const { data } = supabase.storage.from(THUMBNAIL_BUCKET).getPublicUrl(path)
  return { url: data.publicUrl, error: null }
}

export async function createGameAction(formData: FormData) {
  const supabase = createClient()
  const slug = getRequiredText(formData, 'slug')
  const name = getRequiredText(formData, 'name')
  const description = getRequiredText(formData, 'description')
  const thumbnail = await uploadThumbnail(getThumbnailFile(formData), slug)
  if (thumbnail.error) return { error: thumbnail.error }

  const { data, error } = await supabase
    .from('games')
    .insert({
      slug,
      name,
      description: description || null,
      thumbnail_url: thumbnail.url,
      status: getStatus(formData),
    })
    .select()
    .single()
  if (error) return { error: error.message }
  revalidatePath('/admin')
  return { data: data as Game }
}

export async function updateGameAction(
  id: string,
  formData: FormData
) {
  const supabase = createClient()
  const slug = getRequiredText(formData, 'slug')
  const description = getRequiredText(formData, 'description')
  const thumbnail = await uploadThumbnail(getThumbnailFile(formData), slug)
  if (thumbnail.error) return { error: thumbnail.error }

  const updates: {
    slug: string
    name: string
    description: string | null
    status: GameStatus
    thumbnail_url?: string
  } = {
    slug,
    name: getRequiredText(formData, 'name'),
    description: description || null,
    status: getStatus(formData),
  }
  if (thumbnail.url) updates.thumbnail_url = thumbnail.url

  const { data, error } = await supabase
    .from('games')
    .update(updates)
    .eq('id', id)
    .select()
    .single()
  if (error) return { error: error.message }
  revalidatePath('/admin')
  return { data: data as Game }
}

export async function deleteGameAction(id: string) {
  const supabase = createClient()

  const childDeletes = [
    supabase.from('scores').delete().eq('game_id', id),
    supabase.from('achievements').delete().eq('game_id', id),
    supabase.from('matches').delete().eq('game_id', id),
    supabase.from('seasons').delete().eq('game_id', id),
  ]

  for (const deleteQuery of childDeletes) {
    const { error } = await deleteQuery
    if (error) return { error: error.message }
  }

  const { error } = await supabase
    .from('games')
    .delete()
    .eq('id', id)
  if (error) return { error: error.message }
  revalidatePath('/admin')
  return { error: null }
}
