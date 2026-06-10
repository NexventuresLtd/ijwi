'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Post, Comment, Profile, ReactionType } from '@/lib/types'
import PostCard from '@/components/post/PostCard'
import Navbar from '@/components/layout/Navbar'
import ProfileAvatar from '@/components/ui/ProfileAvatar'
import EssayMusicPlayer from '@/components/ui/EssayMusicPlayer'
import { createClient } from '@/lib/supabase/client'
import { timeAgo } from '@/lib/utils'
import BackButton from '@/components/ui/BackButton'

interface PostPageClientProps {
  post: Post
  comments: Comment[]
  currentUserId?: string
  profile?: Profile | null
  userReactions: ReactionType[]
  isAnswerer?: boolean
}

export default function PostPageClient({
  post, comments: initialComments, currentUserId, profile, userReactions, isAnswerer = false
}: PostPageClientProps) {
  const [comments, setComments] = useState(initialComments)
  const [newComment, setNewComment] = useState('')
  const [isAnon, setIsAnon] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [replyTo, setReplyTo] = useState<{ id: string; name: string } | null>(null)
  const [replyText, setReplyText] = useState('')
  const [replyAnon, setReplyAnon] = useState(false)
  const [replySubmitting, setReplySubmitting] = useState(false)
  const [expandedReplies, setExpandedReplies] = useState<Set<string>>(new Set())
  const [replies, setReplies] = useState<Record<string, Comment[]>>({})

  const supabase = createClient()

  const handleComment = async () => {
    if (!newComment.trim() || !currentUserId) return
    setSubmitting(true)

    const { data, error } = await supabase.from('comments').insert({
      post_id: post.id,
      author_id: currentUserId,
      body: newComment.trim(),
      is_anonymous: isAnon,
    }).select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url)`).single()

    if (!error && data) {
      setComments(c => [...c, data as any])
      setNewComment('')
    }
    setSubmitting(false)
  }

  const handleReply = async (parentId: string) => {
    if (!replyText.trim() || !currentUserId) return
    setReplySubmitting(true)

    const { data, error } = await supabase.from('comments').insert({
      post_id: post.id,
      author_id: currentUserId,
      body: replyText.trim(),
      is_anonymous: replyAnon,
      parent_id: parentId,
    }).select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url)`).single()

    if (!error && data) {
      setReplies(r => ({
        ...r,
        [parentId]: [...(r[parentId] ?? []), data as any]
      }))
      setExpandedReplies(s => new Set([...s, parentId]))
      setReplyText('')
      setReplyTo(null)
    }
    setReplySubmitting(false)
  }

  const loadReplies = async (parentId: string) => {
    if (expandedReplies.has(parentId)) {
      setExpandedReplies(s => { const n = new Set(s); n.delete(parentId); return n })
      return
    }
    const { data } = await supabase
      .from('comments')
      .select(`*, author:profiles(id, voice_name, is_revealed, real_name, avatar_url)`)
      .eq('parent_id', parentId)
      .order('created_at', { ascending: true })
    setReplies(r => ({ ...r, [parentId]: (data as any[]) ?? [] }))
    setExpandedReplies(s => new Set([...s, parentId]))
  }

  const handleCommentReact = async (commentId: string, type: 'fire' | 'amen') => {
    if (!currentUserId) return
    // Optimistic update on the comment object — simple toggle approach
    setComments(cs => cs.map(c => {
      if (c.id !== commentId) return c
      const reactions = c.reactions ?? { fire: 0, amen: 0 }
      return { ...c, reactions: { ...reactions, [type]: (reactions[type] ?? 0) + 1 } }
    }))
    await supabase.from('reactions').insert({ post_id: commentId, user_id: currentUserId, reaction_type: type }).then(() => {})
  }

  const isPrayer = post.content_type === 'prayer_request'
  const isQuestion = post.content_type === 'question'
  const canAnswer = !isQuestion || isAnswerer || profile?.is_admin

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--warm-white)' }}>
      <Navbar profile={profile} />
      {post.audio_url && <EssayMusicPlayer audioUrl={post.audio_url} title={post.title} />}

      <main style={{ flex: 1, maxWidth: '1100px', padding: '28px 24px', display: 'grid', gridTemplateColumns: '1fr', gap: '24px' }} className="post-detail-grid">
        <div>
          <BackButton href="/feed" label="Back to Feed" />
          {/* Post */}
          <PostCard post={post} currentUserId={currentUserId} userReactions={userReactions} fullVideo />
        </div>

        {/* Comments column */}
        <div style={{ position: 'sticky', top: 80, alignSelf: 'start', maxHeight: 'calc(100vh - 100px)', overflowY: 'auto' }}>

        {/* Essay truncation for guests */}
        {!currentUserId && (post as any).post_type === 'essay' && (
          <div style={{ position: 'relative', marginTop: -32, marginBottom: 32 }}>
            <div style={{
              position: 'absolute', bottom: 0, left: 0, right: 0,
              height: 120,
              background: 'linear-gradient(to bottom, transparent, var(--ij-bg-base))',
              zIndex: 2,
            }} />
            <div style={{
              position: 'relative', zIndex: 3,
              textAlign: 'center', paddingTop: 80,
            }}>
              <p style={{
                fontFamily: 'var(--ij-font-display)', fontSize: '1.1rem',
                fontStyle: 'italic', fontWeight: 600,
                color: 'var(--ij-text-primary)', marginBottom: 14,
              }}>
                Continue reading with a free account
              </p>
              <div style={{ display: 'flex', gap: 10, justifyContent: 'center', flexWrap: 'wrap' }}>
                <Link href={`/auth/signup?redirect=${encodeURIComponent('/post/' + post.id)}`}>
                  <button className="ij-btn-primary" style={{ minWidth: 180 }}>
                    Find your voice — it's free
                  </button>
                </Link>
                <Link href="/auth/login">
                  <button className="ij-btn-secondary" style={{ minWidth: 120 }}>
                    Sign in
                  </button>
                </Link>
              </div>
            </div>
          </div>
        )}

        {/* Comments */}
        <div style={{ marginBottom: '24px' }}>
          <h3 style={{
            fontFamily: 'var(--font-display)', fontSize: '18px', fontWeight: 500,
            marginBottom: '20px', color: 'var(--text-primary)'
          }}>
            {comments.length} {comments.length === 1 ? 'response' : 'responses'}
          </h3>

          {comments.map(comment => {
            const name = comment.is_anonymous
              ? (comment.author?.voice_name ?? 'Anonymous voice')
              : (comment.author?.real_name ?? comment.author?.voice_name ?? 'Anonymous')
            const isReplying = replyTo?.id === comment.id
            const isExpanded = expandedReplies.has(comment.id)
            const commentReplies = replies[comment.id] ?? []

            return (
              <div key={comment.id} style={{ marginBottom: '20px' }}>
                {/* Comment row */}
                <div style={{ display: 'flex', gap: '10px' }}>
                  <ProfileAvatar
                    userId={comment.author?.id ?? comment.author_id}
                    avatarUrl={comment.author?.avatar_url}
                    isRevealed={comment.author?.is_revealed && !comment.is_anonymous}
                    size={32}
                  />
                  <div style={{ flex: 1 }}>
                    <div style={{
                      background: 'var(--surface)', borderRadius: '14px',
                      padding: '12px 14px',
                    }}>
                      <div style={{ display: 'flex', alignItems: 'baseline', gap: '8px', marginBottom: '4px' }}>
                        {comment.author && !comment.is_anonymous ? (
                          <Link href={`/profile/${comment.author.id}`} style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)', textDecoration: 'none' }}>
                            {name}
                          </Link>
                        ) : (
                          <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-primary)' }}>{name}</span>
                        )}
                        <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{timeAgo(comment.created_at)}</span>
                      </div>
                      <p style={{
                        fontSize: '14px', color: 'var(--text-primary)', lineHeight: 1.65,
                        fontFamily: isPrayer ? 'var(--font-display)' : 'var(--font-body)',
                        fontStyle: isPrayer ? 'italic' : 'normal', margin: 0,
                      }}>
                        {comment.body}
                      </p>
                    </div>

                    {/* Actions row */}
                    <div style={{ display: 'flex', gap: '12px', marginTop: '6px', paddingLeft: '4px', alignItems: 'center' }}>
                      {/* Reactions */}
                      <button
                        onClick={() => handleCommentReact(comment.id, 'fire')}
                        style={{ background: 'none', border: 'none', cursor: currentUserId ? 'pointer' : 'default', fontSize: '12px', color: 'var(--text-muted)', padding: 0, display: 'flex', alignItems: 'center', gap: '3px' }}
                      >
                        ✨ {(comment.reactions?.fire ?? 0) > 0 ? comment.reactions.fire : ''}
                      </button>
                      <button
                        onClick={() => handleCommentReact(comment.id, 'amen')}
                        style={{ background: 'none', border: 'none', cursor: currentUserId ? 'pointer' : 'default', fontSize: '12px', color: 'var(--text-muted)', padding: 0, display: 'flex', alignItems: 'center', gap: '3px' }}
                      >
                        🙏 {(comment.reactions?.amen ?? 0) > 0 ? comment.reactions.amen : ''}
                      </button>
                      {/* Reply button */}
                      {currentUserId && (
                        <button
                          onClick={() => setReplyTo(isReplying ? null : { id: comment.id, name })}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '12px', color: isReplying ? 'var(--flame)' : 'var(--text-muted)', padding: 0, fontFamily: 'var(--font-body)' }}
                        >
                          Reply
                        </button>
                      )}
                      {/* Show replies */}
                      <button
                        onClick={() => loadReplies(comment.id)}
                        style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '12px', color: 'var(--text-muted)', padding: 0, fontFamily: 'var(--font-body)' }}
                      >
                        {isExpanded
                          ? 'Hide replies'
                          : commentReplies.length > 0
                            ? `${commentReplies.length} ${commentReplies.length === 1 ? 'reply' : 'replies'}`
                            : ''}
                      </button>
                    </div>

                    {/* Reply form */}
                    {isReplying && (
                      <div style={{ marginTop: '8px', display: 'flex', gap: '8px', alignItems: 'flex-start' }}>
                        <div style={{ flex: 1 }}>
                          <textarea
                            autoFocus
                            placeholder={`Reply to ${replyTo.name}...`}
                            value={replyText}
                            onChange={e => setReplyText(e.target.value)}
                            rows={2}
                            style={{
                              width: '100%', padding: '10px 12px', borderRadius: '12px',
                              border: '1px solid var(--flame)', fontSize: '14px',
                              fontFamily: 'var(--font-body)', background: 'var(--surface)',
                              color: 'var(--text-primary)', outline: 'none', resize: 'none',
                              boxSizing: 'border-box',
                            }}
                          />
                          <div style={{ display: 'flex', gap: '8px', marginTop: '6px', alignItems: 'center' }}>
                            <button
                              onClick={() => handleReply(comment.id)}
                              disabled={replySubmitting || !replyText.trim()}
                              style={{
                                padding: '6px 16px', borderRadius: '100px',
                                background: 'var(--flame)', color: 'white', border: 'none',
                                fontSize: '13px', cursor: 'pointer', fontFamily: 'var(--font-body)',
                              }}
                            >
                              {replySubmitting ? '...' : 'Reply'}
                            </button>
                            <label style={{ fontSize: '12px', color: 'var(--text-muted)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}>
                              <input type="checkbox" checked={replyAnon} onChange={e => setReplyAnon(e.target.checked)} style={{ accentColor: 'var(--flame)' }} />
                              Anonymous
                            </label>
                            <button onClick={() => setReplyTo(null)} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', fontSize: '12px', cursor: 'pointer' }}>
                              Cancel
                            </button>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Replies */}
                    {isExpanded && commentReplies.map(reply => {
                      const replyName = reply.is_anonymous
                        ? (reply.author?.voice_name ?? 'Anonymous')
                        : (reply.author?.real_name ?? reply.author?.voice_name ?? 'Anonymous')
                      return (
                        <div key={reply.id} style={{ display: 'flex', gap: '8px', marginTop: '10px', paddingLeft: '8px', borderLeft: '2px solid var(--border)' }}>
                          <ProfileAvatar
                            userId={reply.author?.id ?? reply.author_id}
                            avatarUrl={reply.author?.avatar_url}
                            isRevealed={reply.author?.is_revealed && !reply.is_anonymous}
                            size={24}
                          />
                          <div style={{ flex: 1, background: 'var(--surface-2)', borderRadius: '12px', padding: '8px 12px' }}>
                            <div style={{ display: 'flex', gap: '8px', alignItems: 'baseline', marginBottom: '3px' }}>
                              <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>{replyName}</span>
                              <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{timeAgo(reply.created_at)}</span>
                            </div>
                            <p style={{ fontSize: '13px', color: 'var(--text-primary)', lineHeight: 1.6, margin: 0 }}>{reply.body}</p>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* Comment composer */}
        {currentUserId && canAnswer ? (
          <div className="card" style={{ padding: '20px' }}>
            <textarea
              placeholder={isPrayer ? 'Write a prayer for this person...' : isQuestion ? 'Share your answer...' : 'Share your response...'}
              value={newComment}
              onChange={e => setNewComment(e.target.value)}
              rows={4}
              style={{
                width: '100%', padding: '12px', borderRadius: '10px',
                border: '1px solid var(--border)', fontSize: '15px',
                fontFamily: isPrayer ? 'var(--font-display)' : 'var(--font-body)',
                fontStyle: isPrayer ? 'italic' : 'normal',
                background: 'var(--surface)', color: 'var(--text-primary)',
                outline: 'none', resize: 'vertical', lineHeight: 1.7, marginBottom: '12px',
                boxSizing: 'border-box',
              }}
            />
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <button
                onClick={handleComment}
                disabled={submitting || !newComment.trim()}
                style={{
                  padding: '10px 24px', borderRadius: '100px',
                  background: submitting ? 'var(--border)' : 'var(--flame)',
                  color: submitting ? 'var(--text-muted)' : 'white',
                  border: 'none', fontSize: '14px', cursor: submitting ? 'not-allowed' : 'pointer',
                  fontFamily: 'var(--font-body)', fontWeight: 500
                }}
              >
                {submitting ? 'Posting...' : isPrayer ? '🙏 Pray with them' : isQuestion ? 'Post answer' : 'Respond'}
              </button>
              <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', color: 'var(--text-muted)', cursor: 'pointer' }}>
                <input type="checkbox" checked={isAnon} onChange={e => setIsAnon(e.target.checked)} style={{ accentColor: 'var(--flame)' }} />
                Post anonymously
              </label>
            </div>
          </div>
        ) : currentUserId && isQuestion ? (
          <div style={{ textAlign: 'center', padding: '24px', borderRadius: '12px', background: 'var(--surface-2)', border: '1px solid var(--border)' }}>
            <div style={{ fontSize: '28px', marginBottom: '8px' }}>🔒</div>
            <p style={{ fontSize: '15px', color: 'var(--text-secondary)', marginBottom: '4px', fontWeight: 600 }}>
              Only approved voices can answer
            </p>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Questions are answered by trusted pastors, counselors, and content creators approved by the Ijwi team.
            </p>
          </div>
        ) : (
          <div style={{ textAlign: 'center', padding: '24px', borderRadius: '12px', background: 'var(--surface-2)', border: '1px solid var(--border)' }}>
            <p style={{ fontSize: '15px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
              Join Ijwi to respond and pray with others
            </p>
            <Link href="/auth/signup" style={{
              padding: '10px 24px', borderRadius: '100px',
              background: 'var(--flame)', color: 'white',
              textDecoration: 'none', fontSize: '14px', fontFamily: 'var(--font-body)'
            }}>
              Find your voice
            </Link>
          </div>
        )}
        </div>
      </main>
    </div>
  )
}
