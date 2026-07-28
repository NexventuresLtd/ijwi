ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS wallet_pin_hash TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS wallet_biometrics_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_failed_attempts INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_locked_until TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_otp_code TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_otp_expires_at TIMESTAMP WITH TIME ZONE;
