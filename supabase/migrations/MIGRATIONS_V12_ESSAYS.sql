-- ============================================
-- ESSAYS TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS public.essays (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    author_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    cover_image_url text,
    content jsonb,
    content_html text,
    reading_time_mins integer DEFAULT 1,
    topics text[] DEFAULT '{}',
    bg_color_hex text,
    music_url text,
    is_published boolean DEFAULT false,
    published_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Analytics & Tracking
CREATE TABLE IF NOT EXISTS public.essay_analytics (
    essay_id uuid REFERENCES public.essays(id) ON DELETE CASCADE PRIMARY KEY,
    reads integer DEFAULT 0,
    completions integer DEFAULT 0,
    total_read_time_seconds bigint DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Highlights
CREATE TABLE IF NOT EXISTS public.essay_highlights (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    essay_id uuid REFERENCES public.essays(id) ON DELETE CASCADE NOT NULL,
    reader_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    highlighted_text text NOT NULL,
    start_index integer NOT NULL,
    end_index integer NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Essay Reactions (Insightful, Inspiring, Powerful, Thought-provoking)
CREATE TABLE IF NOT EXISTS public.essay_reactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    essay_id uuid REFERENCES public.essays(id) ON DELETE CASCADE NOT NULL,
    reader_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reaction_type text NOT NULL CHECK (reaction_type IN ('insightful', 'inspiring', 'powerful', 'thought_provoking')),
    created_at timestamptz DEFAULT now(),
    UNIQUE(essay_id, reader_id, reaction_type)
);

-- RLS Policies
ALTER TABLE public.essays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.essay_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.essay_highlights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.essay_reactions ENABLE ROW LEVEL SECURITY;

-- Essays are readable by everyone if published, or by the author if unpublished
CREATE POLICY "Public essays are viewable by everyone" ON public.essays
    FOR SELECT USING (is_published = true OR auth.uid() = author_id);

CREATE POLICY "Authors can create essays" ON public.essays
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update their own essays" ON public.essays
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Authors can delete their own essays" ON public.essays
    FOR DELETE USING (auth.uid() = author_id);

-- Analytics are viewable by the author, and maybe public for some stats, but let's say public can view
CREATE POLICY "Analytics viewable by everyone" ON public.essay_analytics
    FOR SELECT USING (true);

-- Highlights viewable by everyone
CREATE POLICY "Highlights viewable by everyone" ON public.essay_highlights
    FOR SELECT USING (true);

CREATE POLICY "Readers can insert highlights" ON public.essay_highlights
    FOR INSERT WITH CHECK (auth.uid() = reader_id);

CREATE POLICY "Readers can delete their own highlights" ON public.essay_highlights
    FOR DELETE USING (auth.uid() = reader_id);

-- Reactions viewable by everyone
CREATE POLICY "Reactions viewable by everyone" ON public.essay_reactions
    FOR SELECT USING (true);

CREATE POLICY "Readers can insert reactions" ON public.essay_reactions
    FOR INSERT WITH CHECK (auth.uid() = reader_id);

CREATE POLICY "Readers can delete their own reactions" ON public.essay_reactions
    FOR DELETE USING (auth.uid() = reader_id);
