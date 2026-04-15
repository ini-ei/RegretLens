"""
RegretLens Model Evaluator - モデル評価・比較フレームワーク
論文用の実験基盤システム
"""
import numpy as np
import json
import os
from datetime import datetime
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.metrics import precision_score, recall_score, f1_score, roc_auc_score, accuracy_score
import pickle

# XGBoost (オプション)
try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError:
    XGBOOST_AVAILABLE = False
    print("Warning: XGBoost not available. Install with: pip install xgboost")

# 既存のml_engineをインポート
from ml_engine import (
    extract_features,
    prepare_training_data,
    predict_with_ml,
    calculate_regret_score_rule_based,
    SKLEARN_AVAILABLE
)


class ModelEvaluator:
    """モデル性能評価・比較クラス"""

    def __init__(self, user_id):
        self.user_id = user_id
        self.results_dir = os.path.join(os.path.dirname(__file__), 'evaluation_results')
        os.makedirs(self.results_dir, exist_ok=True)

    def time_series_cross_validation(self, user_history, feedbacks, n_splits=5):
        """
        時系列交差検証

        Args:
            user_history: ユーザーの意思決定履歴
            feedbacks: フィードバックデータ
            n_splits: 分割数

        Returns:
            dict: モデル別の評価結果
        """
        if not SKLEARN_AVAILABLE:
            return {"error": "scikit-learn not available"}

        # データ準備
        X, y = prepare_training_data(user_history, feedbacks)

        if len(X) < 10:
            return {"error": "Insufficient data for cross-validation (minimum 10 samples required)"}

        # 時系列分割
        tscv = TimeSeriesSplit(n_splits=min(n_splits, len(X) // 2))

        results = {
            'random_forest': {'mae': [], 'rmse': [], 'r2': []},
            'rule_based': {'mae': [], 'rmse': [], 'r2': []},
        }

        if XGBOOST_AVAILABLE:
            results['xgboost'] = {'mae': [], 'rmse': [], 'r2': []}

        for fold_idx, (train_index, test_index) in enumerate(tscv.split(X)):
            X_train, X_test = X[train_index], X[test_index]
            y_train, y_test = y[train_index], y[test_index]

            # Random Forest
            if SKLEARN_AVAILABLE:
                from sklearn.ensemble import RandomForestRegressor
                from sklearn.preprocessing import StandardScaler

                rf_model = RandomForestRegressor(n_estimators=50, max_depth=10, random_state=42)
                scaler = StandardScaler()
                X_train_scaled = scaler.fit_transform(X_train)
                X_test_scaled = scaler.transform(X_test)
                rf_model.fit(X_train_scaled, y_train)
                rf_pred = rf_model.predict(X_test_scaled)

                results['random_forest']['mae'].append(mean_absolute_error(y_test, rf_pred))
                results['random_forest']['rmse'].append(np.sqrt(mean_squared_error(y_test, rf_pred)))
                results['random_forest']['r2'].append(r2_score(y_test, rf_pred))

            # XGBoost
            if XGBOOST_AVAILABLE:
                xgb_model = xgb.XGBRegressor(
                    n_estimators=100,
                    max_depth=6,
                    learning_rate=0.1,
                    random_state=42
                )
                xgb_model.fit(X_train, y_train)
                xgb_pred = xgb_model.predict(X_test)

                results['xgboost']['mae'].append(mean_absolute_error(y_test, xgb_pred))
                results['xgboost']['rmse'].append(np.sqrt(mean_squared_error(y_test, xgb_pred)))
                results['xgboost']['r2'].append(r2_score(y_test, xgb_pred))

            # Rule-based (baseline)
            rule_pred = []
            for i in test_index:
                decision = user_history[i]
                decision_data = {
                    'category': decision.get('category'),
                    'context': decision.get('context', {}),
                    'decision_factors': decision.get('decision_factors', {})
                }
                past_history = [user_history[j] for j in range(len(user_history)) if j < i]
                past_feedbacks = [f for f in feedbacks if any(d.get('id') == f.get('decision_id') for d in past_history)]

                features = extract_features(decision_data, past_history, past_feedbacks)
                score = calculate_regret_score_rule_based(features, decision_data, past_history, past_feedbacks)
                rule_pred.append(score)

            results['rule_based']['mae'].append(mean_absolute_error(y_test, rule_pred))
            results['rule_based']['rmse'].append(np.sqrt(mean_squared_error(y_test, rule_pred)))
            results['rule_based']['r2'].append(r2_score(y_test, rule_pred))

        # 平均を計算
        summary = {}
        for model_name, metrics in results.items():
            summary[model_name] = {
                'mae_mean': float(np.mean(metrics['mae'])),
                'mae_std': float(np.std(metrics['mae'])),
                'rmse_mean': float(np.mean(metrics['rmse'])),
                'rmse_std': float(np.std(metrics['rmse'])),
                'r2_mean': float(np.mean(metrics['r2'])),
                'r2_std': float(np.std(metrics['r2'])),
            }

        return summary

    def evaluate_classification(self, y_true, y_pred, threshold_high=0.7, threshold_low=0.4):
        """
        後悔リスクの分類評価（高/中/低）

        Args:
            y_true: 実際の後悔スコア (0-1)
            y_pred: 予測後悔スコア (0-1)
            threshold_high: 高リスクの閾値
            threshold_low: 低リスクの閾値

        Returns:
            dict: 分類評価指標
        """
        # 3クラス分類に変換
        y_true_class = np.where(y_true >= threshold_high, 2,
                               np.where(y_true >= threshold_low, 1, 0))
        y_pred_class = np.where(y_pred >= threshold_high, 2,
                               np.where(y_pred >= threshold_low, 1, 0))

        return {
            'accuracy': float(accuracy_score(y_true_class, y_pred_class)),
            'precision_macro': float(precision_score(y_true_class, y_pred_class, average='macro', zero_division=0)),
            'recall_macro': float(recall_score(y_true_class, y_pred_class, average='macro', zero_division=0)),
            'f1_macro': float(f1_score(y_true_class, y_pred_class, average='macro', zero_division=0)),
        }

    def calculate_regret_reduction_rate(self, decisions_before, feedbacks_before,
                                       decisions_after, feedbacks_after):
        """
        Regret Reduction Rate (RRR) を計算
        システム介入前後の後悔率の変化を測定

        Args:
            decisions_before: 介入前の意思決定
            feedbacks_before: 介入前のフィードバック
            decisions_after: 介入後の意思決定
            feedbacks_after: 介入後のフィードバック

        Returns:
            dict: RRR関連指標
        """
        # 介入前の平均後悔度
        regret_scores_before = [f.get('regret_score', 3) for f in feedbacks_before]
        avg_regret_before = np.mean(regret_scores_before) if regret_scores_before else 3.0

        # 介入後の平均後悔度
        regret_scores_after = [f.get('regret_score', 3) for f in feedbacks_after]
        avg_regret_after = np.mean(regret_scores_after) if regret_scores_after else 3.0

        # RRR計算
        if avg_regret_before > 0:
            rrr = (avg_regret_before - avg_regret_after) / avg_regret_before
        else:
            rrr = 0.0

        # 統計的検定 (t-test)
        from scipy import stats
        t_stat, p_value = stats.ttest_ind(regret_scores_before, regret_scores_after)

        return {
            'avg_regret_before': float(avg_regret_before),
            'avg_regret_after': float(avg_regret_after),
            'regret_reduction_rate': float(rrr),
            'absolute_reduction': float(avg_regret_before - avg_regret_after),
            't_statistic': float(t_stat),
            'p_value': float(p_value),
            'significant': p_value < 0.05,
            'n_before': len(regret_scores_before),
            'n_after': len(regret_scores_after)
        }

    def calculate_prediction_following_rate(self, user_behavior_logs):
        """
        予測に従った割合を計算

        Args:
            user_behavior_logs: ユーザー行動ログ

        Returns:
            dict: 予測追従率
        """
        if not user_behavior_logs:
            return {'following_rate': 0.0, 'n_decisions': 0}

        followed_count = sum(1 for log in user_behavior_logs if log.get('followed_prediction', False))
        total_count = len(user_behavior_logs)

        # リスクレベル別の分析
        high_risk_logs = [log for log in user_behavior_logs if log.get('predicted_regret', 0) >= 0.7]
        high_risk_followed = sum(1 for log in high_risk_logs if log.get('followed_prediction', False))

        return {
            'overall_following_rate': float(followed_count / total_count) if total_count > 0 else 0.0,
            'high_risk_following_rate': float(high_risk_followed / len(high_risk_logs)) if high_risk_logs else 0.0,
            'n_decisions': total_count,
            'n_high_risk': len(high_risk_logs)
        }

    def save_evaluation_results(self, results, experiment_name):
        """
        評価結果を保存

        Args:
            results: 評価結果辞書
            experiment_name: 実験名
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{experiment_name}_{self.user_id}_{timestamp}.json"
        filepath = os.path.join(self.results_dir, filename)

        # メタデータ追加
        results['metadata'] = {
            'user_id': self.user_id,
            'experiment_name': experiment_name,
            'timestamp': timestamp,
            'datetime': datetime.now().isoformat()
        }

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)

        print(f"Results saved to: {filepath}")
        return filepath

    def generate_comparison_report(self, cv_results):
        """
        モデル比較レポートを生成

        Args:
            cv_results: 交差検証結果

        Returns:
            str: テキストレポート
        """
        report = []
        report.append("=" * 60)
        report.append("Model Performance Comparison Report")
        report.append("=" * 60)
        report.append("")

        # モデルをMAEでソート
        models_sorted = sorted(cv_results.items(), key=lambda x: x[1]['mae_mean'])

        report.append("Ranking by MAE (lower is better):")
        report.append("-" * 60)
        for rank, (model_name, metrics) in enumerate(models_sorted, 1):
            report.append(f"{rank}. {model_name.upper()}")
            report.append(f"   MAE:  {metrics['mae_mean']:.4f} (±{metrics['mae_std']:.4f})")
            report.append(f"   RMSE: {metrics['rmse_mean']:.4f} (±{metrics['rmse_std']:.4f})")
            report.append(f"   R²:   {metrics['r2_mean']:.4f} (±{metrics['r2_std']:.4f})")
            report.append("")

        # ベストモデル
        best_model = models_sorted[0][0]
        report.append(f"Best Model: {best_model.upper()}")
        report.append("=" * 60)

        return "\n".join(report)


def run_experiment_comparison(user_id, user_history, feedbacks, experiment_name="model_comparison"):
    """
    モデル比較実験を実行

    Args:
        user_id: ユーザーID
        user_history: 意思決定履歴
        feedbacks: フィードバックデータ
        experiment_name: 実験名

    Returns:
        dict: 実験結果
    """
    evaluator = ModelEvaluator(user_id)

    print(f"Running {experiment_name} for user {user_id}...")
    print(f"Dataset size: {len(user_history)} decisions, {len(feedbacks)} feedbacks")
    print("")

    # 交差検証実行
    cv_results = evaluator.time_series_cross_validation(user_history, feedbacks, n_splits=5)

    if 'error' in cv_results:
        print(f"Error: {cv_results['error']}")
        return cv_results

    # レポート生成
    report = evaluator.generate_comparison_report(cv_results)
    print(report)

    # 結果保存
    results = {
        'cross_validation': cv_results,
        'report': report
    }

    filepath = evaluator.save_evaluation_results(results, experiment_name)

    return results


if __name__ == '__main__':
    # テスト実行
    print("Model Evaluator Test")
    print("=" * 60)
    print("To use this module, import it in your application:")
    print("")
    print("from model_evaluator import ModelEvaluator, run_experiment_comparison")
    print("")
    print("Example:")
    print("evaluator = ModelEvaluator(user_id)")
    print("results = evaluator.time_series_cross_validation(history, feedbacks)")
