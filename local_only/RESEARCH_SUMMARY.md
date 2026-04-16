# RegretLens 論文化プロジェクト - 実装サマリー

## プロジェクト概要

**システム名**: RegretLens
**論文タイトル**: 「個人化された後悔予測モデル：適応的特徴量選択と時系列学習によるマイクロ意思決定支援システム」
**目標**: 国際会議・ジャーナル論文として発表可能なレベルの学術研究システム

---

## 実装完了機能（2025年10月15日時点）

### 1. 研究計画書
**ファイル**: `local_only/research_plan.md`

- 論文の学術的貢献の明確化
- 4つの主要実験デザイン
- 評価指標の定義（RRR, MAE, RMSE等）
- 実装スケジュール（週単位）
- 論文構成案（8セクション）

### 2. モデル評価・比較フレームワーク ✅
**ファイル**: `model_evaluator.py` (294行)

#### 実装機能:
- **時系列交差検証**: `TimeSeriesSplit`による過去データ漏洩防止
- **複数モデル比較**: Random Forest, XGBoost, ルールベース
- **回帰評価**: MAE, RMSE, R²
- **分類評価**: Accuracy, Precision, Recall, F1-score（3クラス）
- **行動変容評価**: Regret Reduction Rate (RRR) + t検定
- **予測追従率**: 高リスク時の予測追従行動分析
- **自動レポート生成**: モデル性能ランキング出力

#### 使用例:
```python
from model_evaluator import ModelEvaluator, run_experiment_comparison

evaluator = ModelEvaluator(user_id)
results = evaluator.time_series_cross_validation(history, feedbacks, n_splits=5)
print(evaluator.generate_comparison_report(results))
```

#### 評価指標:
```python
# 回帰指標
MAE (Mean Absolute Error)
RMSE (Root Mean Squared Error)
R² Score

# 行動変容指標（独自）
RRR = (後悔度_前 - 後悔度_後) / 後悔度_前
Prediction Following Rate
Statistical Significance (p < 0.05)
```

### 3. 適応的特徴量選択システム ✅
**ファイル**: `adaptive_features.py` (402行)

#### 実装機能:
- **SHAP値計算**: TreeExplainerによる解釈可能な特徴量重要度
- **Permutation Importance**: モデル非依存の頑健性評価
- **RFE**: Recursive Feature Eliminationによる自動選択
- **SelectKBest**: F統計量ベースの統計的選択
- **適応的選択**: ユーザー毎に最適な特徴量セット決定
- **特徴量説明**: 日本語での特徴量の意味説明
- **重要度レポート**: ランキング形式での可視化

#### 使用例:
```python
from adaptive_features import AdaptiveFeatureSelector, analyze_user_specific_features

selector = AdaptiveFeatureSelector(user_id)
result = selector.adaptive_feature_selection(
    history, feedbacks,
    method='shap',  # or 'permutation', 'rfe', 'kbest', 'auto'
    n_features=12
)
print(result['selected_features'])
print(selector.generate_feature_importance_report())
```

#### 特徴量選択手法:
| 手法 | 特徴 | 計算コスト |
|-----|------|----------|
| SHAP | 最も解釈可能、ゲーム理論ベース | 高 |
| Permutation | モデル非依存、頑健 | 中 |
| RFE | 再帰的削減、精度重視 | 高 |
| SelectKBest | 統計的、高速 | 低 |

### 4. 時系列パターン学習エンジン ✅
**ファイル**: `temporal_learner.py` (451行)

#### 実装機能:
- **LSTMモデル**: 2層LSTM + Attention機構
- **GRUモデル**: LSTM軽量版（計算効率重視）
- **シーケンス学習**: 過去N個の意思決定から次を予測
- **Attention重み**: 重要な過去決定を自動強調
- **モデル保存・読込**: PyTorchチェックポイント管理
- **訓練ループ**: Adam最適化、MSE損失関数
- **予測API**: リアルタイム後悔リスク予測

#### アーキテクチャ:
```python
# LSTMモデル構造
Input (sequence_length=10, features=18)
  ↓
LSTM Layer 1 (hidden_size=64)
  ↓
LSTM Layer 2 (hidden_size=64)
  ↓
Attention Mechanism (重み付き平均)
  ↓
FC Layer 1 (64 → 32) + ReLU + Dropout
  ↓
FC Layer 2 (32 → 1) + Sigmoid
  ↓
Output (0-1の後悔スコア)
```

#### 使用例:
```python
from temporal_learner import TemporalLearner

learner = TemporalLearner(user_id, model_type='lstm', sequence_length=10)
result = learner.train_model(history, feedbacks, epochs=50, batch_size=8)
prediction = learner.predict(history, feedbacks)
print(f"Predicted regret: {prediction['regret_score']}")
```

### 5. 研究用データベース拡張 ✅
**ファイル**: `setup_research_tables.sql` (232行)

#### 新規テーブル (7つ):

1. **model_performance**: モデル性能履歴
   - 交差検証結果の記録
   - 時系列での精度変化追跡

2. **feature_importance**: 特徴量重要度
   - ユーザー毎の個人化データ
   - SHAP/Permutation値の保存

3. **experiments**: 実験管理
   - A/Bテスト設定
   - 実験結果のJSON保存
   - ステータス管理

4. **prediction_explanations**: 予測説明（XAI）
   - SHAP値詳細
   - 反実仮想シナリオ
   - 説明文生成

5. **user_behavior_logs**: ユーザー行動追跡
   - 予測追従率計算
   - 意思決定時間測定
   - セッション管理

6. **ab_test_assignments**: A/Bテスト割り当て
   - グループ分け管理
   - 実験参加者追跡

7. **research_participants**: 研究参加者
   - 同意管理（倫理配慮）
   - 匿名化された属性データ

#### カスタム関数:
```sql
-- RRR計算用PostgreSQL関数
SELECT calculate_rrr(user_id, '2025-01-01', '2025-10-01');
-- 介入前後の後悔度減少率を自動計算
```

### 6. Webインターフェース拡張 ✅
**ファイル**: `myapp.py` (更新)

#### 新規エンドポイント:
```
GET/POST /research/evaluate
→ モデル性能比較実験を実行
→ 結果をJSON/HTMLで表示
```

---

## 技術スタック

### 機械学習
- **scikit-learn**: Random Forest, StandardScaler, 交差検証
- **XGBoost** (オプション): 勾配ブースティング
- **PyTorch** (オプション): LSTM/GRU深層学習
- **SHAP** (オプション): 説明可能AI

### バックエンド
- **Flask**: Webフレームワーク
- **PostgreSQL**: リレーショナルDB (JSONB活用)
- **psycopg2**: Python-PostgreSQL接続

### データ分析
- **NumPy**: 数値計算
- **SciPy**: 統計的検定
- **pandas** (推奨): データ操作

---

## 学術的新規性

### 1. 個人適応型特徴量選択
**貢献**: ユーザー毎に異なる後悔要因を自動検出

- 既存研究: 全ユーザー共通の特徴量
- 本研究: SHAP値ベースの個人化
- 効果: 予測精度向上 + 解釈可能性確保

### 2. 時系列考慮型予測
**貢献**: 過去の意思決定パターンを学習

- 既存研究: 単発の意思決定のみ
- 本研究: LSTM/Attention機構
- 効果: コンテキスト依存の予測

### 3. マイクロ意思決定への応用
**貢献**: 日常的な小さな選択に特化

- 既存研究: 投資・医療等の大規模決定
- 本研究: ランチ・買い物・時間管理
- 効果: 頻度の高い累積的影響

### 4. 行動変容の定量評価
**貢献**: Regret Reduction Rate (RRR) 指標

- 既存研究: 予測精度のみ
- 本研究: 実際の行動変化を測定
- 効果: システムの実用性証明

---

## 実験デザイン

### 実験1: モデル性能比較
**目的**: 複数手法の予測精度比較
**手法**: 時系列5分割交差検証
**比較対象**: Random Forest, XGBoost, LSTM, ルールベース
**評価**: MAE, RMSE, R²

### 実験2: 個人化の効果検証
**目的**: 特徴量選択の有効性評価
**手法**: A/Bテスト (4週間)
- A群: 全ユーザー共通18特徴量
- B群: 個人化12特徴量
**評価**: MAE改善率, RRR

### 実験3: 時系列学習の効果
**目的**: LSTM導入による精度向上
**手法**: Before-After比較
**評価**: RMSE, 予測信頼度

### 実験4: ユーザー行動変容
**目的**: システム使用による後悔減少
**手法**: 介入研究 (8週間)
- 介入群: 予測表示
- 対照群: 記録のみ
**評価**: RRR, 統計的有意性 (t検定)

---

## ファイル構成（最新）

```
senmon3/
├── myapp.py                      # Flaskアプリ本体（拡張済み）
├── ml_engine.py                  # 既存MLエンジン
├── pattern_analyzer.py           # 既存パターン分析
│
├── model_evaluator.py            # ✨ モデル評価フレームワーク (NEW)
├── adaptive_features.py          # ✨ 適応的特徴量選択 (NEW)
├── temporal_learner.py           # ✨ 時系列学習 LSTM/GRU (NEW)
│
├── setup.sql                     # 既存DB
├── setup_research_tables.sql     # ✨ 研究用DB拡張 (NEW)
│
├── local_only/
│   ├── docs.md                   # システム設計書（更新済み）
│   ├── research_plan.md          # ✨ 研究計画書 (NEW)
│   ├── RESEARCH_SUMMARY.md       # ✨ このファイル (NEW)
│   ├── requirements.txt          # 基本パッケージ
│   └── README.md
│
├── models/                       # MLモデル保存先
│   ├── model_{user_id}.pkl       # Random Forest
│   ├── feature_selection_{user_id}_{date}.json  # 特徴量選択結果
│   └── temporal_lstm_{user_id}.pth              # PyTorchモデル
│
├── evaluation_results/           # ✨ 実験結果保存 (NEW)
│   └── {experiment}_{user}_{date}.json
│
└── templates/
    ├── research_evaluate.html    # 実験UI（予定）
    └── research_results.html     # 結果表示（予定）
```

---

## セットアップ手順

### 1. 研究用パッケージインストール
```bash
# 必須
pip3 install scikit-learn numpy scipy

# 高度な機能用（推奨）
pip3 install xgboost shap torch pandas matplotlib seaborn

# requirements_research.txt にまとめる
cat > requirements_research.txt << EOF
Flask==3.0.0
psycopg2-binary==2.9.9
scikit-learn==1.3.0
xgboost==2.0.0
torch==2.0.0
shap==0.42.1
scipy==1.11.1
pandas==2.0.3
numpy==1.24.3
matplotlib==3.7.2
seaborn==0.12.2
EOF

pip3 install -r requirements_research.txt
```

### 2. 研究用テーブル作成
```bash
psql -U s2322007 -d s2322007 < setup_research_tables.sql
```

### 3. モデル評価実験の実行
```python
# Python対話シェルまたはスクリプト
from model_evaluator import run_experiment_comparison
from myapp import get_db_connection, FIXED_USER_ID

# データ取得
conn = get_db_connection()
cur = conn.cursor()
cur.execute("SELECT * FROM decisions WHERE user_id = %s", (FIXED_USER_ID,))
history = cur.fetchall()
# ... フィードバック取得 ...

# 実験実行
results = run_experiment_comparison(FIXED_USER_ID, history, feedbacks)
```

### 4. 特徴量分析の実行
```python
from adaptive_features import analyze_user_specific_features

result = analyze_user_specific_features(FIXED_USER_ID, history, feedbacks)
print(result['selected_features'])
```

### 5. LSTM訓練の実行
```python
from temporal_learner import TemporalLearner

learner = TemporalLearner(FIXED_USER_ID, model_type='lstm')
training_result = learner.train_model(history, feedbacks, epochs=50)
print(f"Final loss: {training_result['final_loss']}")
```

---

## 論文執筆に必要な次のステップ

### 短期（1-2週間）
- [ ] サンプルサイズ拡大（現33件 → 200件以上）
- [ ] 実験UIの実装（templates/research_*.html）
- [ ] 可視化機能追加（matplotlib/seaborn）
- [ ] 統計的検定の自動化

### 中期（1-2ヶ月）
- [ ] 実験1-4の実施とデータ収集
- [ ] ベースライン手法の実装
- [ ] クロスユーザー検証
- [ ] ケーススタディ作成

### 長期（3-6ヶ月）
- [ ] 論文執筆（Introduction, Related Work, Method, Experiments, Results, Discussion, Conclusion）
- [ ] 図表作成（モデル図、実験結果グラフ）
- [ ] 国際会議投稿（CHI, UIST, IUI等）
- [ ] オープンソース公開準備

---

## 期待される成果

### 学術的成果
- **国際会議論文**: CHI 2026, UIST 2026, IUI 2026
- **ジャーナル論文**: Behavior & Information Technology, TOCHI
- **引用価値**: 個人化ML + 後悔理論 + XAI の融合
- **ベンチマーク**: 後悔予測の標準データセット

### 実用的成果
- **実用システム**: 実際に使える意思決定支援ツール
- **オープンソース**: GitHub公開 → 研究コミュニティ貢献
- **社会的インパクト**: 日常生活の質向上

---

## 連絡先・リソース

- **プロジェクトディレクトリ**: `/Users/cider/senmon3`
- **ドキュメント**: `local_only/docs.md`, `local_only/research_plan.md`
- **データベース**: PostgreSQL `s2322007@localhost`

---

**Last Updated**: 2025年10月15日
**Status**: Phase 1 完了（研究基盤実装完了）、Phase 2 準備中（実験実施）
