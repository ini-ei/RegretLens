-- RegretLens スキーマ (Neon Postgres版)
-- 認証は端末UUID。auth.users依存とRLSは無し（サーバー側でuser_idフィルタ）

-- 意思決定テーブル
create table if not exists decisions (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  category text not null,
  decision_text text not null,
  alternatives jsonb default '[]'::jsonb,
  context jsonb default '{}'::jsonb,
  decision_factors jsonb default '{}'::jsonb,
  predicted_regret_score real,
  risk_level text,
  warnings jsonb default '[]'::jsonb,
  source_url text,
  source_type text,
  created_at timestamptz default now()
);

create index if not exists idx_decisions_user_id on decisions(user_id);
create index if not exists idx_decisions_category on decisions(user_id, category);
create index if not exists idx_decisions_created_at on decisions(user_id, created_at desc);

-- フィードバックテーブル
create table if not exists feedbacks (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null references decisions on delete cascade,
  user_id text not null,
  regret_score int not null check (regret_score between 1 and 5),
  satisfaction_score int not null check (satisfaction_score between 1 and 5),
  regret_reasons jsonb default '[]'::jsonb,
  would_change boolean default false,
  feedback_timing text,
  feedback_text text,
  created_at timestamptz default now()
);

create index if not exists idx_feedbacks_decision_id on feedbacks(decision_id);
create index if not exists idx_feedbacks_user_id on feedbacks(user_id);

-- チャットメッセージ
create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  decision_context jsonb,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_chat_messages_user_id on chat_messages(user_id, created_at desc);

-- 後悔パターン
create table if not exists regret_patterns (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  pattern_type text not null,
  trigger_conditions jsonb not null,
  average_regret real not null,
  occurrence_count int not null default 1,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_regret_patterns_user_id on regret_patterns(user_id);

-- ユーザープロフィール（予算感・好み・傾向を蓄積）
create table if not exists user_profiles (
  user_id text primary key,
  budget_level text,
  preferences jsonb default '{}'::jsonb,
  notes text,
  updated_at timestamptz default now()
);

-- 通知スケジュール
create table if not exists scheduled_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  decision_id uuid not null references decisions on delete cascade,
  notify_at timestamptz not null,
  notification_type text not null default 'follow_up',
  message text not null,
  is_sent boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_notifications_pending on scheduled_notifications(notify_at) where not is_sent;
