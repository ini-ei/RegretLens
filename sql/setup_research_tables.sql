-- RegretLens 研究用テーブル拡張
-- 論文実験のためのデータ収集・評価テーブル

-- モデル性能履歴テーブル
CREATE TABLE IF NOT EXISTS model_performance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    model_type VARCHAR(50) NOT NULL, -- 'random_forest', 'xgboost', 'lstm', 'gru', 'rule_based', 'ensemble'
    model_version VARCHAR(20),
    metrics JSONB DEFAULT '{}'::jsonb, -- MAE, RMSE, R2, etc.
    training_size INTEGER,
    test_size INTEGER,
    cross_validation_folds INTEGER,
    evaluation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_model_performance_user ON model_performance(user_id);
CREATE INDEX idx_model_performance_type ON model_performance(model_type);
CREATE INDEX idx_model_performance_date ON model_performance(evaluation_date DESC);

COMMENT ON TABLE model_performance IS 'モデル性能評価の履歴';
COMMENT ON COLUMN model_performance.metrics IS 'JSON形式の評価指標 {mae, rmse, r2, precision, recall, f1}';

-- 特徴量重要度テーブル
CREATE TABLE IF NOT EXISTS feature_importance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    feature_name VARCHAR(100) NOT NULL,
    importance_score FLOAT NOT NULL,
    importance_rank INTEGER,
    method VARCHAR(50) NOT NULL, -- 'shap', 'permutation', 'gain', 'rfe'
    model_type VARCHAR(50) NOT NULL,
    training_samples INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_feature_importance_user ON feature_importance(user_id);
CREATE INDEX idx_feature_importance_feature ON feature_importance(feature_name);
CREATE INDEX idx_feature_importance_score ON feature_importance(importance_score DESC);

COMMENT ON TABLE feature_importance IS '個人化特徴量重要度の記録';
COMMENT ON COLUMN feature_importance.method IS '重要度計算手法';

-- 実験データテーブル
CREATE TABLE IF NOT EXISTS experiments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    experiment_name VARCHAR(255) NOT NULL,
    experiment_type VARCHAR(50) NOT NULL, -- 'model_comparison', 'ab_test', 'feature_selection', 'temporal'
    description TEXT,
    user_group VARCHAR(50), -- 'control', 'intervention', 'all'
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    config JSONB DEFAULT '{}'::jsonb, -- 実験設定
    results JSONB DEFAULT '{}'::jsonb, -- 実験結果
    status VARCHAR(20) DEFAULT 'running', -- 'running', 'completed', 'failed'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_experiments_type ON experiments(experiment_type);
CREATE INDEX idx_experiments_status ON experiments(status);
CREATE INDEX idx_experiments_dates ON experiments(start_date, end_date);

COMMENT ON TABLE experiments IS '論文実験の管理・記録';
COMMENT ON COLUMN experiments.config IS '実験パラメータ設定 {model_type, features, hyperparameters}';
COMMENT ON COLUMN experiments.results IS '実験結果データ {metrics, conclusions, visualizations}';

-- 予測説明テーブル
CREATE TABLE IF NOT EXISTS prediction_explanations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    decision_id UUID REFERENCES decisions(id) ON DELETE CASCADE,
    model_type VARCHAR(50) NOT NULL,
    predicted_score FLOAT,
    shap_values JSONB, -- SHAP値 {feature_name: shap_value}
    top_features JSONB, -- 上位影響要因 [{feature, importance, direction}]
    counterfactuals JSONB, -- 反実仮想シナリオ [{change, predicted_outcome}]
    explanation_text TEXT, -- 人間が読める説明文
    confidence_score FLOAT, -- 予測信頼度 0-1
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prediction_explanations_decision ON prediction_explanations(decision_id);
CREATE INDEX idx_prediction_explanations_model ON prediction_explanations(model_type);

COMMENT ON TABLE prediction_explanations IS '予測の説明可能性データ（XAI）';
COMMENT ON COLUMN prediction_explanations.shap_values IS 'SHAP値による特徴量貢献度';
COMMENT ON COLUMN prediction_explanations.counterfactuals IS '「もし〜だったら」分析結果';

-- ユーザー行動ログテーブル
CREATE TABLE IF NOT EXISTS user_behavior_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    decision_id UUID REFERENCES decisions(id) ON DELETE CASCADE,
    action_type VARCHAR(50) NOT NULL, -- 'view_prediction', 'follow_advice', 'ignore_advice', 'view_explanation'
    predicted_regret FLOAT,
    actual_regret FLOAT,
    followed_prediction BOOLEAN,
    explanation_viewed BOOLEAN DEFAULT FALSE,
    time_to_decision INTEGER, -- 意思決定までの時間（秒）
    session_id VARCHAR(100), -- セッションID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_behavior_user ON user_behavior_logs(user_id);
CREATE INDEX idx_user_behavior_decision ON user_behavior_logs(decision_id);
CREATE INDEX idx_user_behavior_action ON user_behavior_logs(action_type);
CREATE INDEX idx_user_behavior_followed ON user_behavior_logs(followed_prediction);

COMMENT ON TABLE user_behavior_logs IS 'ユーザーの行動追跡（実験評価用）';
COMMENT ON COLUMN user_behavior_logs.followed_prediction IS 'ユーザーが予測に従ったか';
COMMENT ON COLUMN user_behavior_logs.time_to_decision IS '予測表示から決定までの時間';

-- A/Bテスト割り当てテーブル
CREATE TABLE IF NOT EXISTS ab_test_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    experiment_id UUID REFERENCES experiments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    test_group VARCHAR(20) NOT NULL, -- 'A', 'B', 'control', 'treatment'
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(experiment_id, user_id)
);

CREATE INDEX idx_ab_test_experiment ON ab_test_assignments(experiment_id);
CREATE INDEX idx_ab_test_user ON ab_test_assignments(user_id);
CREATE INDEX idx_ab_test_group ON ab_test_assignments(test_group);

COMMENT ON TABLE ab_test_assignments IS 'A/Bテストのユーザー割り当て';

-- 実験参加者テーブル（データ収集同意管理）
CREATE TABLE IF NOT EXISTS research_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    consent_given BOOLEAN DEFAULT FALSE,
    consent_date TIMESTAMP WITH TIME ZONE,
    participant_group VARCHAR(50), -- 'student', 'general', 'control'
    demographic_data JSONB, -- 年齢、性別など（匿名化）
    withdrawal_date TIMESTAMP WITH TIME ZONE, -- 同意撤回日
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_research_participants_consent ON research_participants(consent_given);
CREATE INDEX idx_research_participants_group ON research_participants(participant_group);

COMMENT ON TABLE research_participants IS '研究参加者管理（倫理配慮）';
COMMENT ON COLUMN research_participants.consent_given IS 'データ使用への同意';

-- サンプル実験データの挿入
INSERT INTO experiments (experiment_name, experiment_type, description, user_group, start_date, status, config)
VALUES
(
    'モデル性能比較実験',
    'model_comparison',
    'Random Forest, XGBoost, LSTM, ルールベースの予測精度を比較',
    'all',
    CURRENT_TIMESTAMP,
    'running',
    '{"models": ["random_forest", "xgboost", "lstm", "rule_based"], "cv_folds": 5, "metrics": ["mae", "rmse", "r2"]}'::jsonb
),
(
    '個人化特徴量選択の効果検証',
    'ab_test',
    'A群: 共通特徴量 vs B群: 個人化特徴量による予測精度の差',
    'intervention',
    CURRENT_TIMESTAMP,
    'running',
    '{"group_a": "common_features", "group_b": "personalized_features", "duration_weeks": 4}'::jsonb
);

-- ビュー: 実験結果サマリー
CREATE OR REPLACE VIEW experiment_summary AS
SELECT
    e.id,
    e.experiment_name,
    e.experiment_type,
    e.status,
    e.start_date,
    e.end_date,
    COUNT(DISTINCT ub.user_id) as participant_count,
    COUNT(ub.id) as total_decisions,
    AVG(ub.predicted_regret) as avg_predicted_regret,
    AVG(ub.actual_regret) as avg_actual_regret,
    AVG(CASE WHEN ub.followed_prediction THEN 1 ELSE 0 END) as follow_rate
FROM experiments e
LEFT JOIN user_behavior_logs ub ON ub.created_at BETWEEN e.start_date AND COALESCE(e.end_date, CURRENT_TIMESTAMP)
GROUP BY e.id, e.experiment_name, e.experiment_type, e.status, e.start_date, e.end_date;

COMMENT ON VIEW experiment_summary IS '実験結果の集計ビュー';

-- 関数: Regret Reduction Rate (RRR) 計算
CREATE OR REPLACE FUNCTION calculate_rrr(
    p_user_id UUID,
    p_before_date TIMESTAMP,
    p_after_date TIMESTAMP
) RETURNS FLOAT AS $$
DECLARE
    avg_before FLOAT;
    avg_after FLOAT;
    rrr FLOAT;
BEGIN
    -- 介入前の平均後悔度
    SELECT AVG(f.regret_score)
    INTO avg_before
    FROM feedbacks f
    JOIN decisions d ON f.decision_id = d.id
    WHERE d.user_id = p_user_id
      AND f.created_at < p_before_date;

    -- 介入後の平均後悔度
    SELECT AVG(f.regret_score)
    INTO avg_after
    FROM feedbacks f
    JOIN decisions d ON f.decision_id = d.id
    WHERE d.user_id = p_user_id
      AND f.created_at >= p_after_date;

    -- RRR計算
    IF avg_before IS NOT NULL AND avg_before > 0 THEN
        rrr := (avg_before - COALESCE(avg_after, avg_before)) / avg_before;
    ELSE
        rrr := 0;
    END IF;

    RETURN rrr;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_rrr IS 'Regret Reduction Rateを計算（論文評価指標）';
