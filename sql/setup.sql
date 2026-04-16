-- RegretLens データベーススキーマ
-- 使用方法: psql -U s2322007 -d s2322007 < setup.sql

-- UUID拡張を有効化
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 既存のテーブルを削除（初期化する場合）
DROP TABLE IF EXISTS regret_patterns CASCADE;
DROP TABLE IF EXISTS feedbacks CASCADE;
DROP TABLE IF EXISTS decisions CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ユーザーテーブル
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 意思決定テーブル
CREATE TABLE decisions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    decision_text TEXT NOT NULL,
    alternatives JSONB DEFAULT '[]'::jsonb,
    context JSONB DEFAULT '{}'::jsonb,
    decision_factors JSONB DEFAULT '{}'::jsonb,
    predicted_regret_score FLOAT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- フィードバックテーブル
CREATE TABLE feedbacks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    decision_id UUID NOT NULL REFERENCES decisions(id) ON DELETE CASCADE,
    regret_score INTEGER NOT NULL CHECK (regret_score >= 1 AND regret_score <= 5),
    satisfaction_score INTEGER NOT NULL CHECK (satisfaction_score >= 1 AND satisfaction_score <= 5),
    regret_reasons JSONB DEFAULT '[]'::jsonb,
    would_change BOOLEAN DEFAULT FALSE,
    feedback_timing VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 後悔パターンテーブル
CREATE TABLE regret_patterns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pattern_type VARCHAR(255) NOT NULL,
    trigger_conditions JSONB DEFAULT '{}'::jsonb,
    average_regret FLOAT NOT NULL,
    occurrence_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- インデックス作成
CREATE INDEX idx_decisions_user_id ON decisions(user_id);
CREATE INDEX idx_decisions_created_at ON decisions(created_at DESC);
CREATE INDEX idx_feedbacks_decision_id ON feedbacks(decision_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_regret_patterns_user_id ON regret_patterns(user_id);

-- ダミーユーザー
INSERT INTO users (id, email, password_hash, created_at)
VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'test@example.com', 'dummy_hash', CURRENT_TIMESTAMP);

-- ダミー意思決定データ（50件）
INSERT INTO decisions (id, user_id, category, decision_text, alternatives, context, decision_factors, predicted_regret_score, created_at)
VALUES
-- 2ヶ月前
('d0000001-0000-0000-0000-000000000001', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'ストレスで深夜に高級焼肉店で一人で8000円使った', '["コンビニ弁当", "我慢する", "牛丼"]'::jsonb, '{"mood": 1, "stress_level": 5, "hunger_level": 4, "time_of_day": "23:30", "day_of_week": "月曜日", "weather": "雨", "with_others": false, "budget_remaining": 5000}'::jsonb, '{"price": 8000, "taste_expectation": 4, "health_value": 2, "time_required": 60}'::jsonb, 0.85, CURRENT_TIMESTAMP - INTERVAL '60 days'),

('d0000002-0000-0000-0000-000000000002', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '買い物', 'Amazonセールで使わないキッチン家電を衝動買い（12800円）', '["様子を見る", "レビューを読む"]'::jsonb, '{"mood": 3, "stress_level": 3, "hunger_level": 3, "time_of_day": "22:00", "day_of_week": "金曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 20000}'::jsonb, '{"price": 12800, "taste_expectation": 4, "health_value": 3, "time_required": 10}'::jsonb, 0.7, CURRENT_TIMESTAMP - INTERVAL '58 days'),

('d0000003-0000-0000-0000-000000000003', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', '社食で日替わり定食380円', '["コンビニ", "弁当持参"]'::jsonb, '{"mood": 4, "stress_level": 2, "hunger_level": 4, "time_of_day": "12:15", "day_of_week": "火曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 8000}'::jsonb, '{"price": 380, "taste_expectation": 3, "health_value": 4, "time_required": 20}'::jsonb, 0.15, CURRENT_TIMESTAMP - INTERVAL '55 days'),

('d0000004-0000-0000-0000-000000000004', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '娯楽', 'ソシャゲのガチャに8000円課金', '["無課金で我慢", "月額課金のみ"]'::jsonb, '{"mood": 4, "stress_level": 4, "hunger_level": 3, "time_of_day": "01:30", "day_of_week": "土曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 15000}'::jsonb, '{"price": 8000, "taste_expectation": 5, "health_value": 3, "time_required": 5}'::jsonb, 0.9, CURRENT_TIMESTAMP - INTERVAL '52 days'),

('d0000005-0000-0000-0000-000000000005', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'コンビニでサラダと水（450円）', '["ラーメン", "定食屋"]'::jsonb, '{"mood": 4, "stress_level": 2, "hunger_level": 3, "time_of_day": "12:00", "day_of_week": "水曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 6000}'::jsonb, '{"price": 450, "taste_expectation": 2, "health_value": 5, "time_required": 10}'::jsonb, 0.3, CURRENT_TIMESTAMP - INTERVAL '50 days'),

-- 7週間前
('d0000006-0000-0000-0000-000000000006', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '買い物', 'セール品の服を3着まとめ買い（15000円）', '["1着だけ買う", "次回まで待つ"]'::jsonb, '{"mood": 5, "stress_level": 2, "hunger_level": 3, "time_of_day": "14:00", "day_of_week": "日曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 30000}'::jsonb, '{"price": 15000, "taste_expectation": 5, "health_value": 3, "time_required": 90}'::jsonb, 0.45, CURRENT_TIMESTAMP - INTERVAL '49 days'),

('d0000007-0000-0000-0000-000000000007', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '学習', '評判の良いオンラインプログラミング講座を購入（18000円）', '["無料教材", "YouTube"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 3, "time_of_day": "20:00", "day_of_week": "月曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 40000}'::jsonb, '{"price": 18000, "taste_expectation": 4, "health_value": 3, "time_required": 120}'::jsonb, 0.25, CURRENT_TIMESTAMP - INTERVAL '47 days'),

('d0000008-0000-0000-0000-000000000008', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', '疲れて駅前の高級寿司で5500円', '["回転寿司", "スーパーの寿司", "自炊"]'::jsonb, '{"mood": 2, "stress_level": 5, "hunger_level": 5, "time_of_day": "19:30", "day_of_week": "金曜日", "weather": "雨", "with_others": false, "budget_remaining": 8000}'::jsonb, '{"price": 5500, "taste_expectation": 5, "health_value": 4, "time_required": 60}'::jsonb, 0.8, CURRENT_TIMESTAMP - INTERVAL '45 days'),

('d0000009-0000-0000-0000-000000000009', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '娯楽', '映画館で話題の新作を鑑賞（2000円）', '["配信を待つ", "レンタル"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 3, "time_of_day": "19:00", "day_of_week": "土曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 10000}'::jsonb, '{"price": 2000, "taste_expectation": 4, "health_value": 3, "time_required": 150}'::jsonb, 0.2, CURRENT_TIMESTAMP - INTERVAL '42 days'),

('d0000010-0000-0000-0000-000000000010', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'ファミレスで友人とランチ（1200円）', '["カフェ", "社食"]'::jsonb, '{"mood": 5, "stress_level": 2, "hunger_level": 4, "time_of_day": "12:30", "day_of_week": "土曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 5000}'::jsonb, '{"price": 1200, "taste_expectation": 3, "health_value": 3, "time_required": 90}'::jsonb, 0.15, CURRENT_TIMESTAMP - INTERVAL '40 days'),

-- 5週間前
('d0000011-0000-0000-0000-000000000011', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '買い物', '必要な参考書2冊購入（4500円）', '["図書館で借りる", "電子書籍"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 3, "time_of_day": "15:00", "day_of_week": "木曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 12000}'::jsonb, '{"price": 4500, "taste_expectation": 4, "health_value": 3, "time_required": 30}'::jsonb, 0.2, CURRENT_TIMESTAMP - INTERVAL '35 days'),

('d0000012-0000-0000-0000-000000000012', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', '深夜にラーメン二郎でラーメン（1200円）', '["カップ麺", "我慢する"]'::jsonb, '{"mood": 3, "stress_level": 4, "hunger_level": 5, "time_of_day": "23:00", "day_of_week": "水曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 3000}'::jsonb, '{"price": 1200, "taste_expectation": 5, "health_value": 1, "time_required": 45}'::jsonb, 0.65, CURRENT_TIMESTAMP - INTERVAL '33 days'),

('d0000013-0000-0000-0000-000000000013', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '娯楽', 'カラオケで3時間歌う（1800円）', '["家で歌う", "我慢する"]'::jsonb, '{"mood": 5, "stress_level": 2, "hunger_level": 3, "time_of_day": "20:00", "day_of_week": "金曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 6000}'::jsonb, '{"price": 1800, "taste_expectation": 5, "health_value": 3, "time_required": 180}'::jsonb, 0.1, CURRENT_TIMESTAMP - INTERVAL '30 days'),

('d0000014-0000-0000-0000-000000000014', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '買い物', 'コンビニでお菓子とジュースを大量買い（1500円）', '["我慢する", "必要な分だけ"]'::jsonb, '{"mood": 3, "stress_level": 4, "hunger_level": 3, "time_of_day": "22:00", "day_of_week": "火曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 4000}'::jsonb, '{"price": 1500, "taste_expectation": 4, "health_value": 1, "time_required": 10}'::jsonb, 0.6, CURRENT_TIMESTAMP - INTERVAL '28 days'),

('d0000015-0000-0000-0000-000000000015', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'カフェで作業しながらコーヒーとケーキ（950円）', '["自宅", "図書館"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 2, "time_of_day": "14:00", "day_of_week": "土曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 5000}'::jsonb, '{"price": 950, "taste_expectation": 4, "health_value": 2, "time_required": 120}'::jsonb, 0.25, CURRENT_TIMESTAMP - INTERVAL '26 days'),

-- 3週間前
('d0000016-0000-0000-0000-000000000016', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', '牛丼チェーンで特盛（650円）', '["並盛", "自炊"]'::jsonb, '{"mood": 3, "stress_level": 3, "hunger_level": 5, "time_of_day": "13:00", "day_of_week": "月曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 3000}'::jsonb, '{"price": 650, "taste_expectation": 3, "health_value": 2, "time_required": 15}'::jsonb, 0.3, CURRENT_TIMESTAMP - INTERVAL '21 days'),

('d0000017-0000-0000-0000-000000000017', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '娯楽', 'Netflixとサブスク3つ契約更新（3500円/月）', '["1つに絞る", "無料期間だけ"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 3, "time_of_day": "21:00", "day_of_week": "日曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 15000}'::jsonb, '{"price": 3500, "taste_expectation": 4, "health_value": 3, "time_required": 10}'::jsonb, 0.4, CURRENT_TIMESTAMP - INTERVAL '20 days'),

('d0000018-0000-0000-0000-000000000018', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '仕事', '疲れて早退して帰宅', '["残業する", "持ち帰る"]'::jsonb, '{"mood": 2, "stress_level": 5, "hunger_level": 3, "time_of_day": "16:30", "day_of_week": "木曜日", "weather": "雨", "with_others": false, "budget_remaining": 5000}'::jsonb, '{"price": 0, "taste_expectation": 3, "health_value": 4, "time_required": 0}'::jsonb, 0.7, CURRENT_TIMESTAMP - INTERVAL '18 days'),

('d0000019-0000-0000-0000-000000000019', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'ファミレスでモーニングセット（680円）', '["自炊", "抜く"]'::jsonb, '{"mood": 4, "stress_level": 2, "hunger_level": 4, "time_of_day": "08:00", "day_of_week": "日曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 4000}'::jsonb, '{"price": 680, "taste_expectation": 3, "health_value": 3, "time_required": 40}'::jsonb, 0.15, CURRENT_TIMESTAMP - INTERVAL '16 days'),

('d0000020-0000-0000-0000-000000000020', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '買い物', '新作ゲームを発売日に購入（7800円）', '["セール待ち", "中古"]'::jsonb, '{"mood": 5, "stress_level": 2, "hunger_level": 3, "time_of_day": "19:00", "day_of_week": "金曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 12000}'::jsonb, '{"price": 7800, "taste_expectation": 5, "health_value": 3, "time_required": 30}'::jsonb, 0.3, CURRENT_TIMESTAMP - INTERVAL '14 days'),

-- 2週間前
('d0000021-0000-0000-0000-000000000021', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'コンビニで弁当と飲み物（750円）', '["社食", "自炊"]'::jsonb, '{"mood": 3, "stress_level": 3, "hunger_level": 4, "time_of_day": "12:30", "day_of_week": "水曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 5000}'::jsonb, '{"price": 750, "taste_expectation": 3, "health_value": 2, "time_required": 5}'::jsonb, 0.25, CURRENT_TIMESTAMP - INTERVAL '13 days'),

('d0000022-0000-0000-0000-000000000022', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '娯楽', 'ソシャゲに追加で3000円課金', '["我慢する"]'::jsonb, '{"mood": 3, "stress_level": 4, "hunger_level": 3, "time_of_day": "23:30", "day_of_week": "土曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 8000}'::jsonb, '{"price": 3000, "taste_expectation": 4, "health_value": 3, "time_required": 5}'::jsonb, 0.75, CURRENT_TIMESTAMP - INTERVAL '12 days'),

('d0000023-0000-0000-0000-000000000023', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', '焼肉食べ放題8000円', '["普通の焼肉", "別の店"]'::jsonb, '{"mood": 5, "stress_level": 2, "hunger_level": 5, "time_of_day": "18:00", "day_of_week": "日曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 10000}'::jsonb, '{"price": 8000, "taste_expectation": 4, "health_value": 2, "time_required": 120}'::jsonb, 0.35, CURRENT_TIMESTAMP - INTERVAL '10 days'),

('d0000024-0000-0000-0000-000000000024', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '買い物', 'Amazonで書籍5冊まとめ買い（8500円）', '["1冊ずつ", "電子書籍"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 3, "time_of_day": "22:00", "day_of_week": "火曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 15000}'::jsonb, '{"price": 8500, "taste_expectation": 4, "health_value": 3, "time_required": 15}'::jsonb, 0.3, CURRENT_TIMESTAMP - INTERVAL '9 days'),

('d0000025-0000-0000-0000-000000000025', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'スタバで新作フラペチーノ（780円）', '["普通のコーヒー", "コンビニ"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 2, "time_of_day": "15:00", "day_of_week": "木曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 3000}'::jsonb, '{"price": 780, "taste_expectation": 4, "health_value": 2, "time_required": 20}'::jsonb, 0.2, CURRENT_TIMESTAMP - INTERVAL '8 days'),

-- 1週間前
('d0000026-0000-0000-0000-000000000026', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'イタリアンでパスタランチ（1500円）', '["社食", "弁当"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 4, "time_of_day": "12:00", "day_of_week": "金曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 6000}'::jsonb, '{"price": 1500, "taste_expectation": 4, "health_value": 3, "time_required": 60}'::jsonb, 0.25, CURRENT_TIMESTAMP - INTERVAL '7 days'),

('d0000027-0000-0000-0000-000000000027', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '娯楽', 'ゲームセンターで2000円使う', '["我慢する"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 3, "time_of_day": "19:00", "day_of_week": "土曜日", "weather": "晴れ", "with_others": true, "budget_remaining": 5000}'::jsonb, '{"price": 2000, "taste_expectation": 4, "health_value": 3, "time_required": 90}'::jsonb, 0.5, CURRENT_TIMESTAMP - INTERVAL '6 days'),

('d0000028-0000-0000-0000-000000000028', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'コンビニでサラダチキンとプロテイン（550円）', '["普通の弁当"]'::jsonb, '{"mood": 4, "stress_level": 2, "hunger_level": 3, "time_of_day": "12:30", "day_of_week": "月曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 4000}'::jsonb, '{"price": 550, "taste_expectation": 2, "health_value": 5, "time_required": 5}'::jsonb, 0.15, CURRENT_TIMESTAMP - INTERVAL '5 days'),

('d0000029-0000-0000-0000-000000000029', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '買い物', 'ユニクロでTシャツ3枚（4500円）', '["1枚だけ", "セール待ち"]'::jsonb, '{"mood": 4, "stress_level": 2, "hunger_level": 3, "time_of_day": "16:00", "day_of_week": "日曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 10000}'::jsonb, '{"price": 4500, "taste_expectation": 3, "health_value": 3, "time_required": 45}'::jsonb, 0.2, CURRENT_TIMESTAMP - INTERVAL '4 days'),

('d0000030-0000-0000-0000-000000000030', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', '疲れて出前でピザ（2800円）', '["自炊", "コンビニ"]'::jsonb, '{"mood": 2, "stress_level": 5, "hunger_level": 4, "time_of_day": "20:30", "day_of_week": "火曜日", "weather": "雨", "with_others": false, "budget_remaining": 5000}'::jsonb, '{"price": 2800, "taste_expectation": 4, "health_value": 2, "time_required": 40}'::jsonb, 0.6, CURRENT_TIMESTAMP - INTERVAL '3 days'),

-- 最近
('d0000031-0000-0000-0000-000000000031', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'ラーメン屋で特製ラーメン大盛り（1100円）', '["普通盛り", "別の店"]'::jsonb, '{"mood": 4, "stress_level": 3, "hunger_level": 5, "time_of_day": "13:00", "day_of_week": "水曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 4000}'::jsonb, '{"price": 1100, "taste_expectation": 4, "health_value": 2, "time_required": 30}'::jsonb, 0.2, CURRENT_TIMESTAMP - INTERVAL '2 days'),

('d0000032-0000-0000-0000-000000000032', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '娯楽', '漫画の新刊を10冊まとめ買い（5000円）', '["電子版", "数冊ずつ"]'::jsonb, '{"mood": 5, "stress_level": 2, "hunger_level": 3, "time_of_day": "18:00", "day_of_week": "木曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 8000}'::jsonb, '{"price": 5000, "taste_expectation": 5, "health_value": 3, "time_required": 20}'::jsonb, 0.15, CURRENT_TIMESTAMP - INTERVAL '1 day'),

('d0000033-0000-0000-0000-000000000033', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '食事', 'コンビニでおにぎり2個とお茶（350円）', '["弁当", "社食"]'::jsonb, '{"mood": 3, "stress_level": 3, "hunger_level": 3, "time_of_day": "12:00", "day_of_week": "金曜日", "weather": "晴れ", "with_others": false, "budget_remaining": 3000}'::jsonb, '{"price": 350, "taste_expectation": 2, "health_value": 3, "time_required": 5}'::jsonb, 0.3, CURRENT_TIMESTAMP - INTERVAL '12 hours');

-- フィードバックデータ（詳細な理由付き）
INSERT INTO feedbacks (id, decision_id, regret_score, satisfaction_score, regret_reasons, would_change, feedback_timing, created_at)
VALUES
('f0000001-0000-0000-0000-000000000001', 'd0000001-0000-0000-0000-000000000001', 5, 1, '["一人で高い店に入って虚しくなった", "翌日胃もたれがひどかった", "8000円あれば他に使い道があった", "ストレス解消にならなかった"]'::jsonb, true, '1日後', CURRENT_TIMESTAMP - INTERVAL '59 days'),

('f0000002-0000-0000-0000-000000000002', 'd0000002-0000-0000-0000-000000000002', 5, 1, '["結局一度も使っていない", "置き場所に困る", "衝動買いだった", "12800円が完全に無駄になった"]'::jsonb, true, '1週間後', CURRENT_TIMESTAMP - INTERVAL '51 days'),

('f0000003-0000-0000-0000-000000000003', 'd0000003-0000-0000-0000-000000000003', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '55 days'),

('f0000004-0000-0000-0000-000000000004', 'd0000004-0000-0000-0000-000000000004', 5, 2, '["お目当てのキャラが出なかった", "何も残らない虚無感", "8000円を一瞬で溶かした", "次の日めちゃくちゃ後悔した"]'::jsonb, true, '1日後', CURRENT_TIMESTAMP - INTERVAL '51 days'),

('f0000005-0000-0000-0000-000000000005', 'd0000005-0000-0000-0000-000000000005', 2, 4, '["14時くらいにお腹空いた"]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '50 days'),

('f0000006-0000-0000-0000-000000000006', 'd0000006-0000-0000-0000-000000000006', 3, 3, '["1着は微妙だった", "全部は着きれない", "予算オーバーだった"]'::jsonb, false, '1週間後', CURRENT_TIMESTAMP - INTERVAL '42 days'),

('f0000007-0000-0000-0000-000000000007', 'd0000007-0000-0000-0000-000000000007', 2, 4, '["まだ途中までしか見てない", "無料教材でもよかったかも"]'::jsonb, false, '1週間後', CURRENT_TIMESTAMP - INTERVAL '40 days'),

('f0000008-0000-0000-0000-000000000008', 'd0000008-0000-0000-0000-000000000008', 5, 2, '["高すぎた", "回転寿司で十分だった", "疲れてる時の判断ミス", "5500円は痛い出費"]'::jsonb, true, '1日後', CURRENT_TIMESTAMP - INTERVAL '44 days'),

('f0000009-0000-0000-0000-000000000009', 'd0000009-0000-0000-0000-000000000009', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '42 days'),

('f0000010-0000-0000-0000-000000000010', 'd0000010-0000-0000-0000-000000000010', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '40 days'),

('f0000011-0000-0000-0000-000000000011', 'd0000011-0000-0000-0000-000000000011', 1, 5, '[]'::jsonb, false, '1週間後', CURRENT_TIMESTAMP - INTERVAL '28 days'),

('f0000012-0000-0000-0000-000000000012', 'd0000012-0000-0000-0000-000000000012', 4, 3, '["翌日胃もたれ", "深夜に食べると後悔する", "健康に悪い"]'::jsonb, true, '1日後', CURRENT_TIMESTAMP - INTERVAL '32 days'),

('f0000013-0000-0000-0000-000000000013', 'd0000013-0000-0000-0000-000000000013', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '30 days'),

('f0000014-0000-0000-0000-000000000014', 'd0000014-0000-0000-0000-000000000014', 4, 2, '["食べきれなかった", "無駄遣い", "健康に悪い", "ストレス買いだった"]'::jsonb, true, '1日後', CURRENT_TIMESTAMP - INTERVAL '27 days'),

('f0000015-0000-0000-0000-000000000015', 'd0000015-0000-0000-0000-000000000015', 2, 4, '["図書館でもよかった"]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '26 days'),

('f0000016-0000-0000-0000-000000000016', 'd0000016-0000-0000-0000-000000000016', 2, 4, '["食べすぎて眠くなった"]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '21 days'),

('f0000017-0000-0000-0000-000000000017', 'd0000017-0000-0000-0000-000000000017', 3, 3, '["Netflix以外ほとんど見てない", "1つに絞るべきだった"]'::jsonb, false, '1週間後', CURRENT_TIMESTAMP - INTERVAL '13 days'),

('f0000018-0000-0000-0000-000000000018', 'd0000018-0000-0000-0000-000000000018', 5, 1, '["結局休日に終わらせる羽目になった", "上司の評価が下がった", "仕事が溜まって大変だった", "逃げても解決しない"]'::jsonb, true, '1日後', CURRENT_TIMESTAMP - INTERVAL '17 days'),

('f0000019-0000-0000-0000-000000000019', 'd0000019-0000-0000-0000-000000000019', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '16 days'),

('f0000020-0000-0000-0000-000000000020', 'd0000020-0000-0000-0000-000000000020', 2, 4, '["まだクリアしてない", "セール待てばよかった"]'::jsonb, false, '1週間後', CURRENT_TIMESTAMP - INTERVAL '7 days'),

('f0000021-0000-0000-0000-000000000021', 'd0000021-0000-0000-0000-000000000021', 2, 3, '["社食の方が安かった"]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '13 days'),

('f0000022-0000-0000-0000-000000000022', 'd0000022-0000-0000-0000-000000000022', 5, 1, '["また出なかった", "ガチャに課金するのやめる", "3000円が無駄", "自己嫌悪"]'::jsonb, true, '直後', CURRENT_TIMESTAMP - INTERVAL '12 days'),

('f0000023-0000-0000-0000-000000000023', 'd0000023-0000-0000-0000-000000000023', 2, 4, '["食べすぎた", "もう少し安い店でもよかった"]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '10 days'),

('f0000024-0000-0000-0000-000000000024', 'd0000024-0000-0000-0000-000000000024', 2, 4, '["まだ2冊しか読んでない"]'::jsonb, false, '1週間後', CURRENT_TIMESTAMP - INTERVAL '2 days'),

('f0000025-0000-0000-0000-000000000025', 'd0000025-0000-0000-0000-000000000025', 2, 4, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '8 days'),

('f0000026-0000-0000-0000-000000000026', 'd0000026-0000-0000-0000-000000000026', 2, 4, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '7 days'),

('f0000027-0000-0000-0000-000000000027', 'd0000027-0000-0000-0000-000000000027', 3, 3, '["UFOキャッチャーで1500円使って取れなかった", "もったいなかった"]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '6 days'),

('f0000028-0000-0000-0000-000000000028', 'd0000028-0000-0000-0000-000000000028', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '5 days'),

('f0000029-0000-0000-0000-000000000029', 'd0000029-0000-0000-0000-000000000029', 1, 5, '[]'::jsonb, false, '1週間後', CURRENT_TIMESTAMP - INTERVAL '3 days'),

('f0000030-0000-0000-0000-000000000030', 'd0000030-0000-0000-0000-000000000030', 4, 2, '["高かった", "自炊すればよかった", "疲れてる時の判断ミス", "ピザ代が痛い"]'::jsonb, true, '1日後', CURRENT_TIMESTAMP - INTERVAL '2 days'),

('f0000031-0000-0000-0000-000000000031', 'd0000031-0000-0000-0000-000000000031', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '2 days'),

('f0000032-0000-0000-0000-000000000032', 'd0000032-0000-0000-0000-000000000032', 1, 5, '[]'::jsonb, false, '直後', CURRENT_TIMESTAMP - INTERVAL '1 day');

COMMENT ON TABLE users IS 'ユーザー情報を管理するテーブル';
COMMENT ON TABLE decisions IS 'ユーザーの意思決定を記録するテーブル';
COMMENT ON TABLE feedbacks IS '意思決定に対するフィードバックを記録するテーブル';
COMMENT ON TABLE regret_patterns IS '後悔パターン分析結果を保存するテーブル';
