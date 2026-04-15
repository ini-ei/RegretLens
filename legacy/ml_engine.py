"""
RegretLens ML Engine - 後悔予測エンジン（機械学習 + ルールベース）
"""
import numpy as np
from datetime import datetime, timedelta
import json
import os
import pickle

# scikit-learn インポート（サーバーで pip3 install scikit-learn --user が必要）
try:
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.preprocessing import StandardScaler
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    print("Warning: scikit-learn not available. Using rule-based prediction only.")


# モデル保存パス
MODEL_DIR = os.path.join(os.path.dirname(__file__), 'models')
os.makedirs(MODEL_DIR, exist_ok=True)


def get_model_path(user_id):
    """ユーザーごとのモデルファイルパス"""
    return os.path.join(MODEL_DIR, f'model_{user_id}.pkl')


def extract_features(decision_data, user_history, feedbacks):
    """意思決定から特徴量を抽出"""
    features = {}

    # 決定要因から特徴量抽出
    factors = decision_data.get('decision_factors', {})
    features['price'] = float(factors.get('price', 0) or 0)
    features['taste_expectation'] = float(factors.get('taste_expectation', 3) or 3)
    features['health_value'] = float(factors.get('health_value', 3) or 3)
    features['time_required'] = float(factors.get('time_required', 0) or 0)

    # コンテキスト特徴量
    context = decision_data.get('context', {})
    features['mood_score'] = float(context.get('mood', 3))
    features['stress_level'] = float(context.get('stress_level', 3))
    features['hunger_level'] = float(context.get('hunger_level', 3) or 3)
    features['budget_remaining'] = float(context.get('budget_remaining', 0) or 0)
    features['with_others'] = 1.0 if context.get('with_others') else 0.0

    # 時間特徴量のエンコーディング
    time_str = context.get('time_of_day', '12:00')
    try:
        hour = int(time_str.split(':')[0])
    except:
        hour = 12
    features['hour_of_day'] = float(hour)
    features['is_lunch_time'] = 1.0 if 11 <= hour <= 13 else 0.0
    features['is_dinner_time'] = 1.0 if 18 <= hour <= 20 else 0.0

    # 曜日エンコーディング
    day_mapping = {'月曜日': 0, '火曜日': 1, '水曜日': 2, '木曜日': 3, '金曜日': 4, '土曜日': 5, '日曜日': 6}
    features['day_of_week'] = float(day_mapping.get(context.get('day_of_week', '月曜日'), 0))

    # 天気エンコーディング
    weather_mapping = {'晴れ': 1, '曇り': 2, '雨': 3, '雪': 4}
    features['weather_encoded'] = float(weather_mapping.get(context.get('weather', '晴れ'), 1))

    # ユーザー履歴特徴量
    category = decision_data.get('category', '')
    if user_history and feedbacks:
        # 同じカテゴリの過去の後悔率
        category_decisions = [d for d in user_history if d.get('category') == category]
        if category_decisions:
            category_decision_ids = [d.get('id') for d in category_decisions]
            category_feedbacks = [f for f in feedbacks if f.get('decision_id') in category_decision_ids]
            if category_feedbacks:
                regret_scores = [f.get('regret_score', 3) for f in category_feedbacks]
                if regret_scores:
                    if SKLEARN_AVAILABLE:
                        avg = np.mean(regret_scores)
                        avg = float(avg) if not np.isnan(avg) else 3.0
                    else:
                        avg = sum(regret_scores) / len(regret_scores)
                    features['user_average_regret_this_category'] = avg

                    if len(regret_scores) > 1 and SKLEARN_AVAILABLE:
                        var = np.var(regret_scores)
                        features['user_regret_variance'] = float(var) if not np.isnan(var) else 0.0
                    else:
                        features['user_regret_variance'] = 0.0
                else:
                    features['user_average_regret_this_category'] = 3.0
                    features['user_regret_variance'] = 0.0
            else:
                features['user_average_regret_this_category'] = 3.0
                features['user_regret_variance'] = 0.0
        else:
            features['user_average_regret_this_category'] = 3.0
            features['user_regret_variance'] = 0.0

        # 類似決定の数
        features['similar_past_decisions_count'] = float(len(category_decisions))

        # 最近の後悔トレンド（最近1週間）
        now = datetime.now()
        recent_feedbacks = []
        for f in feedbacks:
            created_at = f.get('created_at')
            if isinstance(created_at, str):
                try:
                    created_at = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                except:
                    continue
            if created_at and (now - created_at).days <= 7:
                recent_feedbacks.append(f)

        if recent_feedbacks:
            recent_scores = [f.get('regret_score', 3) for f in recent_feedbacks]
            if SKLEARN_AVAILABLE:
                trend = np.mean(recent_scores)
                features['recent_regret_trend'] = float(trend) if not np.isnan(trend) else 3.0
            else:
                features['recent_regret_trend'] = sum(recent_scores) / len(recent_scores) if recent_scores else 3.0
        else:
            features['recent_regret_trend'] = 3.0
    else:
        # 新規ユーザーのデフォルト値
        features['user_average_regret_this_category'] = 3.0
        features['user_regret_variance'] = 0.0
        features['similar_past_decisions_count'] = 0.0
        features['recent_regret_trend'] = 3.0

    return features


def prepare_training_data(user_history, feedbacks):
    """訓練データを準備"""
    X = []
    y = []

    for decision in user_history:
        # このdecisionのfeedbackを探す
        feedback = None
        for f in feedbacks:
            if f.get('decision_id') == decision.get('id'):
                feedback = f
                break

        if feedback is None:
            continue

        # 特徴量抽出（この決定時点での履歴を使う）
        decision_data = {
            'category': decision.get('category'),
            'decision_text': decision.get('decision_text'),
            'context': decision.get('context', {}),
            'decision_factors': decision.get('decision_factors', {})
        }

        # この決定より前の履歴のみ使用
        past_history = [d for d in user_history if d.get('created_at', '') < decision.get('created_at', '')]
        past_feedbacks = [f for f in feedbacks if any(d.get('id') == f.get('decision_id') for d in past_history)]

        features = extract_features(decision_data, past_history, past_feedbacks)

        # 特徴ベクトルに変換
        feature_vector = [
            features['price'],
            features['taste_expectation'],
            features['health_value'],
            features['time_required'],
            features['mood_score'],
            features['stress_level'],
            features['hunger_level'],
            features['budget_remaining'],
            features['with_others'],
            features['hour_of_day'],
            features['is_lunch_time'],
            features['is_dinner_time'],
            features['day_of_week'],
            features['weather_encoded'],
            features['user_average_regret_this_category'],
            features['user_regret_variance'],
            features['similar_past_decisions_count'],
            features['recent_regret_trend']
        ]

        X.append(feature_vector)
        # 後悔スコアを0-1に正規化（1-5 → 0-1）
        y.append((feedback.get('regret_score', 3) - 1) / 4.0)

    return np.array(X), np.array(y)


def train_model(user_id, user_history, feedbacks):
    """
    機械学習モデルを訓練
    最低10件のフィードバックが必要
    """
    if not SKLEARN_AVAILABLE:
        return None

    # データ準備
    X, y = prepare_training_data(user_history, feedbacks)

    # 最低10件のデータが必要
    if len(X) < 10:
        return None

    # モデル訓練
    model = {
        'regressor': RandomForestRegressor(n_estimators=50, max_depth=10, random_state=42),
        'scaler': StandardScaler()
    }

    # 特徴量の標準化
    X_scaled = model['scaler'].fit_transform(X)

    # モデル訓練
    model['regressor'].fit(X_scaled, y)

    # モデル保存
    model_path = get_model_path(user_id)
    with open(model_path, 'wb') as f:
        pickle.dump(model, f)

    return model


def load_model(user_id):
    """保存されたモデルを読み込み"""
    model_path = get_model_path(user_id)
    if not os.path.exists(model_path):
        return None

    try:
        with open(model_path, 'rb') as f:
            return pickle.load(f)
    except:
        return None


def predict_with_ml(features, model):
    """機械学習モデルで予測"""
    feature_vector = np.array([[
        features['price'],
        features['taste_expectation'],
        features['health_value'],
        features['time_required'],
        features['mood_score'],
        features['stress_level'],
        features['hunger_level'],
        features['budget_remaining'],
        features['with_others'],
        features['hour_of_day'],
        features['is_lunch_time'],
        features['is_dinner_time'],
        features['day_of_week'],
        features['weather_encoded'],
        features['user_average_regret_this_category'],
        features['user_regret_variance'],
        features['similar_past_decisions_count'],
        features['recent_regret_trend']
    ]])

    # 標準化
    X_scaled = model['scaler'].transform(feature_vector)

    # 予測（0-1の範囲）
    prediction = model['regressor'].predict(X_scaled)[0]

    return min(1.0, max(0.0, prediction))


def calculate_regret_score_rule_based(features, decision_data, user_history, feedbacks):
    """ルールベースで後悔スコアを計算（機械学習のフォールバック）"""
    score = 0.3  # ベーススコア

    # ストレスが高い場合
    if features['stress_level'] >= 4:
        score += 0.2

    # 価格が高い場合
    if features['price'] > 1000:
        score += 0.15

    # 過去の同カテゴリの後悔率が高い場合
    if features['user_average_regret_this_category'] >= 4:
        score += 0.25

    # 最近の後悔トレンドが高い場合
    if features['recent_regret_trend'] >= 4:
        score += 0.15

    # 期待値が低い場合
    if features['taste_expectation'] <= 2:
        score += 0.2

    # 気分が悪い場合
    if features['mood_score'] <= 2:
        score += 0.1

    # 空腹度が極端な場合（判断力低下）
    if features['hunger_level'] >= 5:
        score += 0.15

    # 予算残りが少ない場合
    if features['budget_remaining'] < features['price']:
        score += 0.2

    return min(1.0, max(0.0, score))


def generate_warnings(features, decision_data, user_history, feedbacks):
    """警告メッセージを生成"""
    warnings = []
    category = decision_data.get('category', '')

    # ストレスレベルチェック
    if features['stress_level'] >= 4:
        category_high_stress_regrets = 0
        if user_history and feedbacks:
            for d in user_history:
                if d.get('category') == category:
                    context = d.get('context', {})
                    if context.get('stress_level', 0) >= 4:
                        for f in feedbacks:
                            if f.get('decision_id') == d.get('id') and f.get('regret_score', 0) >= 4:
                                category_high_stress_regrets += 1
                                break

        if category_high_stress_regrets > 0:
            warnings.append(f"⚠️ あなたは疲れている時に{category}の選択で後悔しやすい傾向があります（過去{category_high_stress_regrets}回）")

    # 価格チェック
    if features['price'] > 1000:
        expensive_decisions = []
        if user_history:
            for d in user_history:
                factors = d.get('decision_factors', {})
                if isinstance(factors, str):
                    try:
                        factors = json.loads(factors)
                    except:
                        factors = {}
                if factors.get('price', 0) > 1000:
                    expensive_decisions.append(d)

        if expensive_decisions and feedbacks:
            expensive_decision_ids = [d.get('id') for d in expensive_decisions]
            expensive_feedbacks = [f for f in feedbacks if f.get('decision_id') in expensive_decision_ids]
            if expensive_feedbacks:
                satisfaction_scores = [f.get('satisfaction_score', 3) for f in expensive_feedbacks]
                if SKLEARN_AVAILABLE:
                    avg_satisfaction = np.mean(satisfaction_scores)
                    avg_satisfaction = float(avg_satisfaction) if not np.isnan(avg_satisfaction) else 3.0
                else:
                    avg_satisfaction = sum(satisfaction_scores) / len(satisfaction_scores) if satisfaction_scores else 3.0
                if avg_satisfaction < 3.5:
                    warnings.append(f"💰 この価格帯の選択では、満足度が期待を下回ることが多いです（平均満足度: {avg_satisfaction:.1f}/5.0）")

    # 期待値チェック
    if features['taste_expectation'] <= 2:
        warnings.append("📉 期待値が低い選択は後悔につながりやすいです")

    # 空腹度チェック
    if features['hunger_level'] >= 5:
        warnings.append("🍽️ 極度の空腹時は判断力が低下します。落ち着いて選択することをお勧めします")

    # 予算チェック
    if features['budget_remaining'] < features['price']:
        warnings.append("💸 予算を超過しています。経済的なストレスにつながる可能性があります")

    # 過去の後悔率が高い
    if features['user_average_regret_this_category'] >= 4:
        warnings.append(f"📊 {category}カテゴリでの過去の平均後悔度が高いです（{features['user_average_regret_this_category']:.1f}/5.0）")

    return warnings


def find_similar_cases(decision_data, user_history, feedbacks, limit=3):
    """類似の過去ケースを検索"""
    similar_cases = []
    category = decision_data.get('category', '')

    if not user_history or not feedbacks:
        return similar_cases

    # 同じカテゴリの決定を検索
    category_decisions = [d for d in user_history if d.get('category') == category]

    # 後悔度が高い順にソート
    decisions_with_regret = []
    for decision in category_decisions:
        for feedback in feedbacks:
            if feedback.get('decision_id') == decision.get('id'):
                if feedback.get('regret_score', 0) >= 3:
                    decisions_with_regret.append({
                        'decision': decision,
                        'feedback': feedback
                    })
                break

    # 最新のものから取得
    decisions_with_regret.sort(key=lambda x: x['decision'].get('created_at', ''), reverse=True)

    for item in decisions_with_regret[:limit]:
        decision = item['decision']
        feedback = item['feedback']

        created_at = decision.get('created_at', '')
        if isinstance(created_at, datetime):
            date_str = created_at.strftime("%Y年%m月%d日")
        else:
            try:
                dt = datetime.fromisoformat(str(created_at).replace('Z', '+00:00'))
                date_str = dt.strftime("%Y年%m月%d日")
            except:
                date_str = "過去"

        reasons = feedback.get('regret_reasons', [])
        if isinstance(reasons, str):
            try:
                reasons = json.loads(reasons)
            except:
                reasons = []

        reason_text = reasons[0] if reasons else "理由なし"

        similar_cases.append({
            "date": date_str,
            "decision_text": decision.get('decision_text', ''),
            "regret_score": feedback.get('regret_score', 0),
            "reason": reason_text
        })

    return similar_cases


def predict_regret(user_id, decision_data, user_history, feedbacks):
    """
    後悔リスクを予測（機械学習 + ルールベースのハイブリッド）

    Args:
        user_id: ユーザーID
        decision_data: dict - 意思決定データ
        user_history: list - ユーザーの過去の意思決定
        feedbacks: list - 過去のフィードバック

    Returns:
        dict: {
            'regret_score': float,
            'risk_level': str,
            'warnings': list,
            'similar_cases': list,
            'prediction_method': str
        }
    """
    # 特徴量抽出
    features = extract_features(decision_data, user_history, feedbacks)

    # 機械学習モデルを試みる
    regret_score = None
    prediction_method = 'rule_based'

    if SKLEARN_AVAILABLE and len(feedbacks) >= 10:
        # モデルをロードまたは訓練
        model = load_model(user_id)
        if model is None:
            # モデルが存在しない場合は訓練
            model = train_model(user_id, user_history, feedbacks)

        if model is not None:
            try:
                regret_score = predict_with_ml(features, model)
                prediction_method = 'machine_learning'
            except:
                # ML予測失敗時はルールベースにフォールバック
                regret_score = None

    # ルールベースにフォールバック
    if regret_score is None:
        regret_score = calculate_regret_score_rule_based(features, decision_data, user_history, feedbacks)

    # リスクレベル判定
    if regret_score >= 0.7:
        risk_level = "高"
    elif regret_score >= 0.4:
        risk_level = "中"
    else:
        risk_level = "低"

    # 警告生成
    warnings = generate_warnings(features, decision_data, user_history, feedbacks)

    # 類似ケース検索
    similar_cases = find_similar_cases(decision_data, user_history, feedbacks, limit=3)

    return {
        'regret_score': round(regret_score, 2),
        'risk_level': risk_level,
        'warnings': warnings,
        'similar_cases': similar_cases,
        'prediction_method': prediction_method,
        'features': features  # デバッグ用
    }
