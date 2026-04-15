# RegretLens

LLMと対話しながら後悔を予測し、より良い意思決定をサポートするスマホアプリ

## 概要

RegretLensは、AIチャットを通じてユーザーの意思決定を支援するアプリです。会話の中から意思決定を自動検出し、過去の後悔パターンに基づいたアドバイスを提供します。

- **LLMチャット対話**: GPT-4oと自然な会話で意思決定を相談
- **後悔予測**: ルールベース + LLM推論のハイブリッド予測（18次元特徴量）
- **パターン検出**: 繰り返す後悔パターンを自動検出・警告
- **リンク連携**: Amazon / Googleマップのリンクから商品・場所のレビュー傾向を参照
- **フォローアップ通知**: リンク付き意思決定に対して数日後に自動通知でフィードバック促進

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| フロントエンド | Flutter (iOS / Android / Web) |
| バックエンド | Supabase (PostgreSQL + Edge Functions) |
| LLM | OpenAI GPT-4o |
| 認証 | Supabase Auth (匿名 / メール) |

## プロジェクト構成

```
regretlens/
├── app/                          # Flutter アプリ
│   └── lib/
│       ├── main.dart             # エントリポイント
│       ├── app.dart              # ルートウィジェット + ナビゲーション
│       ├── config/
│       │   ├── supabase_config.dart
│       │   └── theme.dart
│       ├── models/
│       │   ├── chat_message.dart
│       │   └── decision.dart     # Decision + Feedback モデル
│       ├── services/
│       │   ├── supabase_service.dart
│       │   └── chat_service.dart
│       ├── screens/
│       │   ├── chat_screen.dart       # メイン: LLMチャット
│       │   ├── dashboard_screen.dart  # 統計・パターン・グラフ
│       │   ├── history_screen.dart    # 意思決定履歴
│       │   ├── feedback_screen.dart   # フィードバック入力
│       │   └── settings_screen.dart
│       └── widgets/
│           ├── chat_bubble.dart       # URL検出・リスクバッジ付き
│           └── risk_indicator.dart
├── supabase/                     # バックエンド
│   ├── migrations/
│   │   └── *_init_schema.sql     # DBスキーマ (6テーブル + RLS)
│   └── functions/
│       ├── _shared/
│       │   ├── cors.ts
│       │   ├── supabase.ts
│       │   └── regret_rules.ts   # 後悔予測ルールエンジン
│       ├── chat/index.ts         # LLM対話 + 意思決定抽出
│       ├── predict/index.ts      # 後悔予測API
│       └── feedback/index.ts     # フィードバック + パターン分析
├── legacy/                       # 旧Flask版 (参照用)
└── README.md
```

## セットアップ

### 1. Supabase プロジェクト作成

[supabase.com](https://supabase.com) でプロジェクトを作成し、URLとAnon Keyを取得。

```bash
# マイグレーション適用
supabase link --project-ref <your-project-ref>
supabase db push
```

### 2. 環境変数設定

Supabase Edge Functions に設定:
```bash
supabase secrets set OPENAI_API_KEY=sk-...
```

Flutter アプリに設定 (`app/lib/config/supabase_config.dart`):
```dart
static const String supabaseUrl = 'https://your-project.supabase.co';
static const String supabaseAnonKey = 'your-anon-key';
```

### 3. Edge Functions デプロイ

```bash
supabase functions deploy chat
supabase functions deploy predict
supabase functions deploy feedback
```

### 4. Flutter アプリ起動

```bash
cd app
flutter pub get
flutter run          # iOS/Android
flutter run -d chrome  # Web
```

## DBスキーマ

| テーブル | 用途 |
|---------|------|
| `profiles` | ユーザープロフィール |
| `decisions` | 意思決定記録 (カテゴリ, コンテキスト, 予測スコア, URL) |
| `feedbacks` | フィードバック (後悔度, 満足度, 理由) |
| `chat_messages` | チャット履歴 |
| `regret_patterns` | 検出された後悔パターン |
| `scheduled_notifications` | フォローアップ通知スケジュール |

## 後悔予測ロジック

旧ML版から移植したルールベースエンジン + LLMの推論力を組み合わせ:

- ストレス高 (>=4): +0.20
- 高額 (>1000円): +0.15
- 同カテゴリ高後悔歴 (>=4): +0.25
- 低期待値 (<=2): +0.20
- 予算超過: +0.20
- 気分低下 (<=2): +0.10
- 極度の空腹 (>=5): +0.15

データ蓄積後にMLモデル (Random Forest / XGBoost) の再導入が可能。旧版の実装は `legacy/` に保持。
