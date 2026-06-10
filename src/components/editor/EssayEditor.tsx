'use client'

import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Placeholder from '@tiptap/extension-placeholder'
import Link from '@tiptap/extension-link'
import { useEffect } from 'react'

interface EssayEditorProps {
  content: string
  onChange: (html: string) => void
  placeholder?: string
}

export default function EssayEditor({ content, onChange, placeholder }: EssayEditorProps) {
  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({
        placeholder: placeholder ?? 'Begin writing your essay…',
      }),
      Link.configure({ openOnClick: false }),
    ],
    content,
    onUpdate: ({ editor }) => {
      onChange(editor.getHTML())
    },
    editorProps: {
      attributes: {
        class: 'essay-editor-content',
      },
    },
  })

  useEffect(() => {
    return () => { editor?.destroy() }
  }, [editor])

  if (!editor) return null

  return (
    <div style={{ position: 'relative' }}>
      {/* Toolbar */}
      <div style={{
        display: 'flex', gap: 4, flexWrap: 'wrap',
        padding: '8px 12px',
        borderBottom: '1px solid var(--ij-border)',
        background: 'var(--ij-bg-elevated)',
        borderRadius: '10px 10px 0 0',
      }}>
        {[
          { label: 'B', title: 'Bold', action: () => editor.chain().focus().toggleBold().run(), active: editor.isActive('bold') },
          { label: 'I', title: 'Italic', action: () => editor.chain().focus().toggleItalic().run(), active: editor.isActive('italic') },
          { label: 'H2', title: 'Heading 2', action: () => editor.chain().focus().toggleHeading({ level: 2 }).run(), active: editor.isActive('heading', { level: 2 }) },
          { label: 'H3', title: 'Heading 3', action: () => editor.chain().focus().toggleHeading({ level: 3 }).run(), active: editor.isActive('heading', { level: 3 }) },
          { label: '❝', title: 'Blockquote', action: () => editor.chain().focus().toggleBlockquote().run(), active: editor.isActive('blockquote') },
          { label: '—', title: 'Horizontal rule', action: () => editor.chain().focus().setHorizontalRule().run(), active: false },
        ].map(btn => (
          <button
            key={btn.label}
            type="button"
            title={btn.title}
            onClick={btn.action}
            style={{
              minWidth: 32, height: 28, borderRadius: 6, border: 'none', cursor: 'pointer',
              background: btn.active ? 'var(--ij-gold)' : 'transparent',
              color: btn.active ? '#0B0B1F' : 'var(--ij-text-secondary)',
              fontFamily: 'var(--ij-font-body)',
              fontSize: btn.label === 'B' ? '14px' : '12px',
              fontWeight: btn.label === 'B' ? 700 : 500,
              fontStyle: btn.label === 'I' ? 'italic' : 'normal',
              transition: 'background 0.15s, color 0.15s',
              padding: '0 8px',
            }}
          >
            {btn.label}
          </button>
        ))}
      </div>

      {/* Editor area */}
      <EditorContent
        editor={editor}
        style={{
          minHeight: 360,
          padding: '20px 24px',
          background: 'var(--ij-bg-surface)',
          border: '1px solid var(--ij-border)',
          borderTop: 'none',
          borderRadius: '0 0 10px 10px',
          outline: 'none',
        }}
      />

      <style>{`
        .essay-editor-content {
          outline: none;
          font-family: var(--ij-font-body);
          font-size: 16px;
          line-height: 1.8;
          color: var(--ij-text-primary);
        }
        .essay-editor-content p { margin-bottom: 14px; }
        .essay-editor-content h2 {
          font-family: var(--ij-font-display);
          font-size: 1.5rem;
          font-weight: 700;
          color: var(--ij-text-primary);
          margin: 24px 0 12px;
        }
        .essay-editor-content h3 {
          font-family: var(--ij-font-display);
          font-size: 1.2rem;
          font-weight: 600;
          color: var(--ij-text-primary);
          margin: 20px 0 10px;
        }
        .essay-editor-content blockquote {
          border-left: 3px solid var(--ij-gold);
          padding: 8px 0 8px 16px;
          margin: 16px 0;
          color: var(--ij-text-secondary);
          font-style: italic;
        }
        .essay-editor-content hr {
          border: none;
          border-top: 1px solid var(--ij-border);
          margin: 24px 0;
        }
        .essay-editor-content a { color: var(--ij-gold); text-decoration: underline; }
        .essay-editor-content p.is-editor-empty:first-child::before {
          content: attr(data-placeholder);
          float: left;
          color: var(--ij-text-hint);
          pointer-events: none;
          height: 0;
        }
      `}</style>
    </div>
  )
}
