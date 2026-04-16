"""
実験1: モデル性能比較
目的: 提案手法（Random Forest + 適応的特徴量選択）が既存手法より優れていることを示す
"""
import numpy as np
import json
import os
from datetime import datetime
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['font.family'] = 'DejaVu Sans'
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from scipy import stats

from generate_synthetic_data import SyntheticDataGenerator
from ml_engine import extract_features, prepare_training_data, calculate_regret_score_rule_based
from adaptive_features import AdaptiveFeatureSelector


class Experiment1:
    """実験1: モデル性能比較"""

    def __init__(self, seed=42):
        self.seed = seed
        self.results_dir = 'results'
        os.makedirs(self.results_dir, exist_ok=True)

    def train_test_split_temporal(self, decisions, feedbacks, train_ratio=0.8):
        """
        時系列を考慮した訓練/テスト分割

        Args:
            decisions: 意思決定リスト
            feedbacks: フィードバックリスト
            train_ratio: 訓練データの比率

        Returns:
            tuple: (train_decisions, train_feedbacks, test_decisions, test_feedbacks)
        """
        n_train = int(len(decisions) * train_ratio)

        train_decisions = decisions[:n_train]
        test_decisions = decisions[n_train:]

        train_decision_ids = [d['id'] for d in train_decisions]
        test_decision_ids = [d['id'] for d in test_decisions]

        train_feedbacks = [f for f in feedbacks if f['decision_id'] in train_decision_ids]
        test_feedbacks = [f for f in feedbacks if f['decision_id'] in test_decision_ids]

        return train_decisions, train_feedbacks, test_decisions, test_feedbacks

    def evaluate_rule_based(self, test_decisions, test_feedbacks, all_decisions, all_feedbacks):
        """
        ルールベース手法を評価

        Args:
            test_decisions: テスト用意思決定
            test_feedbacks: テスト用フィードバック
            all_decisions: 全意思決定（履歴用）
            all_feedbacks: 全フィードバック（履歴用）

        Returns:
            dict: 評価結果
        """
        predictions = []
        actuals = []

        for decision in test_decisions:
            # この決定より前の履歴を取得
            decision_time = decision['created_at']
            past_decisions = [d for d in all_decisions if d['created_at'] < decision_time]
            past_decision_ids = [d['id'] for d in past_decisions]
            past_feedbacks = [f for f in all_feedbacks if f['decision_id'] in past_decision_ids]

            # 特徴量抽出
            decision_data = {
                'category': decision['category'],
                'context': decision['context'],
                'decision_factors': decision['decision_factors']
            }
            features = extract_features(decision_data, past_decisions, past_feedbacks)

            # ルールベースで予測
            pred_score = calculate_regret_score_rule_based(features, decision_data, past_decisions, past_feedbacks)
            predictions.append(pred_score)

            # 実際の後悔スコア（正規化: 1-5 → 0-1）
            feedback = next(f for f in test_feedbacks if f['decision_id'] == decision['id'])
            actual_score = (feedback['regret_score'] - 1) / 4.0
            actuals.append(actual_score)

        predictions = np.array(predictions)
        actuals = np.array(actuals)

        return {
            'mae': mean_absolute_error(actuals, predictions),
            'rmse': np.sqrt(mean_squared_error(actuals, predictions)),
            'r2': r2_score(actuals, predictions),
            'predictions': predictions.tolist(),
            'actuals': actuals.tolist()
        }

    def evaluate_random_forest_full(self, train_decisions, train_feedbacks, test_decisions, test_feedbacks):
        """
        Random Forest（全18特徴量）を評価

        Args:
            train_decisions: 訓練用意思決定
            train_feedbacks: 訓練用フィードバック
            test_decisions: テスト用意思決定
            test_feedbacks: テスト用フィードバック

        Returns:
            dict: 評価結果
        """
        # 訓練データ準備
        X_train, y_train = prepare_training_data(train_decisions, train_feedbacks)

        if len(X_train) < 10:
            return {'error': 'Insufficient training data'}

        # モデル訓練
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)

        model = RandomForestRegressor(n_estimators=50, max_depth=10, random_state=self.seed)
        model.fit(X_train_scaled, y_train)

        # テストデータ準備
        X_test = []
        actuals = []

        for decision in test_decisions:
            # 特徴量抽出
            decision_data = {
                'category': decision['category'],
                'context': decision['context'],
                'decision_factors': decision['decision_factors']
            }
            features = extract_features(decision_data, train_decisions, train_feedbacks)

            # 特徴ベクトル
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
            X_test.append(feature_vector)

            # 実際の後悔スコア
            feedback = next(f for f in test_feedbacks if f['decision_id'] == decision['id'])
            actual_score = (feedback['regret_score'] - 1) / 4.0
            actuals.append(actual_score)

        X_test = np.array(X_test)
        actuals = np.array(actuals)

        # 予測
        X_test_scaled = scaler.transform(X_test)
        predictions = model.predict(X_test_scaled)
        predictions = np.clip(predictions, 0, 1)

        return {
            'mae': mean_absolute_error(actuals, predictions),
            'rmse': np.sqrt(mean_squared_error(actuals, predictions)),
            'r2': r2_score(actuals, predictions),
            'predictions': predictions.tolist(),
            'actuals': actuals.tolist()
        }

    def evaluate_random_forest_adaptive(self, train_decisions, train_feedbacks, test_decisions, test_feedbacks, user_id):
        """
        Random Forest + 適応的特徴量選択（提案手法）を評価

        Args:
            train_decisions: 訓練用意思決定
            train_feedbacks: 訓練用フィードバック
            test_decisions: テスト用意思決定
            test_feedbacks: テスト用フィードバック
            user_id: ユーザーID

        Returns:
            dict: 評価結果
        """
        # 適応的特徴量選択
        selector = AdaptiveFeatureSelector(user_id)
        selection_result = selector.adaptive_feature_selection(
            train_decisions,
            train_feedbacks,
            method='auto',
            n_features=12
        )

        if 'error' in selection_result:
            return {'error': selection_result['error']}

        selected_indices = selection_result['selected_indices']

        # 訓練データ準備
        X_train_full, y_train = prepare_training_data(train_decisions, train_feedbacks)
        X_train = X_train_full[:, selected_indices]  # 選択された特徴量のみ

        # モデル訓練
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)

        model = RandomForestRegressor(n_estimators=50, max_depth=10, random_state=self.seed)
        model.fit(X_train_scaled, y_train)

        # テストデータ準備
        X_test_full = []
        actuals = []

        for decision in test_decisions:
            # 特徴量抽出
            decision_data = {
                'category': decision['category'],
                'context': decision['context'],
                'decision_factors': decision['decision_factors']
            }
            features = extract_features(decision_data, train_decisions, train_feedbacks)

            # 特徴ベクトル（全18次元）
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
            X_test_full.append(feature_vector)

            # 実際の後悔スコア
            feedback = next(f for f in test_feedbacks if f['decision_id'] == decision['id'])
            actual_score = (feedback['regret_score'] - 1) / 4.0
            actuals.append(actual_score)

        X_test_full = np.array(X_test_full)
        X_test = X_test_full[:, selected_indices]  # 選択された特徴量のみ
        actuals = np.array(actuals)

        # 予測
        X_test_scaled = scaler.transform(X_test)
        predictions = model.predict(X_test_scaled)
        predictions = np.clip(predictions, 0, 1)

        return {
            'mae': mean_absolute_error(actuals, predictions),
            'rmse': np.sqrt(mean_squared_error(actuals, predictions)),
            'r2': r2_score(actuals, predictions),
            'predictions': predictions.tolist(),
            'actuals': actuals.tolist(),
            'selected_features': selection_result['selected_features'],
            'n_features': len(selected_indices)
        }

    def run_experiment(self, n_users=100, decisions_per_user=100):
        """
        実験1を実行

        Args:
            n_users: ユーザー数
            decisions_per_user: ユーザーあたりの決定数

        Returns:
            dict: 実験結果
        """
        print("=" * 80)
        print("実験1: モデル性能比較")
        print("=" * 80)
        print(f"ユーザー数: {n_users}")
        print(f"決定数/ユーザー: {decisions_per_user}")
        print("")

        # データ生成
        print("データ生成中...")
        generator = SyntheticDataGenerator(seed=self.seed)
        dataset = generator.generate_dataset(n_users=n_users, decisions_per_user=decisions_per_user)
        print("")

        # ユーザーごとに評価
        results_by_user = {
            'rule_based': [],
            'random_forest_full': [],
            'random_forest_adaptive': []
        }

        for user_idx, user in enumerate(dataset['users']):
            user_id = user['user_id']

            # このユーザーのデータを抽出
            user_decisions = [d for d in dataset['decisions'] if d['user_id'] == user_id]
            user_feedbacks = [f for f in dataset['feedbacks'] if f['user_id'] == user_id]

            # 時系列分割（80/20）
            train_decisions, train_feedbacks, test_decisions, test_feedbacks = \
                self.train_test_split_temporal(user_decisions, user_feedbacks, train_ratio=0.8)

            # 手法1: ルールベース
            rule_result = self.evaluate_rule_based(test_decisions, test_feedbacks, user_decisions, user_feedbacks)
            results_by_user['rule_based'].append(rule_result['mae'])

            # 手法2: Random Forest（全18特徴量）
            rf_full_result = self.evaluate_random_forest_full(train_decisions, train_feedbacks, test_decisions, test_feedbacks)
            if 'error' not in rf_full_result:
                results_by_user['random_forest_full'].append(rf_full_result['mae'])
            else:
                results_by_user['random_forest_full'].append(np.nan)

            # 手法3: Random Forest + 適応的特徴量選択
            rf_adaptive_result = self.evaluate_random_forest_adaptive(train_decisions, train_feedbacks, test_decisions, test_feedbacks, user_id)
            if 'error' not in rf_adaptive_result:
                results_by_user['random_forest_adaptive'].append(rf_adaptive_result['mae'])
            else:
                results_by_user['random_forest_adaptive'].append(np.nan)

            if (user_idx + 1) % 10 == 0:
                print(f"評価完了: {user_idx + 1}/{n_users} ユーザー")

        print("\n実験完了！\n")

        # 統計量計算
        summary = {}
        for method_name, mae_list in results_by_user.items():
            mae_array = np.array([m for m in mae_list if not np.isnan(m)])
            summary[method_name] = {
                'mae_mean': float(np.mean(mae_array)),
                'mae_std': float(np.std(mae_array)),
                'mae_min': float(np.min(mae_array)),
                'mae_max': float(np.max(mae_array)),
                'n_users': len(mae_array)
            }

        # t検定（提案手法 vs Random Forest全特徴量）
        rf_full_mae = np.array([m for m in results_by_user['random_forest_full'] if not np.isnan(m)])
        rf_adaptive_mae = np.array([m for m in results_by_user['random_forest_adaptive'] if not np.isnan(m)])

        if len(rf_full_mae) > 0 and len(rf_adaptive_mae) > 0:
            t_stat, p_value = stats.ttest_rel(rf_full_mae, rf_adaptive_mae)
            summary['statistical_test'] = {
                't_statistic': float(t_stat),
                'p_value': float(p_value),
                'significant': bool(p_value < 0.01)
            }

        # 結果表示
        print("=" * 80)
        print("結果サマリー")
        print("=" * 80)
        for method_name, stats_dict in summary.items():
            if method_name != 'statistical_test':
                print(f"\n{method_name}:")
                print(f"  MAE = {stats_dict['mae_mean']:.4f} ± {stats_dict['mae_std']:.4f}")
                print(f"  範囲: [{stats_dict['mae_min']:.4f}, {stats_dict['mae_max']:.4f}]")

        if 'statistical_test' in summary:
            print(f"\n統計的有意性検定 (RF全特徴 vs RF適応):")
            print(f"  t統計量 = {summary['statistical_test']['t_statistic']:.4f}")
            print(f"  p値 = {summary['statistical_test']['p_value']:.6f}")
            print(f"  有意差あり (p<0.01): {summary['statistical_test']['significant']}")

        print("=" * 80)

        # 結果保存
        result_data = {
            'summary': summary,
            'results_by_user': results_by_user,
            'metadata': {
                'n_users': n_users,
                'decisions_per_user': decisions_per_user,
                'seed': self.seed,
                'timestamp': datetime.now().isoformat()
            }
        }

        result_file = os.path.join(self.results_dir, 'exp1_model_comparison.json')
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(result_data, f, indent=2, ensure_ascii=False)
        print(f"\n結果を保存しました: {result_file}\n")

        return result_data

    def visualize_results(self, result_data):
        """
        結果を可視化

        Args:
            result_data: 実験結果
        """
        print("結果を可視化中...")

        # データ準備
        methods = ['rule_based', 'random_forest_full', 'random_forest_adaptive']
        method_labels = ['ルールベース', 'Random Forest\n(全18特徴量)', 'Random Forest\n+ 適応的選択\n(提案手法)']

        mae_means = [result_data['summary'][m]['mae_mean'] for m in methods]
        mae_stds = [result_data['summary'][m]['mae_std'] for m in methods]

        # 図1: 棒グラフ（MAE比較）
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

        # 棒グラフ
        x_pos = np.arange(len(methods))
        colors = ['#ff9999', '#66b3ff', '#99ff99']
        bars = ax1.bar(x_pos, mae_means, yerr=mae_stds, capsize=5, color=colors, alpha=0.8, edgecolor='black')

        ax1.set_xlabel('手法', fontsize=12)
        ax1.set_ylabel('MAE (Mean Absolute Error)', fontsize=12)
        ax1.set_title('実験1: モデル性能比較', fontsize=14, fontweight='bold')
        ax1.set_xticks(x_pos)
        ax1.set_xticklabels(method_labels, fontsize=10)
        ax1.grid(axis='y', alpha=0.3)

        # 値を棒の上に表示
        for bar, mean_val in zip(bars, mae_means):
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height,
                    f'{mean_val:.4f}',
                    ha='center', va='bottom', fontsize=10)

        # 箱ひげ図
        mae_data = [
            [m for m in result_data['results_by_user'][method] if not np.isnan(m)]
            for method in methods
        ]

        bp = ax2.boxplot(mae_data, labels=method_labels, patch_artist=True)
        for patch, color in zip(bp['boxes'], colors):
            patch.set_facecolor(color)
            patch.set_alpha(0.8)

        ax2.set_xlabel('手法', fontsize=12)
        ax2.set_ylabel('MAE', fontsize=12)
        ax2.set_title('ユーザー別MAE分布', fontsize=14, fontweight='bold')
        ax2.grid(axis='y', alpha=0.3)

        plt.tight_layout()

        # 保存
        fig_file = os.path.join(self.results_dir, 'exp1_model_comparison.png')
        plt.savefig(fig_file, dpi=300, bbox_inches='tight')
        print(f"グラフを保存しました: {fig_file}")

        plt.close()


if __name__ == '__main__':
    # 実験実行
    experiment = Experiment1(seed=42)
    results = experiment.run_experiment(n_users=100, decisions_per_user=100)
    experiment.visualize_results(results)
