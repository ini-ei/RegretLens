# RegretLens サーバーセットアップガイド

## 前提条件
- PostgreSQL がインストール済み
- Python 3.x がインストール済み
- Apache + mod_wsgi がインストール済み（本番環境の場合）
- SSH公開鍵認証が設定済み（推奨）

## 0. SSH公開鍵の設定（初回のみ）

### 0.1 公開鍵のアップロード

サーバーは基本的に公開鍵による通信を前提として設定されています。初回接続時は以下の手順で公開鍵をアップロードしてください。

```bash
# ローカルPCから実行
cd ~/.ssh
scp id_rsa.pub ユーザー名@サーバーアドレス:~/.ssh/authorized_keys
```

パスワード認証が求められるので、個別に連絡されたパスワードを入力してください。

### 0.2 接続確認

公開鍵の設定が完了したら、ターミナルから接続できます:

```bash
ssh ユーザー名@サーバーアドレス
# 秘密鍵のパスフレーズを入力
```

### 0.3 Cyberduckの設定

ファイル転送ソフト（Cyberduck等）の設定:
- プロトコル: SFTP
- サーバ: サーバーアドレス
- ユーザ名: 学籍番号等
- SSH Private Key: ~/.ssh/id_rsa

## 1. ファイル転送

### 1.1 ファイル転送方法

**Cyberduckを使用する場合:**
1. Cyberduckを起動し、ブックマークから接続
2. public_htmlフォルダまたはプロジェクトディレクトリへ移動
3. ファイルをドラッグ&ドロップで転送

**scpコマンドを使用する場合:**
```bash
scp ファイル名 ユーザー名@サーバーアドレス:~/プロジェクトパス/
```

### 1.2 転送するファイル
```bash
# 必須ファイル
myapp.py
ml_engine.py
pattern_analyzer.py
setup.sql
flask.wsgi

# 研究用ファイル（オプション）
model_evaluator.py
adaptive_features.py
temporal_learner.py
setup_research_tables.sql

# テンプレート
templates/
├── base.html
├── dashboard.html
├── decision_form.html
├── feedback_form.html
├── feedbacks_list.html
├── login.html (未使用)
└── register.html (未使用)

# 設定ファイル
local_only/requirements.txt
```

### 転送しないファイル（ローカル専用）
```bash
local_only/docs/             # PDFドキュメント（授業資料等）
local_only/docs.md           # ドキュメント
local_only/research_plan.md  # 研究計画書
local_only/RESEARCH_SUMMARY.md
local_only/README.md
.gitignore
.DS_Store
models/                      # ローカルで訓練したモデル（サーバーで再生成）
__pycache__/                 # Pythonキャッシュ
*.pyc                        # コンパイル済みPythonファイル
```

### 1.3 ファイルのエンコーディングと改行コード

**重要:** サーバーで動作させるPythonファイルは以下の設定で保存してください:
- 文字コード: **UTF-8**
- 改行コード: **LF** (Linuxスタイル)
- ファイル名: 半角英数字のみ使用

VSCodeでの設定方法:
1. 画面右下の「UTF-8」「CRLF」等の表示をクリック
2. 「UTF-8で保存」「LFで保存」を選択

## 2. データベースセットアップ

### 2.1 データベース接続情報の設定



# 基本テーブル作成
psql -U s2322007 -d s2322007 < setup.sql

# 研究用テーブル作成（オプション）
psql -U s2322007 -d s2322007 < setup_research_tables.sql

# 確認
psql -U s2322007 -d s2322007 -c "\dt"
# users, decisions, feedbacks, regret_patterns が表示されればOK
```

### 2.4 PostgreSQL接続の基本

**psqlコマンドでの接続:**
```bash
# フルオプション指定
psql -U ユーザー名 -W -d データベース名

# ユーザー名とDB名が同じ場合（省略形）
psql

# SQLファイルの実行
psql < file.sql
```

**psql内の基本コマンド:**
```sql
\dt              -- テーブル一覧表示
\d テーブル名    -- テーブル構造表示
\q               -- psql終了
```

## 3. Pythonパッケージインストール

### 3.1 基本パッケージのインストール

```bash
# ユーザーディレクトリにインストール（権限不要）
pip3 install --user -r local_only/requirements.txt

# 機械学習ライブラリ
pip3 install --user scikit-learn numpy scipy

# 研究用（オプション）
pip3 install xgboost shap torch pandas matplotlib seaborn --user
```

### 3.2 追加モジュールのインストール

サーバー環境で追加のPythonモジュールが必要な場合:

```bash
# --userオプションを必ず付ける（システム領域への書き込み権限が不要）
pip3 install モジュール名 --user

# 例: psycopg2（PostgreSQL接続用）
pip3 install psycopg2-binary --user

# インストール済みパッケージの確認
pip3 list --user
```

## 4. ディレクトリ作成

```bash
cd ~/senmon3
mkdir -p models              # MLモデル保存先
mkdir -p evaluation_results  # 実験結果保存先
chmod 755 models evaluation_results
```

## 5. Apache設定（本番環境）

### 5.1 WSGIファイルの作成

FlaskアプリケーションをApacheで動作させるために、WSGIファイルが必要です。

**flask.wsgi の作成:**

```python
# flask.wsgi
import sys
import os

# プロジェクトディレクトリの絶対パス
DIR = os.path.dirname(__file__)
sys.path.append(DIR)
sys.path.insert(0, '/home/s2322007/senmon3')  # 実際のパスに変更

# 環境変数設定
os.environ['DB_HOST'] = 'localhost'
os.environ['DB_NAME'] = 's2322007'
os.environ['DB_USER'] = 's2322007'
os.environ['DB_PASSWORD'] = 'あなたのパスワード'  # 実際のパスワード

# Flaskアプリケーションのインポート
from myapp import app as application
```

**重要なポイント:**
- `sys.path.insert(0, '...')` で、Flaskアプリのディレクトリを指定
- `from myapp import app as application` の `myapp` は実際のPythonファイル名に合わせる
- 環境変数でDB接続情報を設定（ハードコードを避ける）

### 5.2 Apache設定の申請

Apache設定は管理者権限が必要なため、以下の情報を管理者に連絡してください:

**申請に必要な情報:**
```
サーバーのユーザー名: s2322007
プロジェクトディレクトリ: /home/s2322007/senmon3/
wsgiファイルの場所: /home/s2322007/senmon3/flask.wsgi
希望するURL: /senmon3 (または /ユーザー名)
```

**Apache設定ファイル例（参考）:**

```apache
# /etc/httpd/conf.d/senmon3.conf (管理者が設定)

WSGIDaemonProcess senmon3 user=s2322007 group=s2322007 threads=5
WSGIScriptAlias /senmon3 /home/s2322007/senmon3/flask.wsgi

<Directory /home/s2322007/senmon3>
    WSGIProcessGroup senmon3
    WSGIApplicationGroup %{GLOBAL}
    Require all granted
</Directory>
```

### 5.3 公開URL

設定完了後、以下のURLでアクセス可能になります:

- Flask アプリケーション: `http://サーバーURL/senmon3/`
- 静的ファイル（CGI等）: `http://サーバーURL/~s2322007/`

**注意:** CGI とFlask では公開URLが異なります:
- CGI: `~ユーザー名/` （public_htmlフォルダ）
- Flask: `/プロジェクト名/` （WSGI設定による）

## 6. 開発サーバーでの起動（テスト用）

```bash
cd ~/senmon3

# 環境変数設定
export DB_PASSWORD=あなたのパスワード

# 起動
python3 myapp.py

# ポートフォワーディングでローカルからアクセス
# ローカルPC側で実行:
# ssh -L 5000:localhost:5000 s2322007@サーバーアドレス
# ブラウザで http://localhost:5000 にアクセス
```

## 7. 動作確認

### 7.1 基本動作確認

```bash
# Pythonシェルで確認
python3

>>> from myapp import get_db_connection
>>> conn = get_db_connection()
>>> cur = conn.cursor()
>>> cur.execute("SELECT COUNT(*) FROM decisions")
>>> print(cur.fetchone())
# {'count': 33} が表示されればOK
```

### 7.2 Webアクセス確認

ブラウザで以下にアクセス:
- ダッシュボード: `/senmon3/` または `http://localhost:5000/`
- 意思決定入力: `/senmon3/decision/new`
- フィードバック一覧: `/senmon3/feedbacks`

## 8. トラブルシューティング

### エラー: ModuleNotFoundError
```bash
# パッケージが見つからない場合
pip3 install --user パッケージ名

# sys.pathを確認
python3 -c "import sys; print(sys.path)"
```

### エラー: psycopg2.OperationalError
```bash
# データベース接続エラー
# 1. PostgreSQLが起動しているか確認
psql -U s2322007 -d s2322007 -c "SELECT 1"

# 2. 環境変数が設定されているか確認
echo $DB_PASSWORD

# 3. パスワードが正しいか確認
```

### エラー: Permission denied (models/)
```bash
# ディレクトリの権限確認
ls -ld models/
chmod 755 models/
```

### エラー: 500 Internal Server Error (Apache)
```bash
# Apacheエラーログ確認（管理者に依頼）
sudo tail -f /var/log/httpd/error_log
```

## 9. セキュリティ対策

### 9.1 secret_key の変更

```python
# myapp.py の12行目
# 現在（開発用）
app.secret_key = '0bbb75e3e5bec98a22c421fae1673951d20f039c6502a6228ba51ae92efb05ac'

# 本番環境用に変更
import os
app.secret_key = os.getenv('SECRET_KEY', os.urandom(32).hex())

# 環境変数で設定
export SECRET_KEY=$(python3 -c "import os; print(os.urandom(32).hex())")
```

### 9.2 固定ユーザーIDの扱い

現在はログイン機能なしで固定ID使用:
```python
FIXED_USER_ID = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
```

複数ユーザーで使う場合は、ログイン機能の実装が必要。

### 9.3 DEBUGモードの無効化

```python
# myapp.py の13行目
# 開発環境
app.config['DEBUG'] = True

# 本番環境
app.config['DEBUG'] = False  # 必ず変更
```

## 10. バックアップ

### データベースバックアップ

```bash
# 定期的にバックアップ
pg_dump -U s2322007 -d s2322007 > backup_$(date +%Y%m%d).sql

# リストア（必要時）
psql -U s2322007 -d s2322007 < backup_20251015.sql
```

### モデルファイルバックアップ

```bash
# modelsディレクトリをtar.gz化
tar -czf models_backup_$(date +%Y%m%d).tar.gz models/
```

## 11. Flask vs CGI の比較

本プロジェクトではFlaskを使用していますが、参考までにCGIとの違いを記載します。

### 11.1 CGI（Common Gateway Interface）

**特徴:**
- シンプルで学習コストが低い
- リクエストごとにプロセス起動（パフォーマンス低）
- 実行権限の設定が必要（chmod 755）

**公開URL:** `http://サーバー/~ユーザー名/sample.py`

**実行権限の設定:**
```bash
# Cyberduckで右クリック→情報→実行権限を全てチェック
# または、サーバー上で:
chmod 755 sample.py
```

### 11.2 Flask（Webフレームワーク）

**特徴:**
- テンプレートエンジン（Jinja2）でHTML生成が容易
- ルーティング機能（URL設計が柔軟）
- JSON API作成が簡単
- 常駐プロセス（パフォーマンス高）
- 静的ファイル（CSS, JS）の管理が容易

**公開URL:** `http://サーバー/プロジェクト名/`

**ディレクトリ構造:**
```
myapp/
├── myapp.py          # メインアプリケーション
├── flask.wsgi        # WSGIインターフェース
├── templates/        # HTMLテンプレート
│   ├── layout.html
│   └── index.html
└── static/           # 静的ファイル
    ├── css/
    │   └── bootstrap.min.css
    └── js/
        └── bootstrap.bundle.min.js
```

## 12. チェックリスト

### 初回セットアップ:
- [ ] SSH公開鍵の設定完了
- [ ] Cyberduck接続設定完了
- [ ] データベースアクセス確認

### 転送前:
- [ ] ファイルのエンコーディング確認（UTF-8, LF）
- [ ] myapp.pyのDB接続情報を環境変数化
- [ ] secret_keyを本番用に変更
- [ ] DEBUG=Falseに設定
- [ ] flask.wsgiのパス確認・修正
- [ ] templatesフォルダの確認
- [ ] staticフォルダの確認（CSS/JS）

### 転送後:
- [ ] 全ファイル転送完了
- [ ] データベーステーブル作成完了（setup.sql実行）
- [ ] 環境変数設定完了（~/.bashrc）
- [ ] Pythonパッケージインストール完了
- [ ] ディレクトリ作成・権限設定完了（models/等）
- [ ] Apache設定申請完了
- [ ] 動作確認完了（ダッシュボード表示）
- [ ] データ投入確認（33件のサンプルデータ）
- [ ] 静的ファイル読み込み確認（Bootstrap等）

## 13. サポートとリファレンス

### 13.1 トラブル時の確認手順

問題が発生した場合:
1. エラーログ確認（Apacheまたはpython3の出力）
2. データベース接続確認（psqlコマンドで接続テスト）
3. ファイルパス・権限確認（ls -la で確認）
4. ファイルのエンコーディング確認（UTF-8, LF）
5. Pythonモジュールのインストール確認（pip3 list --user）

### 13.2 参考資料

**プロジェクトドキュメント:**
- システム設計: `local_only/docs.md`
- 研究計画: `local_only/research_plan.md`
- 実装サマリー: `local_only/RESEARCH_SUMMARY.md`

**授業資料（PDFドキュメント）:**
- 環境設定とHTML/CSS: `local_only/docs/00intro.pdf`
- Python CGI入門: `local_only/docs/01py-cgi.pdf`
- Flask入門: `local_only/docs/02flask.pdf`

**公式ドキュメント:**
- Flask: https://flask.palletsprojects.com/
- Flask日本語: https://msiz07-flask-docs-ja.readthedocs.io/
- PostgreSQL: https://www.postgresql.org/docs/
- Bootstrap: https://getbootstrap.jp/

### 13.3 よくある質問

**Q: Flask と CGI の違いは？**
A: CGIはリクエストごとにプロセス起動、Flaskは常駐プロセスで高速。FlaskはテンプレートエンジンやルーティングなどWebフレームワークの機能を持つ。

**Q: 静的ファイル（CSS, JS）はどこに置く？**
A: Flaskの場合、`static/` フォルダに配置し、テンプレート内で `url_for('static', filename='css/style.css')` で読み込む。

**Q: テンプレートが更新されない**
A: ブラウザのキャッシュをクリアするか、Apache/Flaskを再起動してください。開発時は `app.config['DEBUG'] = True` でキャッシュ無効化。

**Q: データベース接続エラーが出る**
A: 環境変数（DB_PASSWORD等）が設定されているか確認。`echo $DB_PASSWORD` で確認できます。
