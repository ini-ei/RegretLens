-- RegretLens スキーマ定義

-- プロフィール
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  created_at timestamptz default now()
);

alter table profiles enable row level security;
create policy "Users can view own profile" on profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on profiles for insert with check (auth.uid() = id);

-- プロフィール自動作成トリガー
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', '匿名ユーザー'));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 意思決定テーブル
create table decisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  category text not null,
  decision_text text not null,
  alternatives jsonb default '[]'::jsonb,
  context jsonb default '{}'::jsonb,
  decision_factors jsonb default '{}'::jsonb,
  predicted_regret_score real,
  risk_level text,
  warnings jsonb default '[]'::jsonb,
  source_url text,
  source_type text, -- 'amazon', 'google_maps', 'manual', etc.
  created_at timestamptz default now()
);

alter table decisions enable row level security;
create policy "Users can view own decisions" on decisions for select using (auth.uid() = user_id);
create policy "Users can insert own decisions" on decisions for insert with check (auth.uid() = user_id);
create policy "Users can update own decisions" on decisions for update using (auth.uid() = user_id);

create index idx_decisions_user_id on decisions(user_id);
create index idx_decisions_category on decisions(user_id, category);
create index idx_decisions_created_at on decisions(user_id, created_at desc);

-- フィードバックテーブル
create table feedbacks (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null references decisions on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  regret_score int not null check (regret_score between 1 and 5),
  satisfaction_score int not null check (satisfaction_score between 1 and 5),
  regret_reasons jsonb default '[]'::jsonb,
  would_change boolean default false,
  feedback_timing text,
  feedback_text text,
  created_at timestamptz default now()
);

alter table feedbacks enable row level security;
create policy "Users can view own feedbacks" on feedbacks for select using (auth.uid() = user_id);
create policy "Users can insert own feedbacks" on feedbacks for insert with check (auth.uid() = user_id);

create index idx_feedbacks_decision_id on feedbacks(decision_id);
create index idx_feedbacks_user_id on feedbacks(user_id);

-- チャットメッセージ
create table chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  decision_context jsonb,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

alter table chat_messages enable row level security;
create policy "Users can view own messages" on chat_messages for select using (auth.uid() = user_id);
create policy "Users can insert own messages" on chat_messages for insert with check (auth.uid() = user_id);

create index idx_chat_messages_user_id on chat_messages(user_id, created_at desc);

-- 後悔パターン
create table regret_patterns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  pattern_type text not null,
  trigger_conditions jsonb not null,
  average_regret real not null,
  occurrence_count int not null default 1,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table regret_patterns enable row level security;
create policy "Users can view own patterns" on regret_patterns for select using (auth.uid() = user_id);
create policy "Users can manage own patterns" on regret_patterns for all using (auth.uid() = user_id);

create index idx_regret_patterns_user_id on regret_patterns(user_id);

-- 通知スケジュール (リンク貼った商品のフォローアップ通知用)
create table scheduled_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  decision_id uuid not null references decisions on delete cascade,
  notify_at timestamptz not null,
  notification_type text not null default 'follow_up',
  message text not null,
  is_sent boolean default false,
  created_at timestamptz default now()
);

alter table scheduled_notifications enable row level security;
create policy "Users can view own notifications" on scheduled_notifications for select using (auth.uid() = user_id);
create policy "Users can manage own notifications" on scheduled_notifications for all using (auth.uid() = user_id);

create index idx_notifications_pending on scheduled_notifications(notify_at) where not is_sent;
