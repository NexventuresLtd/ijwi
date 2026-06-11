-- V15: Add 'essay' content type and 'comment_like' reaction type

-- Drop and recreate content_type check constraint
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_content_type_check;
ALTER TABLE posts ADD CONSTRAINT posts_content_type_check CHECK (content_type IN (
  'story', 'devotional', 'spoken_word', 'short',
  'prayer_request', 'question', 'encouragement', 'letter', 'essay'
));

-- Drop and recreate reaction_type check constraint
ALTER TABLE reactions DROP CONSTRAINT IF EXISTS reactions_reaction_type_check;
ALTER TABLE reactions ADD CONSTRAINT reactions_reaction_type_check CHECK (reaction_type IN (
  'fire', 'amen', 'healed', 'needed', 'sharing', 'comment_like'
));
