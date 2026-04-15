"""
RegretLens Adaptive Features - 適応的特徴量選択システム
個人ごとに最適な特徴量セットを自動選出
"""
import numpy as np
import json
import os
from datetime import datetime
import pickle

# 機械学習ライブラリ
try:
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.preprocessing import StandardScaler
    from sklearn.feature_selection import RFE, SelectKBest, f_regression
    from sklearn.inspection import permutation_importance
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False

# SHAP (SHapley Additive exPlanations)
try:
    import shap
    SHAP_AVAILABLE = True
except ImportError:
    SHAP_AVAILABLE = False
    print("Warning: SHAP not available. Install with: pip install shap")

from ml_engine import extract_features, prepare_training_data


# 特徴量名リスト（18次元）
FEATURE_NAMES = [
    'price',
    'taste_expectation',
    'health_value',
    'time_required',
    'mood_score',
    'stress_level',
    'hunger_level',
    'budget_remaining',
    'with_others',
    'hour_of_day',
    'is_lunch_time',
    'is_dinner_time',
    'day_of_week',
    'weather_encoded',
    'user_average_regret_this_category',
    'user_regret_variance',
    'similar_past_decisions_count',
    'recent_regret_trend'
]


class AdaptiveFeatureSelector:
    """個人適応型特徴量選択クラス"""

    def __init__(self, user_id):
        self.user_id = user_id
        self.feature_names = FEATURE_NAMES.copy()
        self.selected_features = None
        self.feature_importance = {}
        self.models_dir = os.path.join(os.path.dirname(__file__), 'models')
        os.makedirs(self.models_dir, exist_ok=True)

    def calculate_feature_importance_permutation(self, X, y, model):
        """
        Permutation Importanceによる特徴量重要度計算

        Args:
            X: 特徴量行列
            y: 目的変数
            model: 訓練済みモデル

        Returns:
            dict: 特徴量名 -> 重要度
        """
        if not SKLEARN_AVAILABLE:
            return {}

        perm_importance = permutation_importance(model, X, y, n_repeats=10, random_state=42)

        importance_dict = {}
        for i, importance in enumerate(perm_importance.importances_mean):
            if i < len(self.feature_names):
                importance_dict[self.feature_names[i]] = float(importance)

        return importance_dict

    def calculate_feature_importance_shap(self, X, model, max_samples=100):
        """
        SHAP値による特徴量重要度計算（解釈可能性重視）

        Args:
            X: 特徴量行列
            model: 訓練済みモデル
            max_samples: SHAP計算のサンプル数

        Returns:
            dict: 特徴量名 -> SHAP重要度
        """
        if not SHAP_AVAILABLE:
            print("SHAP not available, falling back to permutation importance")
            return {}

        # サンプル数を制限（計算コスト削減）
        X_sample = X[:min(max_samples, len(X))]

        # TreeExplainerを使用（Random Forestに最適化）
        explainer = shap.TreeExplainer(model)
        shap_values = explainer.shap_values(X_sample)

        # 平均絶対SHAP値を計算
        mean_abs_shap = np.mean(np.abs(shap_values), axis=0)

        shap_dict = {}
        for i, importance in enumerate(mean_abs_shap):
            if i < len(self.feature_names):
                shap_dict[self.feature_names[i]] = float(importance)

        return shap_dict

    def select_features_rfe(self, X, y, n_features_to_select=10):
        """
        Recursive Feature Elimination (RFE)による特徴量選択

        Args:
            X: 特徴量行列
            y: 目的変数
            n_features_to_select: 選択する特徴量数

        Returns:
            list: 選択された特徴量のインデックス
        """
        if not SKLEARN_AVAILABLE:
            return list(range(len(self.feature_names)))

        model = RandomForestRegressor(n_estimators=50, max_depth=10, random_state=42)
        rfe = RFE(model, n_features_to_select=n_features_to_select)
        rfe.fit(X, y)

        selected_indices = [i for i, selected in enumerate(rfe.support_) if selected]
        return selected_indices

    def select_features_kbest(self, X, y, k=10):
        """
        SelectKBestによる特徴量選択（統計的手法）

        Args:
            X: 特徴量行列
            y: 目的変数
            k: 選択する特徴量数

        Returns:
            list: 選択された特徴量のインデックス
        """
        if not SKLEARN_AVAILABLE:
            return list(range(len(self.feature_names)))

        selector = SelectKBest(score_func=f_regression, k=k)
        selector.fit(X, y)

        selected_indices = selector.get_support(indices=True).tolist()
        return selected_indices

    def adaptive_feature_selection(self, user_history, feedbacks, method='shap', n_features=12):
        """
        適応的特徴量選択メイン関数

        Args:
            user_history: ユーザーの意思決定履歴
            feedbacks: フィードバックデータ
            method: 'shap', 'permutation', 'rfe', 'kbest', 'auto'
            n_features: 選択する特徴量数

        Returns:
            dict: 選択結果
        """
        if not SKLEARN_AVAILABLE:
            return {
                'error': 'scikit-learn not available',
                'selected_features': self.feature_names,
                'feature_importance': {}
            }

        # データ準備
        X, y = prepare_training_data(user_history, feedbacks)

        if len(X) < 10:
            return {
                'error': 'Insufficient data (minimum 10 samples required)',
                'selected_features': self.feature_names,
                'feature_importance': {}
            }

        # モデル訓練
        model = RandomForestRegressor(n_estimators=50, max_depth=10, random_state=42)
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        model.fit(X_scaled, y)

        # 特徴量重要度計算
        importance_dict = {}

        if method == 'shap' and SHAP_AVAILABLE:
            importance_dict = self.calculate_feature_importance_shap(X_scaled, model)
        elif method == 'permutation':
            importance_dict = self.calculate_feature_importance_permutation(X_scaled, y, model)
        elif method == 'auto':
            # SHAP利用可能ならSHAP、なければPermutation
            if SHAP_AVAILABLE:
                importance_dict = self.calculate_feature_importance_shap(X_scaled, model)
            else:
                importance_dict = self.calculate_feature_importance_permutation(X_scaled, y, model)

        # 特徴量選択
        if method in ['rfe']:
            selected_indices = self.select_features_rfe(X_scaled, y, n_features)
        elif method in ['kbest']:
            selected_indices = self.select_features_kbest(X_scaled, y, n_features)
        else:
            # 重要度の高い順にn_features個を選択
            if importance_dict:
                sorted_features = sorted(importance_dict.items(), key=lambda x: x[1], reverse=True)
                top_features = [name for name, _ in sorted_features[:n_features]]
                selected_indices = [i for i, name in enumerate(self.feature_names) if name in top_features]
            else:
                # デフォルト: 全特徴量を使用
                selected_indices = list(range(len(self.feature_names)))

        selected_feature_names = [self.feature_names[i] for i in selected_indices]

        # 結果保存
        self.selected_features = selected_feature_names
        self.feature_importance = importance_dict

        result = {
            'method': method,
            'n_features_selected': len(selected_feature_names),
            'selected_features': selected_feature_names,
            'selected_indices': selected_indices,
            'feature_importance': importance_dict,
            'training_samples': len(X)
        }

        # モデル情報を保存
        self.save_feature_selection(result)

        return result

    def get_feature_explanations(self):
        """特徴量の説明を返す"""
        explanations = {
            'price': '価格（円）',
            'taste_expectation': '味の期待度（1-5）',
            'health_value': '健康価値（1-5）',
            'time_required': '所要時間（分）',
            'mood_score': '気分（1-5）',
            'stress_level': 'ストレスレベル（1-5）',
            'hunger_level': '空腹度（1-5）',
            'budget_remaining': '予算残高（円）',
            'with_others': '他者と一緒か（0/1）',
            'hour_of_day': '時刻（0-23）',
            'is_lunch_time': 'ランチタイムか（0/1）',
            'is_dinner_time': 'ディナータイムか（0/1）',
            'day_of_week': '曜日（0-6）',
            'weather_encoded': '天気（1-4）',
            'user_average_regret_this_category': 'カテゴリ別平均後悔度',
            'user_regret_variance': '後悔度の分散',
            'similar_past_decisions_count': '類似決定の数',
            'recent_regret_trend': '最近1週間の後悔トレンド'
        }
        return explanations

    def save_feature_selection(self, result):
        """特徴量選択結果を保存"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"feature_selection_{self.user_id}_{timestamp}.json"
        filepath = os.path.join(self.models_dir, filename)

        result['metadata'] = {
            'user_id': self.user_id,
            'timestamp': timestamp,
            'datetime': datetime.now().isoformat()
        }

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

        print(f"Feature selection saved to: {filepath}")

    def load_latest_feature_selection(self):
        """最新の特徴量選択結果を読み込み"""
        import glob

        pattern = os.path.join(self.models_dir, f"feature_selection_{self.user_id}_*.json")
        files = glob.glob(pattern)

        if not files:
            return None

        # 最新ファイルを取得
        latest_file = max(files, key=os.path.getctime)

        with open(latest_file, 'r', encoding='utf-8') as f:
            result = json.load(f)

        self.selected_features = result.get('selected_features', self.feature_names)
        self.feature_importance = result.get('feature_importance', {})

        return result

    def generate_feature_importance_report(self):
        """特徴量重要度レポートを生成"""
        if not self.feature_importance:
            return "No feature importance data available"

        report = []
        report.append("=" * 60)
        report.append("Feature Importance Report")
        report.append("=" * 60)
        report.append("")

        explanations = self.get_feature_explanations()

        # 重要度順にソート
        sorted_features = sorted(self.feature_importance.items(), key=lambda x: x[1], reverse=True)

        report.append("Ranking (higher is more important):")
        report.append("-" * 60)

        for rank, (feature_name, importance) in enumerate(sorted_features, 1):
            explanation = explanations.get(feature_name, feature_name)
            selected = "✓" if self.selected_features and feature_name in self.selected_features else " "
            report.append(f"{rank:2d}. [{selected}] {feature_name:35s} {importance:.4f}")
            report.append(f"     {explanation}")

        report.append("")
        report.append("=" * 60)

        return "\n".join(report)


def analyze_user_specific_features(user_id, user_history, feedbacks):
    """
    ユーザー固有の特徴量分析を実行

    Args:
        user_id: ユーザーID
        user_history: 意思決定履歴
        feedbacks: フィードバックデータ

    Returns:
        dict: 分析結果
    """
    selector = AdaptiveFeatureSelector(user_id)

    print(f"Analyzing personalized features for user {user_id}...")
    print(f"Dataset size: {len(user_history)} decisions, {len(feedbacks)} feedbacks")
    print("")

    # 特徴量選択実行
    result = selector.adaptive_feature_selection(user_history, feedbacks, method='auto', n_features=12)

    if 'error' in result:
        print(f"Error: {result['error']}")
        return result

    # レポート生成
    report = selector.generate_feature_importance_report()
    print(report)

    result['report'] = report

    return result


if __name__ == '__main__':
    print("Adaptive Feature Selector")
    print("=" * 60)
    print("This module implements personalized feature selection.")
    print("")
    print("Usage:")
    print("from adaptive_features import AdaptiveFeatureSelector")
    print("")
    print("selector = AdaptiveFeatureSelector(user_id)")
    print("result = selector.adaptive_feature_selection(history, feedbacks)")
