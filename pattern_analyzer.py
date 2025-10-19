"""
RegretLens Pattern Analyzer - 後悔パターン分析
"""
import json
from datetime import datetime


def analyze_regret_patterns(user_id, user_history, feedbacks, conn):
    """
    ユーザーの後悔パターンを分析してデータベースに保存

    Args:
        user_id: ユーザーID
        user_history: list - ユーザーの過去の意思決定
        feedbacks: list - 過去のフィードバック
        conn: データベース接続
    """
    if not user_history or not feedbacks:
        return

    cur = conn.cursor()

    # 既存のパターンを削除
    cur.execute("DELETE FROM regret_patterns WHERE user_id = %s", (user_id,))

    patterns = []

    # パターン1: 高ストレス時のカテゴリ別後悔
    for decision in user_history:
        context = decision.get('context', {})
        if isinstance(context, str):
            try:
                context = json.loads(context)
            except:
                context = {}

        if context.get('stress_level', 0) >= 4:
            category = decision.get('category', '')
            # このdecisionのfeedbackを探す
            for feedback in feedbacks:
                if feedback.get('decision_id') == decision.get('id'):
                    if feedback.get('regret_score', 0) >= 4:
                        pattern_type = f"高ストレス時の{category}選択"
                        trigger_conditions = {
                            'stress_level_min': 4,
                            'category': category
                        }

                        # 既存のパターンを探す
                        found = False
                        for p in patterns:
                            if p['pattern_type'] == pattern_type:
                                p['regret_scores'].append(feedback.get('regret_score'))
                                p['occurrence_count'] += 1
                                found = True
                                break

                        if not found:
                            patterns.append({
                                'pattern_type': pattern_type,
                                'trigger_conditions': trigger_conditions,
                                'regret_scores': [feedback.get('regret_score')],
                                'occurrence_count': 1
                            })
                    break

    # パターン2: 高額購入の後悔
    for decision in user_history:
        factors = decision.get('decision_factors', {})
        if isinstance(factors, str):
            try:
                factors = json.loads(factors)
            except:
                factors = {}

        price = factors.get('price', 0)
        if price > 1000:
            for feedback in feedbacks:
                if feedback.get('decision_id') == decision.get('id'):
                    if feedback.get('regret_score', 0) >= 3:
                        pattern_type = "高額購入時の後悔"
                        trigger_conditions = {
                            'price_min': 1000
                        }

                        found = False
                        for p in patterns:
                            if p['pattern_type'] == pattern_type:
                                p['regret_scores'].append(feedback.get('regret_score'))
                                p['occurrence_count'] += 1
                                found = True
                                break

                        if not found:
                            patterns.append({
                                'pattern_type': pattern_type,
                                'trigger_conditions': trigger_conditions,
                                'regret_scores': [feedback.get('regret_score')],
                                'occurrence_count': 1
                            })
                    break

    # パターン3: 低期待値の選択
    for decision in user_history:
        factors = decision.get('decision_factors', {})
        if isinstance(factors, str):
            try:
                factors = json.loads(factors)
            except:
                factors = {}

        expectation = factors.get('taste_expectation', 3)
        if expectation <= 2:
            for feedback in feedbacks:
                if feedback.get('decision_id') == decision.get('id'):
                    if feedback.get('regret_score', 0) >= 3:
                        pattern_type = "低期待値の選択"
                        trigger_conditions = {
                            'expectation_max': 2
                        }

                        found = False
                        for p in patterns:
                            if p['pattern_type'] == pattern_type:
                                p['regret_scores'].append(feedback.get('regret_score'))
                                p['occurrence_count'] += 1
                                found = True
                                break

                        if not found:
                            patterns.append({
                                'pattern_type': pattern_type,
                                'trigger_conditions': trigger_conditions,
                                'regret_scores': [feedback.get('regret_score')],
                                'occurrence_count': 1
                            })
                    break

    # パターン4: 曜日別の後悔（月曜日の衝動買いなど）
    for decision in user_history:
        context = decision.get('context', {})
        if isinstance(context, str):
            try:
                context = json.loads(context)
            except:
                context = {}

        day_of_week = context.get('day_of_week', '')
        category = decision.get('category', '')

        if day_of_week:
            for feedback in feedbacks:
                if feedback.get('decision_id') == decision.get('id'):
                    if feedback.get('regret_score', 0) >= 4:
                        pattern_type = f"{day_of_week}の{category}"
                        trigger_conditions = {
                            'day_of_week': day_of_week,
                            'category': category
                        }

                        found = False
                        for p in patterns:
                            if p['pattern_type'] == pattern_type:
                                p['regret_scores'].append(feedback.get('regret_score'))
                                p['occurrence_count'] += 1
                                found = True
                                break

                        if not found:
                            patterns.append({
                                'pattern_type': pattern_type,
                                'trigger_conditions': trigger_conditions,
                                'regret_scores': [feedback.get('regret_score')],
                                'occurrence_count': 1
                            })
                    break

    # パターンをデータベースに保存
    for pattern in patterns:
        if pattern['occurrence_count'] >= 2:  # 2回以上発生したパターンのみ保存
            avg_regret = sum(pattern['regret_scores']) / len(pattern['regret_scores'])

            cur.execute("""
                INSERT INTO regret_patterns
                (user_id, pattern_type, trigger_conditions, average_regret, occurrence_count, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, NOW(), NOW())
            """, (
                user_id,
                pattern['pattern_type'],
                json.dumps(pattern['trigger_conditions']),
                avg_regret,
                pattern['occurrence_count']
            ))

    conn.commit()
    cur.close()


def update_patterns_after_feedback(user_id, conn):
    """
    フィードバック登録後にパターンを更新

    Args:
        user_id: ユーザーID
        conn: データベース接続
    """
    cur = conn.cursor()

    # ユーザーの履歴を取得
    cur.execute("""
        SELECT id, category, decision_text, alternatives, context, decision_factors, created_at
        FROM decisions
        WHERE user_id = %s
        ORDER BY created_at DESC
    """, (user_id,))
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

    # パターン分析を実行
    analyze_regret_patterns(user_id, user_history, feedbacks, conn)
