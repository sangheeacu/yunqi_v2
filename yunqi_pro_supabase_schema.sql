-- ============================================================
-- Yùn Qì Pro — Supabase Database Schema
-- Blossom Skin & Health · Sang Hee Park PhD
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. USERS
-- ============================================================
CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email            TEXT UNIQUE NOT NULL,
  full_name        TEXT,
  profession       TEXT,
  location         TEXT,
  avatar_url       TEXT,
  hemisphere       TEXT NOT NULL DEFAULT 'southern' CHECK (hemisphere IN ('northern','southern')),
  ui_language      TEXT NOT NULL DEFAULT 'en' CHECK (ui_language IN ('en','ko')),
  show_hanzi       TEXT NOT NULL DEFAULT 'always' CHECK (show_hanzi IN ('always','hover','hide')),
  show_pinyin      TEXT NOT NULL DEFAULT 'always' CHECK (show_pinyin IN ('always','hover','hide')),
  is_super_admin   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Super admin: sangheeacu@gmail.com은 가입 없이 자동 접근
-- auth.users와 연동 시 trigger로 자동 생성

-- Super admin 자동 설정 함수
CREATE OR REPLACE FUNCTION set_super_admin()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email = 'sangheeacu@gmail.com' THEN
    NEW.is_super_admin := TRUE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_super_admin
  BEFORE INSERT OR UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_super_admin();

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 2. SUBSCRIPTIONS
-- ============================================================
CREATE TABLE subscriptions (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stripe_customer_id   TEXT UNIQUE,
  stripe_subscription_id TEXT UNIQUE,
  plan                 TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free','monthly','annual')),
  status               TEXT NOT NULL DEFAULT 'inactive' CHECK (status IN ('trialing','active','cancelled','past_due','inactive')),
  trial_start          TIMESTAMPTZ,
  trial_end            TIMESTAMPTZ,
  current_period_start TIMESTAMPTZ,
  current_period_end   TIMESTAMPTZ,
  cancelled_at         TIMESTAMPTZ,
  cancel_reason        TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status  ON subscriptions(status);

-- ============================================================
-- 3. CHAT SESSIONS (AI Q&A)
-- ============================================================
CREATE TABLE chat_sessions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      TEXT,
  is_saved   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_chat_sessions_updated_at
  BEFORE UPDATE ON chat_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_chat_sessions_user_id ON chat_sessions(user_id);

-- ============================================================
-- 4. CHAT MESSAGES
-- ============================================================
CREATE TABLE chat_messages (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('user','assistant')),
  content    TEXT NOT NULL,
  sources    JSONB,
  tokens     INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_session_id ON chat_messages(session_id);

-- ============================================================
-- 5. SAVED ANALYSES
-- ============================================================
CREATE TABLE saved_analyses (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  year          INTEGER NOT NULL,
  hemisphere    TEXT NOT NULL DEFAULT 'southern',
  analysis_type TEXT NOT NULL DEFAULT 'annual' CHECK (analysis_type IN ('annual','personal','multi_year','southern')),
  title         TEXT,
  data          JSONB NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_saved_analyses_user_id ON saved_analyses(user_id);

-- ============================================================
-- 6. PERSONAL PROFILES (생년월일 기반 운기)
-- ============================================================
CREATE TABLE personal_profiles (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL DEFAULT 'My Profile',
  date_of_birth   DATE NOT NULL,
  birth_year_data JSONB,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_personal_profiles_updated_at
  BEFORE UPDATE ON personal_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_personal_profiles_user_id ON personal_profiles(user_id);

-- ============================================================
-- 7. PATIENTS
-- ============================================================
CREATE TABLE patients (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  full_name       TEXT NOT NULL,
  date_of_birth   DATE,
  gender          TEXT CHECK (gender IN ('male','female','other','prefer_not_to_say')),
  contact_email   TEXT,
  contact_phone   TEXT,
  birth_year_data JSONB,
  notes           TEXT,
  last_session    DATE,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_patients_updated_at
  BEFORE UPDATE ON patients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_patients_user_id   ON patients(user_id);
CREATE INDEX idx_patients_is_active ON patients(is_active);

-- ============================================================
-- 8. PATIENT SESSION NOTES
-- ============================================================
CREATE TABLE patient_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id      UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_date    DATE NOT NULL,
  chief_complaint TEXT,
  yunqi_context   JSONB,
  treatment_notes TEXT,
  acu_points      TEXT[],
  herbs           TEXT[],
  follow_up_date  DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_patient_sessions_updated_at
  BEFORE UPDATE ON patient_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_patient_sessions_patient_id ON patient_sessions(patient_id);
CREATE INDEX idx_patient_sessions_user_id    ON patient_sessions(user_id);

-- ============================================================
-- 9. NOTIFICATION SETTINGS
-- ============================================================
CREATE TABLE notification_settings (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id            UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  jieqi_alerts       BOOLEAN NOT NULL DEFAULT TRUE,
  keqi_transitions   BOOLEAN NOT NULL DEFAULT TRUE,
  weekly_briefing    BOOLEAN NOT NULL DEFAULT FALSE,
  treatment_calendar BOOLEAN NOT NULL DEFAULT TRUE,
  billing_reminders  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_notification_settings_updated_at
  BEFORE UPDATE ON notification_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 10. QUIZ PROGRESS
-- ============================================================
CREATE TABLE quiz_progress (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  module      INTEGER NOT NULL CHECK (module BETWEEN 1 AND 4),
  question_id TEXT NOT NULL,
  is_correct  BOOLEAN NOT NULL,
  answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quiz_progress_user_id ON quiz_progress(user_id);
CREATE INDEX idx_quiz_progress_module  ON quiz_progress(user_id, module);

CREATE VIEW quiz_stats AS
SELECT
  user_id,
  module,
  COUNT(*)                                        AS total_answered,
  SUM(CASE WHEN is_correct THEN 1 ELSE 0 END)    AS correct_count,
  ROUND(
    SUM(CASE WHEN is_correct THEN 1 ELSE 0 END)::NUMERIC
    / COUNT(*) * 100, 1
  )                                                AS accuracy_pct,
  MAX(answered_at)                                 AS last_activity
FROM quiz_progress
GROUP BY user_id, module;

-- ============================================================
-- 11. BILLING HISTORY
-- ============================================================
CREATE TABLE billing_history (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stripe_invoice_id TEXT UNIQUE,
  amount_cents      INTEGER NOT NULL,
  currency          TEXT NOT NULL DEFAULT 'aud',
  status            TEXT NOT NULL CHECK (status IN ('paid','pending','failed','refunded')),
  plan              TEXT,
  invoice_url       TEXT,
  period_start      TIMESTAMPTZ,
  period_end        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_billing_history_user_id ON billing_history(user_id);

-- ============================================================
-- 12. AI USAGE LOGS (Admin용)
-- ============================================================
CREATE TABLE ai_usage_logs (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID REFERENCES users(id) ON DELETE SET NULL,
  session_id        UUID REFERENCES chat_sessions(id) ON DELETE SET NULL,
  prompt_tokens     INTEGER,
  completion_tokens INTEGER,
  total_tokens      INTEGER,
  response_ms       INTEGER,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_usage_logs_user_id    ON ai_usage_logs(user_id);
CREATE INDEX idx_ai_usage_logs_created_at ON ai_usage_logs(created_at);

CREATE VIEW ai_usage_monthly AS
SELECT
  DATE_TRUNC('month', created_at) AS month,
  COUNT(*)                         AS total_queries,
  SUM(total_tokens)                AS total_tokens,
  AVG(response_ms)                 AS avg_response_ms,
  COUNT(DISTINCT user_id)          AS unique_users
FROM ai_usage_logs
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE users                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages         ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_analyses        ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients              ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_progress         ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_history       ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_logs         ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND is_super_admin = TRUE
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE POLICY users_self          ON users                 FOR ALL USING (id = auth.uid() OR is_super_admin());
CREATE POLICY subs_self           ON subscriptions         FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY chat_sessions_self  ON chat_sessions         FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY chat_messages_self  ON chat_messages         FOR ALL USING (
  session_id IN (SELECT id FROM chat_sessions WHERE user_id = auth.uid()) OR is_super_admin()
);
CREATE POLICY analyses_self       ON saved_analyses        FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY profiles_self       ON personal_profiles     FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY patients_self       ON patients              FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY patient_sessions_self ON patient_sessions    FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY notif_self          ON notification_settings FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY quiz_self           ON quiz_progress         FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY billing_self        ON billing_history       FOR ALL USING (user_id = auth.uid() OR is_super_admin());
CREATE POLICY ai_logs_admin       ON ai_usage_logs         FOR ALL USING (is_super_admin());

-- ============================================================
-- AUTO-PROVISION: 신규 가입 시 기본 레코드 자동 생성
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO users (id, email, full_name, is_super_admin)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    (NEW.email = 'sangheeacu@gmail.com')
  );

  INSERT INTO subscriptions (user_id, plan, status)
  VALUES (NEW.id, 'free', 'inactive');

  INSERT INTO notification_settings (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- ADDITIONAL INDEXES
-- ============================================================
CREATE INDEX idx_chat_sessions_created_at ON chat_sessions(created_at DESC);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at ASC);
CREATE INDEX idx_patients_name            ON patients(user_id, full_name);
CREATE INDEX idx_quiz_progress_date       ON quiz_progress(user_id, answered_at DESC);
