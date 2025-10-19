from flask import Flask, render_template, request, redirect, url_for, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
import uuid
from datetime import datetime
import json
import traceback
import os
from dotenv import load_dotenv
from ml_engine import predict_regret as ml_predict_regret
from pattern_analyzer import update_patterns_after_feedback
from model_evaluator import ModelEvaluator, run_experiment_comparison

# .env ファイルを読み込む
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['DEBUG'] = os.getenv('DEBUG', 'False').lower() == 'true'

# ユーザーID（環境変数から読み込む）
FIXED_USER_ID = os.getenv('FIXED_USER_ID')

# データベース接続
def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        database=os.getenv('DB_NAME', 'senmon3'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', ''),
        cursor_factory=RealDictCursor
    )

# ルート: ホーム（ダッシュボード）
@app.route('/')
def index():
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # ユーザーの意思決定履歴を取得
        cur.execute("""
            SELECT id, category, decision_text, predicted_regret_score, created_at
            FROM decisions
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT 10
        """, (FIXED_USER_ID,))
        decisions = cur.fetchall()

        # 統計情報を計算
        # 全意思決定数
        cur.execute("""
            SELECT COUNT(*) as total FROM decisions WHERE user_id = %s
        """, (FIXED_USER_ID,))
        stats = {'total_decisions': cur.fetchone()['total']}

        # カテゴリ別の後悔率
        cur.execute("""
            SELECT d.category, AVG(f.regret_score) as avg_regret, COUNT(*) as count
            FROM decisions d
            JOIN feedbacks f ON d.id = f.decision_id
            WHERE d.user_id = %s
            GROUP BY d.category
            ORDER BY avg_regret DESC
        """, (FIXED_USER_ID,))
        category_regret = cur.fetchall()
        # Decimalをfloatに変換
        stats['category_regret'] = [{'category': c['category'], 'avg_regret': float(c['avg_regret']), 'count': c['count']} for c in category_regret]

        # 後悔パターン Top 3
        cur.execute("""
            SELECT pattern_type, average_regret, occurrence_count
            FROM regret_patterns
            WHERE user_id = %s
            ORDER BY average_regret DESC, occurrence_count DESC
            LIMIT 3
        """, (FIXED_USER_ID,))
        top_patterns = cur.fetchall()
        stats['top_patterns'] = [{'pattern_type': p['pattern_type'], 'average_regret': float(p['average_regret']), 'occurrence_count': p['occurrence_count']} for p in top_patterns]

        # 時系列データ（週ごとの後悔率）
        cur.execute("""
            SELECT
                DATE_TRUNC('week', f.created_at) as week,
                AVG(f.regret_score) as avg_regret
            FROM feedbacks f
            JOIN decisions d ON f.decision_id = d.id
            WHERE d.user_id = %s AND f.created_at >= NOW() - INTERVAL '5 weeks'
            GROUP BY week
            ORDER BY week
        """, (FIXED_USER_ID,))
        weekly_trend = cur.fetchall()
        stats['weekly_trend'] = [{'week': w['week'], 'avg_regret': float(w['avg_regret'])} for w in weekly_trend]

        # フィードバック数
        cur.execute("""
            SELECT COUNT(*) as total
            FROM feedbacks f
            JOIN decisions d ON f.decision_id = d.id
            WHERE d.user_id = %s
        """, (FIXED_USER_ID,))
        stats['total_feedbacks'] = cur.fetchone()['total']

        cur.close()
        conn.close()

        return render_template('dashboard.html', decisions=decisions, stats=stats)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return render_template('dashboard.html', decisions=[], stats={'total_decisions': 0, 'total_feedbacks': 0, 'category_regret': [], 'top_patterns': [], 'weekly_trend': []}, error=str(e))

# ルート: 意思決定入力フォーム
@app.route('/decision/new', methods=['GET', 'POST'])
def new_decision():
    if request.method == 'POST':
        try:
            # フォームデータ取得
            category = request.form.get('category')
            decision_text = request.form.get('decision_text')
            alternatives = request.form.get('alternatives', '')

            # コンテキスト情報
            context = {
                'mood': int(request.form.get('mood', 3)),
                'stress_level': int(request.form.get('stress_level', 3)),
                'hunger_level': int(request.form.get('hunger_level', 3)),
                'time_of_day': request.form.get('time_of_day', ''),
                'day_of_week': request.form.get('day_of_week', ''),
                'weather': request.form.get('weather', ''),
                'with_others': request.form.get('with_others') == 'on',
                'budget_remaining': float(request.form.get('budget_remaining', 0))
            }

            # 決定要因
            decision_factors = {
                'price': float(request.form.get('price', 0)),
                'taste_expectation': int(request.form.get('taste_expectation', 3)),
                'health_value': int(request.form.get('health_value', 3)),
                'time_required': float(request.form.get('time_required', 0))
            }

            # alternatives を配列に変換
            alternatives_list = [alt.strip() for alt in alternatives.split(',') if alt.strip()]

            conn = get_db_connection()
            cur = conn.cursor()

            # ユーザーの過去の意思決定を取得（予測用）
            cur.execute("""
                SELECT id, category, decision_text, alternatives, context, decision_factors, created_at
                FROM decisions
                WHERE user_id = %s
                ORDER BY created_at DESC
            """, (FIXED_USER_ID,))
            user_history = cur.fetchall()

            # 過去のフィードバックを取得
            if user_history:
                decision_ids = [d['id'] for d in user_history]
                cur.execute("""
                    SELECT decision_id, regret_score, satisfaction_score, regret_reasons, created_at
                    FROM feedbacks
                    WHERE decision_id = ANY(%s)
                """, (decision_ids,))
                feedbacks = cur.fetchall()
            else:
                feedbacks = []

            # 後悔予測を実行
            decision_data = {
                'category': category,
                'decision_text': decision_text,
                'alternatives': alternatives_list,
                'context': context,
                'decision_factors': decision_factors
            }
            prediction = ml_predict_regret(FIXED_USER_ID, decision_data, user_history, feedbacks)
            predicted_score = prediction.get('regret_score', None)

            # 意思決定を保存
            decision_id = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO decisions
                (id, user_id, category, decision_text, alternatives, context, decision_factors, predicted_regret_score, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
            """, (decision_id, FIXED_USER_ID, category, decision_text,
                  json.dumps(alternatives_list), json.dumps(context), json.dumps(decision_factors), predicted_score))
            conn.commit()

            cur.close()
            conn.close()

            return redirect(url_for('index'))

        except Exception as e:
            return render_template('decision_form.html', error=str(e))

    return render_template('decision_form.html')

# ルート: 後悔予測API
@app.route('/api/predict', methods=['POST'])
def predict_regret():
    try:
        data = request.get_json()

        conn = get_db_connection()
        cur = conn.cursor()

        # ユーザーの過去の意思決定を取得
        cur.execute("""
            SELECT id, category, decision_text, alternatives, context, decision_factors, created_at
            FROM decisions
            WHERE user_id = %s
            ORDER BY created_at DESC
        """, (FIXED_USER_ID,))
        user_history = cur.fetchall()

        # 過去のフィードバックを取得
        if user_history:
            decision_ids = [d['id'] for d in user_history]
            cur.execute("""
                SELECT decision_id, regret_score, satisfaction_score, regret_reasons, created_at
                FROM feedbacks
                WHERE decision_id = ANY(%s)
            """, (decision_ids,))
            feedbacks = cur.fetchall()
        else:
            feedbacks = []

        cur.close()
        conn.close()

        # ML エンジンで予測
        prediction = ml_predict_regret(
            FIXED_USER_ID,
            data,
            user_history,
            feedbacks
        )

        return jsonify(prediction)

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ルート: フィードバック入力
@app.route('/feedback/<decision_id>', methods=['GET', 'POST'])
def feedback(decision_id):
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cur = conn.cursor()

            # 意思決定の所有権確認
            cur.execute("""
                SELECT id FROM decisions
                WHERE id = %s AND user_id = %s
            """, (decision_id, FIXED_USER_ID))

            if not cur.fetchone():
                cur.close()
                conn.close()
                return redirect(url_for('index'))

            # フィードバックデータ取得
            regret_score = int(request.form.get('regret_score', 3))
            satisfaction_score = int(request.form.get('satisfaction_score', 3))
            would_change = request.form.get('would_change') == 'on'
            feedback_timing = request.form.get('feedback_timing', '1日後')
            regret_reasons = request.form.get('regret_reasons', '')

            regret_reasons_list = [r.strip() for r in regret_reasons.split(',') if r.strip()]

            # フィードバック保存
            feedback_id = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO feedbacks
                (id, decision_id, regret_score, satisfaction_score, regret_reasons, would_change, feedback_timing, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
            """, (feedback_id, decision_id, regret_score, satisfaction_score,
                  json.dumps(regret_reasons_list), would_change, feedback_timing))
            conn.commit()

            # 後悔パターンを更新
            update_patterns_after_feedback(FIXED_USER_ID, conn)

            cur.close()
            conn.close()

            return redirect(url_for('index'))

        except Exception as e:
            return render_template('feedback_form.html', decision_id=decision_id, error=str(e))

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # 意思決定情報を取得
        cur.execute("""
            SELECT id, category, decision_text, created_at
            FROM decisions
            WHERE id = %s AND user_id = %s
        """, (decision_id, FIXED_USER_ID))
        decision = cur.fetchone()

        cur.close()
        conn.close()

        if not decision:
            return redirect(url_for('index'))

        return render_template('feedback_form.html', decision=decision)

    except Exception as e:
        return redirect(url_for('index'))

# ルート: 振り返り一覧
@app.route('/feedbacks')
def feedbacks_list():
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # ユーザーの全フィードバックを取得
        cur.execute("""
            SELECT
                f.id,
                f.regret_score,
                f.satisfaction_score,
                f.regret_reasons,
                f.would_change,
                f.feedback_timing,
                f.created_at,
                d.category,
                d.decision_text,
                d.predicted_regret_score,
                d.created_at as decision_created_at
            FROM feedbacks f
            JOIN decisions d ON f.decision_id = d.id
            WHERE d.user_id = %s
            ORDER BY f.created_at DESC
        """, (FIXED_USER_ID,))
        feedbacks = cur.fetchall()

        cur.close()
        conn.close()

        return render_template('feedbacks_list.html', feedbacks=feedbacks)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return render_template('feedbacks_list.html', feedbacks=[], error=str(e))

# ルート: モデル評価実験（研究用）
@app.route('/research/evaluate', methods=['GET', 'POST'])
def research_evaluate():
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # ユーザーの履歴を取得
        cur.execute("""
            SELECT id, category, decision_text, alternatives, context, decision_factors, created_at
            FROM decisions
            WHERE user_id = %s
            ORDER BY created_at DESC
        """, (FIXED_USER_ID,))
        user_history = cur.fetchall()

        # フィードバックを取得
        if user_history:
            decision_ids = [d['id'] for d in user_history]
            cur.execute("""
                SELECT decision_id, regret_score, satisfaction_score, regret_reasons, created_at
                FROM feedbacks
                WHERE decision_id = ANY(%s)
            """, (decision_ids,))
            feedbacks = cur.fetchall()
        else:
            feedbacks = []

        cur.close()
        conn.close()

        if request.method == 'POST':
            # 実験実行
            experiment_name = request.form.get('experiment_name', 'model_comparison')
            results = run_experiment_comparison(FIXED_USER_ID, user_history, feedbacks, experiment_name)

            return render_template('research_results.html',
                                 results=results,
                                 experiment_name=experiment_name,
                                 data_size={'decisions': len(user_history), 'feedbacks': len(feedbacks)})

        # GET: 実験設定画面
        return render_template('research_evaluate.html',
                             data_size={'decisions': len(user_history), 'feedbacks': len(feedbacks)})

    except Exception as e:
        import traceback
        traceback.print_exc()
        return render_template('research_evaluate.html', error=str(e))

if __name__ == '__main__':
    app.run(debug=True, port=5000)
