システム設計書

1. システム概要
システム名
RegretLens (リグレット・レンズ) - 後悔を予測し、より良い意思決定を支援するパーソナライズドシステム
コンセプト
日常の小さな意思決定（購買、食事、時間の使い方など）を記録し、機械学習で個人の後悔パターンを学習。新しい選択時に「後悔リスク」を予測して警告することで、意思決定の質を向上させる。

2. 独自性のポイント
🎯 本システムの3つの独自性
独自性1: 日常的マイクロ意思決定への特化

既存研究との差異: 既存の後悔理論研究は投資・医療・キャリアなどの「大きな決定」に焦点
本システム: ランチ選び、衝動買い、SNS閲覧時間など日常の小さな選択に特化
意義: 頻度が高い小規模決定こそ、累積的に生活の質に影響する

独自性2: 予測型アプローチ

既存システムとの差異: Decision Journalなどは「事後の振り返り」のみ
本システム: 過去データから意思決定時点で後悔を予測し警告
意義: 事前警告により、後悔する前に行動を変える機会を提供

独自性3: パーソナライズされた学習モデル

既存研究との差異: 一般的な後悔パターンの理論化
本システム: 各ユーザーの個別の後悔傾向を機械学習で抽出
意義: 「誰もが後悔しやすい状況」ではなく「あなたが後悔しやすい状況」を特定


3. システムアーキテクチャ
┌─────────────────────────────────────────┐
│         フロントエンド (Jinja2)          │
│  - 意思決定記録UI                           │
│  - 後悔リスク可視化ダッシュボード              │
│  - 予測結果表示                             │
│  - フィードバック一覧                        │
└──────────────┬──────────────────────────┘
               │ Flask Routes
┌──────────────┴──────────────────────────┐
│    バックエンド (Flask/Python)           │
│  - myapp.py: ルーティング、リクエスト処理     │
│  - 固定ユーザーID認証 (ログイン不要)          │
│  - データCRUD (PostgreSQL)                │
│  - ML予測エンジン呼び出し                    │
└──────────────┬──────────────────────────┘
               │
     ┌─────────┴─────────┬─────────────────┐
     │                   │                 │
┌────┴──────┐    ┌───────┴────────┐  ┌────┴──────────┐
│ Database  │    │  ML Engine     │  │Pattern Analyzer│
│(PostgreSQL)│    │(ml_engine.py)  │  │(pattern_analyzer.py)│
│           │    │                │  │                │
│- Users    │    │- 特徴量抽出      │  │- 後悔パターン   │
│- Decisions│    │- モデル訓練      │  │  自動検出      │
│- Feedbacks│    │- 後悔予測       │  │- パターン更新   │
│- Regret   │    │- Random Forest │  │- DB保存        │
│  Patterns │    │  + Rule-based  │  │                │
└───────────┘    └────────────────┘  └────────────────┘

実装ファイル構成:
- myapp.py: Flaskアプリケーション本体
- ml_engine.py: 機械学習 + ルールベースの後悔予測エンジン
- pattern_analyzer.py: 後悔パターン分析エンジン
- setup.sql: データベーススキーマ + サンプルデータ
- templates/: HTMLテンプレート (Jinja2)
  - dashboard.html: ダッシュボード
  - decision_form.html: 意思決定入力フォーム
  - feedback_form.html: フィードバック入力フォーム
  - feedbacks_list.html: フィードバック一覧

3.1 実装済みAPIルート
| メソッド | エンドポイント | 機能 | 実装ファイル |
|---------|-------------|------|------------|
| GET | / | ダッシュボード（最新10件の意思決定、統計情報） | myapp.py:26-103 |
| GET/POST | /decision/new | 意思決定入力フォーム + 後悔予測 | myapp.py:106-191 |
| POST | /api/predict | 後悔リスク予測API (JSON) | myapp.py:194-237 |
| GET/POST | /feedback/<decision_id> | フィードバック入力フォーム | myapp.py:240-309 |
| GET | /feedbacks | フィードバック一覧 | myapp.py:312-346 |

3.2 機械学習エンジン仕様 (ml_engine.py)
予測方式: ハイブリッド型（機械学習 + ルールベース）

機械学習モデル:
- アルゴリズム: Random Forest Regressor (n_estimators=50, max_depth=10)
- 特徴量標準化: StandardScaler
- 最低訓練データ数: 10件のフィードバック
- モデル保存: ユーザー毎にpickle形式で保存 (models/model_{user_id}.pkl)
- 出力: 後悔スコア (0-1の範囲)

ルールベース予測（フォールバック）:
- 使用条件: データ不足時（フィードバック10件未満）
- ロジック: ストレスレベル、価格、過去の後悔率などに基づく重み付け計算
- 出力: 後悔スコア (0-1の範囲)

特徴量 (18次元):
1. price: 価格
2. taste_expectation: 期待度 (1-5)
3. health_value: 健康価値 (1-5)
4. time_required: 所要時間
5. mood_score: 気分 (1-5)
6. stress_level: ストレスレベル (1-5)
7. hunger_level: 空腹度 (1-5)
8. budget_remaining: 予算残高
9. with_others: 他者と一緒か (0/1)
10. hour_of_day: 時刻 (0-23)
11. is_lunch_time: ランチタイムか (0/1)
12. is_dinner_time: ディナータイムか (0/1)
13. day_of_week: 曜日 (0-6)
14. weather_encoded: 天気 (1-4)
15. user_average_regret_this_category: カテゴリ別平均後悔度
16. user_regret_variance: 後悔度の分散
17. similar_past_decisions_count: 類似決定の数
18. recent_regret_trend: 最近1週間の後悔トレンド

3.3 パターン分析エンジン仕様 (pattern_analyzer.py)
自動検出パターン:
1. 高ストレス時のカテゴリ別後悔 (stress_level >= 4)
2. 高額購入時の後悔 (price > 1000円)
3. 低期待値の選択 (expectation <= 2)
4. 曜日×カテゴリ別の後悔パターン

パターン保存条件:
- 2回以上発生したパターンのみDB保存
- フィードバック登録時に自動更新
- regret_patternsテーブルに格納

4. データベース設計
主要テーブル
Users (ユーザー)
sqlusers
- id: UUID (PK)
- email: VARCHAR
- password_hash: VARCHAR
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
Decisions (意思決定記録)
sqldecisions
- id: UUID (PK)
- user_id: UUID (FK)
- category: VARCHAR (例: "食事", "購買", "時間の使い方")
- decision_text: TEXT (例: "1200円のランチセット")
- alternatives: JSONB (検討した他の選択肢)
- context: JSONB (状況情報)
  {
    "time_of_day": "12:30",
    "day_of_week": "月曜日",
    "mood": 3,  # 1-5スケール
    "stress_level": 4,
    "hunger_level": 5,
    "budget_remaining": 5000,
    "weather": "雨",
    "with_others": false
  }
- decision_factors: JSONB (選択の理由)
  {
    "price": 1200,
    "taste_expectation": 4,
    "health_value": 3,
    "time_required": 30
  }
- predicted_regret_score: FLOAT (予測時の後悔スコア)
- created_at: TIMESTAMP
Feedback (満足度フィードバック)
sqlfeedback
- id: UUID (PK)
- decision_id: UUID (FK)
- regret_score: INT (1-5: 1=全く後悔なし, 5=とても後悔)
- satisfaction_score: INT (1-5)
- regret_reasons: TEXT[] (後悔の理由)
- would_change: BOOLEAN (同じ状況ならどうするか)
- feedback_timing: VARCHAR ("immediate", "1day", "1week")
- created_at: TIMESTAMP
Regret_Patterns (後悔パターン分析結果)
sqlregret_patterns
- id: UUID (PK)
- user_id: UUID (FK)
- pattern_type: VARCHAR (例: "高額購入時", "疲労時の食事")
- trigger_conditions: JSONB
- average_regret: FLOAT
- occurrence_count: INT
- created_at: TIMESTAMP

5. 機能設計
5.1 コア機能
機能1: 意思決定記録
入力フォーム:
┌────────────────────────────────────┐
│ 意思決定を記録                       │
├────────────────────────────────────┤
│ カテゴリ: [食事 ▼]                  │
│                                    │
│ 選んだこと:                         │
│ [ラーメン屋で豚骨ラーメン大盛り      ]│
│                                    │
│ 他に考えた選択肢: [+ 追加]          │
│ ├ 社食の定食 (500円)                │
│ ├ コンビニ弁当 (400円)              │
│ └ [新しい選択肢を追加...]            │
│                                    │
│ 今の状況を教えてください:            │
│ 気分: ☆☆☆☆☆                       │
│ ストレス: ☆☆☆☆☆                   │
│ 空腹度: ☆☆☆☆☆                     │
│ 予算残り: [5000]円                  │
│ 誰かと一緒？ [ ] はい [✓] いいえ     │
│                                    │
│ 選んだ理由:                         │
│ 価格: [950]円                       │
│ 美味しさ期待度: ☆☆☆☆☆              │
│ 健康面: ☆☆☆☆☆                     │
│ 所要時間: [20]分                    │
│                                    │
│ [💡 後悔リスクを予測]  [記録する]     │
└────────────────────────────────────┘
独自性ポイント:

詳細なコンテキスト情報: 時刻、曜日、気分、ストレスレベルなど、後悔に影響する要因を網羅的に記録
選択肢の比較: 選んだものだけでなく、検討した他の選択肢も記録（後悔は「他の選択肢」との比較で生まれる）

機能2: 後悔リスク予測
予測アルゴリズム:
python# 特徴量
features = [
    # 決定要因
    'price',
    'expected_satisfaction',
    'health_value',
    'time_required',
    
    # コンテキスト
    'time_of_day_encoded',
    'day_of_week_encoded',
    'mood_score',
    'stress_level',
    'hunger_level',
    'budget_remaining',
    'weather_encoded',
    'with_others',
    
    # ユーザー履歴特徴
    'user_average_regret_this_category',
    'user_regret_variance',
    'similar_past_decisions_count',
    
    # 時系列特徴
    'days_since_last_similar_decision',
    'recent_regret_trend'  # 最近1週間の後悔傾向
]

# モデル: Random Forest Classifier
# 出力: 後悔リスク (0-1) + 理由
予測結果表示:
┌────────────────────────────────────┐
│ 🚨 後悔リスク予測                    │
├────────────────────────────────────┤
│ この選択の後悔リスク: 72%           │
│ ████████████████░░░░               │
│                                    │
│ ⚠️ 注意すべきポイント:               │
│ • あなたは疲れている時に高額な       │
│   食事を選ぶと後悔しやすい傾向       │
│   (過去5回中4回が後悔)              │
│                                    │
│ • この価格帯の食事では、満足度が     │
│   期待を下回ることが多い            │
│   (平均満足度: 2.8/5.0)             │
│                                    │
│ 💡 過去の類似ケース:                 │
│ 2週間前: 同じ店で大盛り → 後悔度4   │
│ 理由「量が多すぎて苦しくなった」     │
│                                    │
│ [それでも記録する] [選択を変える]     │
└────────────────────────────────────┘
独自性ポイント:

リスクの可視化: 数値だけでなく、なぜそのリスクがあるのかを説明
過去の類似ケース提示: 自分の過去の失敗を思い出させる（後悔理論の「反実仮想思考」に基づく）

機能3: 満足度フィードバック
フィードバックタイミング:

即時 (決定直後): 初期満足度
1日後: 短期的な評価
1週間後: 長期的な評価（オプション）

フィードバックフォーム:
┌────────────────────────────────────┐
│ 振り返り: 豚骨ラーメン大盛り         │
├────────────────────────────────────┤
│ 後悔していますか？                   │
│ ( ) 全く後悔していない               │
│ ( ) 少し後悔                        │
│ (●) やや後悔                        │
│ ( ) かなり後悔                      │
│ ( ) とても後悔                      │
│                                    │
│ 後悔の理由: (複数選択可)             │
│ [✓] 価格が高すぎた                  │
│ [✓] 量が多すぎた                    │
│ [ ] 味が期待外れだった               │
│ [✓] 健康的でなかった                │
│ [ ] 時間がかかりすぎた               │
│ [ ] その他: [____________]          │
│                                    │
│ 同じ状況なら、どうしますか？         │
│ (●) 別の選択肢を選ぶ                │
│ ( ) 同じ選択をする                  │
│                                    │
│ [フィードバックを送信]               │
└────────────────────────────────────┘
独自性ポイント:

複数時点での評価: 即座の感情と時間が経った後の評価を区別（感情の変化を追跡）
構造化された後悔理由: 自由記述だけでなく、選択式で後悔の要因を特定


5.2 分析・可視化機能
ダッシュボード
┌────────────────────────────────────────────────────┐
│ あなたの意思決定パターン                             │
├────────────────────────────────────────────────────┤
│                                                    │
│ 📊 後悔率の推移                                     │
│ %                                                  │
│ 80│                                                │
│ 60│     ●─────●                                    │
│ 40│           ●─────●─────●                        │
│ 20│                       ●─────●                  │
│  0└─────┬─────┬─────┬─────┬─────┬                 │
│    1週目  2週目  3週目  4週目  5週目               │
│                                                    │
│ 🎯 後悔しやすいパターン Top 3                        │
│ 1. 疲れている時の高額な食事 (後悔率: 80%)            │
│ 2. 月曜日の衝動買い (後悔率: 65%)                   │
│ 3. 深夜のSNS閲覧 (後悔率: 60%)                     │
│                                                    │
│ ✨ 改善が見られた領域                               │
│ • 食事の選択: 後悔率 65% → 35% (↓30%)              │
│   → 予算を意識するようになった効果                  │
│                                                    │
│ 📅 カテゴリ別後悔率                                 │
│ 食事      ████████░░ 40%                          │
│ 購買      ██████████ 50%                          │
│ 時間管理   ████░░░░░░ 20%                          │
│                                                    │
└────────────────────────────────────────────────────┘
独自性ポイント:

時系列での行動変容可視化: システム使用前後での改善を定量化
パーソナライズされたインサイト: 一般論ではなく「あなた」の傾向を示す

6. 現在の実装状況

✅ 実装完了機能:
1. データベース設計・構築
   - PostgreSQL スキーマ設計完了
   - 4つのテーブル (users, decisions, feedbacks, regret_patterns)
   - サンプルデータ33件 + フィードバック32件を投入済み
   - インデックス最適化済み

2. Flaskバックエンド (myapp.py)
   - 全5つのルート実装完了
   - 固定ユーザーID認証システム (ログイン不要)
   - PostgreSQL接続管理 (psycopg2)
   - JSON処理 (JSONB型対応)
   - エラーハンドリング実装

3. 機械学習エンジン (ml_engine.py)
   - ハイブリッド予測システム実装
   - Random Forest Regressor (scikit-learn)
   - 18次元特徴量エンジニアリング
   - ルールベースフォールバック
   - ユーザー毎のモデル訓練・保存機能
   - 警告メッセージ生成機能
   - 類似ケース検索機能

4. パターン分析エンジン (pattern_analyzer.py)
   - 4種類の後悔パターン自動検出
   - フィードバック連動型パターン更新
   - DB自動同期

5. フロントエンド (Jinja2テンプレート)
   - ダッシュボード (dashboard.html)
   - 意思決定入力フォーム (decision_form.html)
   - フィードバック入力フォーム (feedback_form.html)
   - フィードバック一覧 (feedbacks_list.html)

🔧 技術スタック:
- バックエンド: Flask 3.0.0
- データベース: PostgreSQL (JSONB型活用)
- DB接続: psycopg2-binary 2.9.9
- 機械学習: scikit-learn (Random Forest)
- フロントエンド: Jinja2 (Flask標準)
- Python: 3.x
- デプロイ: Apache + mod_wsgi (flask.wsgi)

📊 現在のデータ状況:
- ユーザー: 1名 (固定ID: a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11)
- 意思決定記録: 33件 (2ヶ月分のサンプルデータ)
- フィードバック: 32件
- カテゴリ: 食事、買い物、娯楽、学習、仕事

⚠️ 未実装・今後の拡張機能:
1. ユーザー登録・ログイン機能
2. リアルタイム予測UI (JavaScript)
3. グラフ・チャート可視化 (Chart.js等)
4. モバイル対応 (レスポンシブデザイン)
5. 予測精度の評価・改善
6. A/Bテストによるアルゴリズム改善
7. 外部API連携 (天気情報など)
8. プッシュ通知 (フィードバックリマインダー)

7. セットアップ手順

7.1 データベース初期化
```bash
psql -U s2322007 -d s2322007 < setup.sql
```

7.2 Pythonパッケージインストール
```bash
pip3 install -r local_only/requirements.txt
pip3 install scikit-learn --user  # 機械学習用
```

7.3 開発サーバー起動
```bash
python3 myapp.py
# http://localhost:5000 でアクセス
```

7.4 本番デプロイ (Apache)
- flask.wsgiを使用
- Apache設定でmod_wsgiを有効化
- データベース接続情報を環境変数化推奨

8. ファイル構成
```
senmon3/
├── myapp.py                 # Flaskアプリケーション本体
├── ml_engine.py             # 機械学習エンジン
├── pattern_analyzer.py      # パターン分析エンジン
├── setup.sql                # DBスキーマ + サンプルデータ
├── flask.wsgi               # Apache用WSGIファイル
├── .gitignore               # Git除外設定
├── local_only/              # ローカル専用ファイル
│   ├── docs.md              # このドキュメント
│   ├── requirements.txt     # 依存パッケージ
│   └── README.md
├── templates/               # HTMLテンプレート
│   ├── base.html
│   ├── dashboard.html
│   ├── decision_form.html
│   ├── feedback_form.html
│   ├── feedbacks_list.html
│   ├── login.html
│   └── register.html
└── models/                  # MLモデル保存先 (自動生成)
    └── model_{user_id}.pkl

## 論文化に向けた拡張システム

### 9.1 研究の新規性

本システムを学術論文レベルに昇華させるため、以下の拡張を実施：

#### 学術的貢献
1. **個人適応型特徴量選択アルゴリズム** (adaptive_features.py)
   - SHAP値による解釈可能な特徴量重要度分析
   - Permutation Importanceによる頑健性評価
   - RFE/SelectKBestによる自動特徴量選択
   - ユーザー毎に最適な特徴量セットを自動決定

2. **モデル評価・比較フレームワーク** (model_evaluator.py)
   - 時系列交差検証 (TimeSeriesSplit)
   - 複数モデルの性能比較 (Random Forest, XGBoost, ルールベース)
   - 評価指標: MAE, RMSE, R², Precision, Recall, F1
   - Regret Reduction Rate (RRR) - 独自の行動変容評価指標

3. **時系列パターン学習** (予定)
   - LSTM/GRUによる意思決定シーケンス学習
   - Attention機構で重要な過去決定を強調

### 9.2 実装済み研究機能

#### model_evaluator.py (モデル評価器)
**機能**:
- `time_series_cross_validation()`: 時系列交差検証
- `evaluate_classification()`: 3クラス分類評価（高/中/低リスク）
- `calculate_regret_reduction_rate()`: RRR計算 + 統計的検定
- `calculate_prediction_following_rate()`: 予測追従率分析
- `generate_comparison_report()`: モデル性能比較レポート生成

**評価指標**:
```python
# 回帰指標
- Mean Absolute Error (MAE)
- Root Mean Squared Error (RMSE)
- R² Score

# 分類指標
- Accuracy, Precision, Recall, F1-score

# 行動変容指標
- Regret Reduction Rate (RRR) = (後悔度_介入前 - 後悔度_介入後) / 後悔度_介入前
- Prediction Following Rate: 予測に従った割合
- Statistical significance (t-test, p-value)
```

#### adaptive_features.py (適応的特徴量選択)
**機能**:
- `calculate_feature_importance_shap()`: SHAP値による解釈可能性
- `calculate_feature_importance_permutation()`: Permutation Importance
- `select_features_rfe()`: Recursive Feature Elimination
- `select_features_kbest()`: 統計的特徴量選択
- `adaptive_feature_selection()`: 総合的適応選択

**特徴量選択手法**:
- **SHAP (SHapley Additive exPlanations)**: 最も解釈可能
- **Permutation Importance**: モデルに依存しない頑健性
- **RFE**: 再帰的特徴量削減
- **SelectKBest**: F統計量ベース

### 9.3 新規APIエンドポイント

| メソッド | エンドポイント | 機能 | 実装ファイル |
|---------|-------------|------|------------|
| GET/POST | /research/evaluate | モデル性能比較実験 | myapp.py:350-397 |

### 9.4 論文構成案

**タイトル**: 「個人化された後悔予測モデル：適応的特徴量選択と時系列学習によるマイクロ意思決定支援システム」

**主要な実験**:
1. モデル性能比較実験 (Random Forest vs XGBoost vs ルールベース)
2. 個人化特徴量選択の効果検証 (A/Bテスト)
3. ユーザー行動変容の定量評価 (RRR測定)
4. 予測説明可能性の評価 (SHAP可視化)

### 9.5 必要な追加ライブラリ

```bash
# 研究用パッケージ
pip3 install xgboost==2.0.0
pip3 install shap==0.42.1
pip3 install scipy==1.11.1
pip3 install matplotlib==3.7.2
pip3 install seaborn==0.12.2
```

### 9.6 期待される成果

**学術的成果**:
- 国際会議論文 (CHI, UIST, IUI等)
- ジャーナル論文 (Behavior & IT, TOCHI等)
- 後悔予測の標準ベンチマーク確立

**実用的成果**:
- 個人化学習のベストプラクティス
- オープンソースフレームワーク
- 実用可能な意思決定支援システム

詳細は `local_only/research_plan.md` を参照。
```