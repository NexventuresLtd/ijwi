import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import PostPageClient from './PostPageClient'
import type { Metadata } from 'next'

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params
  const supabase = await createClient()
  
  const { data: post } = await supabase
    .from('posts')
    .select('content, media_urls, is_anonymous, profiles!posts_user_id_fkey(name, voice_name)')
    .eq('id', id)
    .single()

  if (!post) return { title: 'Post Not Found' }

  let authorName = 'Anonymous'
  if (!post.is_anonymous && post.profiles) {
    const profile = Array.isArray(post.profiles) ? post.profiles[0] : post.profiles;
    authorName = profile.voice_name || profile.name || 'Anonymous'
  }

  const plainText = post.content?.substring(0, 150) || 'View this post on Ijwi.'
  const imageUrl = post.media_urls && post.media_urls.length > 0 ? post.media_urls[0] : null

  return {
    title: `Post by ${authorName} on Ijwi`,
    description: plainText,
    openGraph: {
      title: `Post by ${authorName} on Ijwi`,
      description: plainText,
      images: imageUrl ? [imageUrl] : [],
      type: 'article',
    },
    twitter: {
      card: imageUrl ? 'summary_large_image' : 'summary',
      title: `Post by ${authorName} on Ijwi`,
      description: plainText,
      images: imageUrl ? [imageUrl] : [],
    },
  }
}

export default async function PostPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // No JOIN — a JOIN that references a missing column silently returns null,
  // causing notFound() even when the post exists.
  const { data: postRaw } = await supabase
    .from('posts')
    .select('*')
    .eq('id', id)
    .single()

  if (!postRaw) notFound()

  // Fetch author separately so a missing profile column can't 404 the page.
  const { data: authorProfile } = await supabase
    .from('profiles')
    .select('id, voice_name, is_revealed, real_name, avatar_url, is_verified, is_approved_poster, subscription_status')
    .eq('id', postRaw.author_id)
    .maybeSingle()

  const { data: comments } = await supabase
    .from('comments')
    .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url)`)
    .eq('post_id', id)
    .is('parent_id', null)
    .order('created_at', { ascending: true })

  let profile = null
  let userReactions: string[] = []

  if (user) {
    const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
    profile = data

    const { data: reactions } = await supabase
      .from('reactions')
      .select('reaction_type')
      .eq('post_id', id)
      .eq('user_id', user.id)
    userReactions = (reactions ?? []).map(r => r.reaction_type)
  }

  const post = {
    ...postRaw,
    author: authorProfile,
    reactions: {
      fire: postRaw.reaction_fire ?? 0,
      amen: postRaw.reaction_amen ?? 0,
      healed: postRaw.reaction_healed ?? 0,
      needed: postRaw.reaction_needed ?? 0,
      sharing: postRaw.reaction_sharing ?? 0,
    }
  }

  return (
    <PostPageClient
      post={post}
      comments={comments ?? []}
      currentUserId={user?.id}
      profile={profile}
      userReactions={userReactions as any}
      isAnswerer={profile?.is_answerer ?? false}
    />
  )
}
