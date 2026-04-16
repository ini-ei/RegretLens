# 論文化に向けた研究計画書

## 論文タイトル案
「個人化された後悔予測モデル：適応的特徴量選択と時系列学習によるマイクロ意思決定支援システム」
Personalized Regret Prediction Model: Adaptive Feature Selection and Temporal Learning for Micro-Decision Support

## 研究の新規性・貢献

### 1. 学術的貢献
1. **個人適応型特徴量選択アルゴリズム**
   - ユーザー毎に有効な特徴量を自動選出
   - SHAP値による解釈可能性の確保
   - Cold-start問題への対処（ベイズ最適化）

2. **時系列考慮型後悔予測モデル**
   - LSTM/GRUによる意思決定パターンの時系列学習
   - 短期・中期・長期の後悔変化を予測
   - Context-aware attention機構

3. **マルチモデルアンサンブル最適化**
   - データ量に応じた動的モデル選択
   - Random Forest / XGBoost / LSTM / ルールベースのアンサンブル
   - オンライン学習による継続的改善

4. **後悔の定量化メトリクス**
   - 多次元後悔スコア（感情的/経済的/時間的/健康的）
   - 予測精度の評価指標（MAE, RMSE, 分類精度）
   - ユーザー行動変容の定量評価

### 2. 実用的貢献
- 日常的マイクロ意思決定への機械学習応用
- 説明可能AI (XAI) による信頼性向上
- プライバシー保護型個人学習システム

## システム拡張内容

### Phase 1: モデル評価・比較フレームワーク
**ファイル**: `model_evaluator.py`

機能:
- 複数モデルの性能比較（Random Forest, XGBoost, LSTM, ルールベース）
- 交差検証（時系列対応）
- 評価指標の自動計算
  - 回帰: MAE, RMSE, R²
  - 分類: Precision, Recall, F1, AUC-ROC
  - カスタム: Regret Reduction Rate (RRR)
- 実験結果のJSON/CSV出力

### Phase 2: 適応的特徴量選択システム
**ファイル**: `adaptive_features.py`

機能:
- ユーザー毎の特徴量重要度計算（SHAP, Permutation Importance）
- 自動特徴量選択（Recursive Feature Elimination）
- Cold-start時のベイズ最適化
- 動的特徴量追加（新しいコンテキスト情報）
- 特徴量間の相互作用検出

### Phase 3: 時系列パターン学習エンジン
**ファイル**: `temporal_learner.py`

機能:
- LSTM/GRUによる意思決定シーケンス学習
- Attention機構で重要な過去決定を強調
- 短期トレンド vs 長期トレンドの分離
- 曜日・時間帯のサイクル性学習
- 季節性パターンの検出

### Phase 4: マルチモデルアンサンブル
**ファイル**: `ensemble_predictor.py`

機能:
- データ量に応じた動的モデル選択
  - 0-10件: ルールベース + ベイズ最適化
  - 10-50件: Random Forest
  - 50-100件: XGBoost
  - 100件以上: LSTM + アンサンブル
- スタッキングアンサンブル
- モデル信頼度の出力

### Phase 5: 実験・評価システム
**ファイル**: `experiment_runner.py`

機能:
- A/Bテスト管理
- ユーザー群の分割（介入群/対照群）
- 行動変容の定量評価
  - 後悔率の変化
  - 予測に従った割合
  - 長期的な満足度向上
- 実験結果の統計的検定

### Phase 6: 説明可能性モジュール
**ファイル**: `explainability.py`

機能:
- SHAP値による予測理由の可視化
- LIME による局所的説明
- Counterfactual Explanation（「もし〜だったら」分析）
- ユーザーフレンドリーな説明文生成

## データベース拡張

### 新規テーブル

```sql
-- モデル性能履歴
CREATE TABLE model_performance (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    model_type VARCHAR(50), -- 'random_forest', 'xgboost', 'lstm', 'ensemble'
    version VARCHAR(20),
    metrics JSONB, -- MAE, RMSE, R2, etc.
    training_size INTEGER,
    evaluation_date TIMESTAMP,
    created_at TIMESTAMP
);

-- 特徴量重要度
CREATE TABLE feature_importance (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    feature_name VARCHAR(100),
    importance_score FLOAT,
    method VARCHAR(50), -- 'shap', 'permutation', 'gain'
    model_type VARCHAR(50),
    created_at TIMESTAMP
);

-- 実験データ
CREATE TABLE experiments (
    id UUID PRIMARY KEY,
    experiment_name VARCHAR(255),
    user_group VARCHAR(50), -- 'control', 'intervention'
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    config JSONB,
    results JSONB,
    created_at TIMESTAMP
);

-- 予測説明
CREATE TABLE prediction_explanations (
    id UUID PRIMARY KEY,
    decision_id UUID REFERENCES decisions(id),
    shap_values JSONB,
    top_features JSONB, -- 上位3つの影響要因
    counterfactuals JSONB, -- 反実仮想シナリオ
    explanation_text TEXT,
    created_at TIMESTAMP
);

-- ユーザー行動ログ
CREATE TABLE user_behavior_logs (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    decision_id UUID REFERENCES decisions(id),
    action_type VARCHAR(50), -- 'view_prediction', 'follow_advice', 'ignore_advice'
    predicted_regret FLOAT,
    actual_regret FLOAT,
    followed_prediction BOOLEAN,
    created_at TIMESTAMP
);
```

## 評価指標

### 1. 予測精度
- Mean Absolute Error (MAE)
- Root Mean Squared Error (RMSE)
- R² Score
- 分類精度（高/中/低リスク）

### 2. ユーザー行動変容
- **Regret Reduction Rate (RRR)**
  ```
  RRR = (平均後悔度_介入前 - 平均後悔度_介入後) / 平均後悔度_介入前
  ```
- Prediction Following Rate: 予測に従った割合
- Decision Quality Improvement: 意思決定の質の向上

### 3. 個人化の効果
- User-specific Model Lift: 個人化モデルの改善度
- Feature Diversity Score: ユーザー間の特徴量重要度の多様性
- Adaptation Speed: 新規ユーザーの学習速度

### 4. 説明可能性
- Explanation Satisfaction Score: 説明への満足度
- Trust Score: システムへの信頼度

## 実験デザイン

### 実験1: モデル性能比較
- 目的: 複数の機械学習モデルの予測精度比較
- 手法: 時系列交差検証
- 比較対象: Random Forest, XGBoost, LSTM, ルールベース, アンサンブル
- 評価期間: 8週間

### 実験2: 個人化の効果検証
- 目的: 個人化特徴量選択の有効性評価
- 手法: A/Bテスト
  - A群: 全ユーザー共通特徴量
  - B群: 個人適応型特徴量
- 評価指標: MAE, RRR
- 期間: 4週間

### 実験3: 時系列学習の効果
- 目的: LSTM導入による予測精度向上の検証
- 手法: Before-After比較
- 評価指標: RMSE, 予測信頼度
- 期間: 12週間

### 実験4: ユーザー行動変容の検証
- 目的: システム使用による後悔率の減少
- 手法: 介入研究
  - 介入群: 予測結果を表示
  - 対照群: 記録のみ（予測非表示）
- 評価指標: RRR, 満足度の変化
- 期間: 8週間

## 論文構成案

### 1. Introduction
- 意思決定と後悔の心理学
- 既存研究の限界（大規模決定のみ、個人化不足）
- 本研究の貢献

### 2. Related Work
- 後悔理論（Regret Theory）
- 個人化推薦システム
- 時系列予測モデル
- 説明可能AI

### 3. Proposed Method
- システムアーキテクチャ
- 適応的特徴量選択アルゴリズム
- 時系列学習モデル
- マルチモデルアンサンブル

### 4. Implementation
- データベース設計
- 特徴量エンジニアリング
- モデル訓練プロセス

### 5. Experiments
- 実験デザイン
- データセット
- ベースライン手法
- 評価指標

### 6. Results
- モデル性能比較
- 個人化の効果
- ユーザー行動変容
- ケーススタディ

### 7. Discussion
- 発見事項
- 限界と今後の課題
- 倫理的考察

### 8. Conclusion

## 実装スケジュール

### Week 1-2: モデル評価フレームワーク
- model_evaluator.py 実装
- 交差検証システム
- 評価指標計算

### Week 3-4: 適応的特徴量選択
- adaptive_features.py 実装
- SHAP統合
- 特徴量重要度分析

### Week 5-6: 時系列学習エンジン
- temporal_learner.py 実装
- LSTM/GRU実装
- Attention機構

### Week 7-8: アンサンブルシステム
- ensemble_predictor.py 実装
- 動的モデル選択
- XGBoost統合

### Week 9-10: 実験システム
- experiment_runner.py 実装
- A/Bテスト機能
- データ収集自動化

### Week 11-12: 説明可能性モジュール
- explainability.py 実装
- SHAP可視化
- 説明文生成

### Week 13-16: 実験実施・データ収集

### Week 17-20: 論文執筆

## 必要なライブラリ追加

```
# requirements_research.txt
scikit-learn==1.3.0
xgboost==2.0.0
torch==2.0.0
shap==0.42.1
lime==0.2.0.1
optuna==3.3.0
pandas==2.0.3
numpy==1.24.3
matplotlib==3.7.2
seaborn==0.12.2
scipy==1.11.1
statsmodels==0.14.0
```

## 期待される成果

### 学術的成果
- 国際会議発表 (CHI, UIST, IUI等)
- ジャーナル論文 (Behavior & IT, TOCHI等)
- オープンソースフレームワーク公開

### 実用的成果
- 実用可能な意思決定支援システム
- 後悔予測の標準ベンチマーク
- 個人化学習のベストプラクティス
