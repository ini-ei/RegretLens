"""
実験2: 適応的特徴量選択の効果
目的: 個人化（ユーザーごとに特徴量を選ぶ）の有効性を示す
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
from sklearn.metrics import mean_absolute_error
from scipy.spatial.distance import jaccard

from generate_synthetic_data import SyntheticDataGenerator
from ml_engine import extract_features, prepare_training_data
from adaptive_features import AdaptiveFeatureSelector, FEATURE_NAMES


class Experiment2:
    """実験2: 適応的特徴量選択の効果"""

    def __init__(self, seed=42):
        self.seed = seed
        self.results_dir = 'results'
        os.makedirs(self.results_dir, exist_ok=True)
        self.feature_names = FEATURE_NAMES

    def train_test_split_temporal(self, decisions, feedbacks, train_ratio=0.8):
        """時系列を考慮した訓練/テスト分割"""
        n_train = int(len(decisions) * train_ratio)

        train_decisions = decisions[:n_train]
        test_decisions = decisions[n_train:]

        train_decision_ids = [d['id'] for d in train_decisions]
        test_decision_ids = [d['id'] for d in test_decisions]

        train_feedbacks = [f for f in feedbacks if f['decision_id'] in train_decision_ids]
        test_feedbacks = [f for f in feedbacks if f['decision_id'] in test_decision_ids]

        return train_decisions, train_feedbacks, test_decisions, test_feedbacks

    def evaluate_with_features(self, train_decisions, train_feedbacks, test_decisions, test_feedbacks, feature_indices):
        """
        指定された特徴量インデックスでモデルを評価

        Args:
            train_decisions: 訓練用意思決定
            train_feedbacks: 訓練用フィードバック
            test_decisions: テスト用意思決定
            test_feedbacks: テスト用フィードバック
            feature_indices: 使用する特徴量のインデックスリスト

        Returns:
            float: MAE
        """
        # 訓練データ準備
        X_train_full, y_train = prepare_training_data(train_decisions, train_feedbacks)

        if len(X_train_full) < 10:
            return np.nan

        X_train = X_train_full[:, feature_indices]

        # モデル訓練
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)

        model = RandomForestRegressor(n_estimators=50, max_depth=10, random_state=self.seed)
        model.fit(X_train_scaled, y_train)

        # テストデータ準備
        X_test_full = []
        actuals = []

        for decision in test_decisions:
            decision_data = {
                'category': decision['category'],
                'context': decision['context'],
                'decision_factors': decision['decision_factors']
            }
            features = extract_features(decision_data, train_decisions, train_feedbacks)

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

            feedback = next(f for f in test_feedbacks if f['decision_id'] == decision['id'])
            actual_score = (feedback['regret_score'] - 1) / 4.0
            actuals.append(actual_score)

        X_test_full = np.array(X_test_full)
        X_test = X_test_full[:, feature_indices]
        actuals = np.array(actuals)

        # 予測
        X_test_scaled = scaler.transform(X_test)
        predictions = model.predict(X_test_scaled)
        predictions = np.clip(predictions, 0, 1)

        return mean_absolute_error(actuals, predictions)

    def get_global_top_features(self, dataset, n_features=12):
        """
        全ユーザーの平均で重要度が高い特徴量を取得（固定上位12特徴量）

        Args:
            dataset: データセット
            n_features: 選択する特徴量数

        Returns:
            list: 選択された特徴量のインデックス
        """
        print("全ユーザーの特徴量重要度を計算中...")

        all_importance = {name: [] for name in self.feature_names}

        for user_idx, user in enumerate(dataset['users']):
            user_id = user['user_id']

            user_decisions = [d for d in dataset['decisions'] if d['user_id'] == user_id]
            user_feedbacks = [f for f in dataset['feedbacks'] if f['user_id'] == user_id]

            train_decisions, train_feedbacks, _, _ = \
                self.train_test_split_temporal(user_decisions, user_feedbacks, train_ratio=0.8)

            # 特徴量重要度計算
            selector = AdaptiveFeatureSelector(user_id)
            result = selector.adaptive_feature_selection(train_decisions, train_feedbacks, method='auto', n_features=n_features)

            if 'error' not in result and 'feature_importance' in result:
                for feature_name, importance in result['feature_importance'].items():
                    all_importance[feature_name].append(importance)

            if (user_idx + 1) % 10 == 0:
                print(f"  {user_idx + 1}/{len(dataset['users'])} ユーザー処理完了")

        # 平均重要度を計算
        avg_importance = {}
        for feature_name, importance_list in all_importance.items():
            if importance_list:
                avg_importance[feature_name] = np.mean(importance_list)
            else:
                avg_importance[feature_name] = 0.0

        # 上位n_features個を選択
        sorted_features = sorted(avg_importance.items(), key=lambda x: x[1], reverse=True)
        top_features = [name for name, _ in sorted_features[:n_features]]
        top_indices = [i for i, name in enumerate(self.feature_names) if name in top_features]

        print(f"\n固定上位{n_features}特徴量: {top_features}\n")

        return top_indices, avg_importance

    def calculate_jaccard_diversity(self, selected_features_list):
        """
        選択された特徴量セットのJaccard距離を計算

        Args:
            selected_features_list: ユーザーごとの選択特徴量リスト

        Returns:
            float: 平均Jaccard距離
        """
        if len(selected_features_list) < 2:
            return 0.0

        distances = []
        n_users = len(selected_features_list)

        for i in range(n_users):
            for j in range(i + 1, n_users):
                set_i = set(selected_features_list[i])
                set_j = set(selected_features_list[j])

                # Jaccard距離 = 1 - Jaccard類似度
                if len(set_i) == 0 and len(set_j) == 0:
                    distance = 0.0
                else:
                    intersection = len(set_i & set_j)
                    union = len(set_i | set_j)
                    jaccard_similarity = intersection / union if union > 0 else 0.0
                    distance = 1.0 - jaccard_similarity

                distances.append(distance)

        return np.mean(distances)

    def run_experiment(self, n_users=50, decisions_per_user=100):
        """
        実験2を実行

        Args:
            n_users: ユーザー数
            decisions_per_user: ユーザーあたりの決定数

        Returns:
            dict: 実験結果
        """
        print("=" * 80)
        print("実験2: 適応的特徴量選択の効果")
        print("=" * 80)
        print(f"ユーザー数: {n_users}")
        print(f"決定数/ユーザー: {decisions_per_user}")
        print("")

        # データ生成
        print("データ生成中...")
        generator = SyntheticDataGenerator(seed=self.seed)
        dataset = generator.generate_dataset(n_users=n_users, decisions_per_user=decisions_per_user)
        print("")

        # 固定上位12特徴量を取得
        global_top_indices, global_importance = self.get_global_top_features(dataset, n_features=12)

        # ユーザーごとに評価
        results = {
            'all_18_features': [],
            'fixed_top_12': [],
            'adaptive_12': []
        }

        user_feature_importance = []  # ヒートマップ用
        user_selected_features = []  # 多様性分析用
        user_types = []  # ユーザータイプ記録

        for user_idx, user in enumerate(dataset['users']):
            user_id = user['user_id']
            user_type = user['user_type']
            user_types.append(user_type)

            user_decisions = [d for d in dataset['decisions'] if d['user_id'] == user_id]
            user_feedbacks = [f for f in dataset['feedbacks'] if f['user_id'] == user_id]

            train_decisions, train_feedbacks, test_decisions, test_feedbacks = \
                self.train_test_split_temporal(user_decisions, user_feedbacks, train_ratio=0.8)

            # 手法1: 全18特徴量
            mae_18 = self.evaluate_with_features(train_decisions, train_feedbacks, test_decisions, test_feedbacks,
                                                 list(range(18)))
            results['all_18_features'].append(mae_18)

            # 手法2: 固定上位12特徴量
            mae_fixed = self.evaluate_with_features(train_decisions, train_feedbacks, test_decisions, test_feedbacks,
                                                    global_top_indices)
            results['fixed_top_12'].append(mae_fixed)

            # 手法3: 適応的12特徴量
            selector = AdaptiveFeatureSelector(user_id)
            selection_result = selector.adaptive_feature_selection(train_decisions, train_feedbacks, method='auto', n_features=12)

            if 'error' not in selection_result:
                adaptive_indices = selection_result['selected_indices']
                mae_adaptive = self.evaluate_with_features(train_decisions, train_feedbacks, test_decisions, test_feedbacks,
                                                          adaptive_indices)
                results['adaptive_12'].append(mae_adaptive)

                # 特徴量重要度を記録（ヒートマップ用）
                importance_vector = []
                for feature_name in self.feature_names:
                    importance_vector.append(selection_result['feature_importance'].get(feature_name, 0.0))
                user_feature_importance.append(importance_vector)

                # 選択された特徴量を記録（多様性分析用）
                user_selected_features.append(selection_result['selected_features'])
            else:
                results['adaptive_12'].append(np.nan)
                user_feature_importance.append([0.0] * 18)
                user_selected_features.append([])

            if (user_idx + 1) % 10 == 0:
                print(f"評価完了: {user_idx + 1}/{n_users} ユーザー")

        print("\n実験完了！\n")

        # 統計量計算
        summary = {}
        for method_name, mae_list in results.items():
            mae_array = np.array([m for m in mae_list if not np.isnan(m)])
            summary[method_name] = {
                'mae_mean': float(np.mean(mae_array)),
                'mae_std': float(np.std(mae_array)),
                'mae_min': float(np.min(mae_array)),
                'mae_max': float(np.max(mae_array)),
                'n_users': len(mae_array)
            }

        # 特徴量の多様性分析
        jaccard_distance = self.calculate_jaccard_diversity(user_selected_features)
        unique_feature_sets = len(set([tuple(sorted(features)) for features in user_selected_features if features]))

        diversity_analysis = {
            'avg_jaccard_distance': float(jaccard_distance),
            'unique_feature_sets': int(unique_feature_sets),
            'total_users': n_users
        }

        # ユーザータイプ別の分析
        type_analysis = self.analyze_by_user_type(user_types, user_selected_features, results)

        # 結果表示
        print("=" * 80)
        print("結果サマリー")
        print("=" * 80)
        for method_name, stats_dict in summary.items():
            print(f"\n{method_name}:")
            print(f"  MAE = {stats_dict['mae_mean']:.4f} ± {stats_dict['mae_std']:.4f}")
            print(f"  範囲: [{stats_dict['mae_min']:.4f}, {stats_dict['mae_max']:.4f}]")

        print(f"\n特徴量の多様性:")
        print(f"  平均Jaccard距離 = {jaccard_distance:.4f}")
        print(f"  ユニーク特徴量セット数 = {unique_feature_sets}/{n_users}")

        print("=" * 80)

        # 結果保存
        result_data = {
            'summary': summary,
            'diversity_analysis': diversity_analysis,
            'type_analysis': type_analysis,
            'results_by_user': results,
            'user_feature_importance': user_feature_importance,
            'user_selected_features': user_selected_features,
            'user_types': user_types,
            'global_top_features': [self.feature_names[i] for i in global_top_indices],
            'metadata': {
                'n_users': n_users,
                'decisions_per_user': decisions_per_user,
                'seed': self.seed,
                'timestamp': datetime.now().isoformat()
            }
        }

        result_file = os.path.join(self.results_dir, 'exp2_adaptive_features.json')
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(result_data, f, indent=2, ensure_ascii=False)
        print(f"\n結果を保存しました: {result_file}\n")

        return result_data

    def analyze_by_user_type(self, user_types, user_selected_features, results):
        """ユーザータイプ別に分析"""
        type_mapping = {
            'stress_sensitive': 'ストレス敏感型',
            'price_sensitive': '価格敏感型',
            'mood_dependent': '気分依存型',
            'random': 'ランダム型'
        }

        type_analysis = {}

        for user_type_en, user_type_ja in type_mapping.items():
            # このタイプのユーザーのインデックス
            type_indices = [i for i, ut in enumerate(user_types) if ut == user_type_en]

            if not type_indices:
                continue

            # MAE平均
            mae_adaptive = [results['adaptive_12'][i] for i in type_indices if not np.isnan(results['adaptive_12'][i])]
            avg_mae = np.mean(mae_adaptive) if mae_adaptive else np.nan

            # 主要特徴量（出現頻度Top5）
            feature_counts = {}
            for idx in type_indices:
                for feature in user_selected_features[idx]:
                    feature_counts[feature] = feature_counts.get(feature, 0) + 1

            top_features = sorted(feature_counts.items(), key=lambda x: x[1], reverse=True)[:5]

            type_analysis[user_type_ja] = {
                'n_users': len(type_indices),
                'avg_mae': float(avg_mae) if not np.isnan(avg_mae) else None,
                'top_features': [{'feature': f, 'count': c} for f, c in top_features]
            }

        return type_analysis

    def visualize_results(self, result_data):
        """結果を可視化"""
        print("結果を可視化中...")

        # 図1: MAE比較（棒グラフ）
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        methods = ['all_18_features', 'fixed_top_12', 'adaptive_12']
        method_labels = ['All 18\nFeatures', 'Fixed Top 12\nFeatures', 'Adaptive 12\nFeatures\n(Proposed)']

        mae_means = [result_data['summary'][m]['mae_mean'] for m in methods]
        mae_stds = [result_data['summary'][m]['mae_std'] for m in methods]

        # 棒グラフ
        x_pos = np.arange(len(methods))
        colors = ['#66b3ff', '#ffcc99', '#99ff99']
        bars = axes[0].bar(x_pos, mae_means, yerr=mae_stds, capsize=5, color=colors, alpha=0.8, edgecolor='black')

        axes[0].set_xlabel('Method', fontsize=12)
        axes[0].set_ylabel('MAE (Mean Absolute Error)', fontsize=12)
        axes[0].set_title('Exp2: Adaptive Feature Selection Effect', fontsize=14, fontweight='bold')
        axes[0].set_xticks(x_pos)
        axes[0].set_xticklabels(method_labels, fontsize=10)
        axes[0].grid(axis='y', alpha=0.3)

        for bar, mean_val in zip(bars, mae_means):
            height = bar.get_height()
            axes[0].text(bar.get_x() + bar.get_width()/2., height,
                        f'{mean_val:.4f}',
                        ha='center', va='bottom', fontsize=10)

        # 箱ひげ図
        mae_data = [
            [m for m in result_data['results_by_user'][method] if not np.isnan(m)]
            for method in methods
        ]

        bp = axes[1].boxplot(mae_data, tick_labels=method_labels, patch_artist=True)
        for patch, color in zip(bp['boxes'], colors):
            patch.set_facecolor(color)
            patch.set_alpha(0.8)

        axes[1].set_xlabel('Method', fontsize=12)
        axes[1].set_ylabel('MAE', fontsize=12)
        axes[1].set_title('MAE Distribution by User', fontsize=14, fontweight='bold')
        axes[1].grid(axis='y', alpha=0.3)

        plt.tight_layout()

        fig_file = os.path.join(self.results_dir, 'exp2_mae_comparison.png')
        plt.savefig(fig_file, dpi=300, bbox_inches='tight')
        print(f"グラフを保存しました: {fig_file}")
        plt.close()

        # 図2: ヒートマップ（ユーザー × 特徴量の重要度）
        self.plot_feature_importance_heatmap(result_data)

    def plot_feature_importance_heatmap(self, result_data):
        """特徴量重要度のヒートマップを作成"""
        print("ヒートマップを作成中...")

        user_feature_importance = np.array(result_data['user_feature_importance'])
        user_types = result_data['user_types']

        # ユーザータイプでソート
        type_order = {'stress_sensitive': 0, 'price_sensitive': 1, 'mood_dependent': 2, 'random': 3}
        sorted_indices = sorted(range(len(user_types)), key=lambda i: type_order.get(user_types[i], 4))

        sorted_importance = user_feature_importance[sorted_indices]
        sorted_types = [user_types[i] for i in sorted_indices]

        # 正規化（各ユーザーの重要度を0-1にスケール）
        normalized_importance = np.zeros_like(sorted_importance)
        for i in range(len(sorted_importance)):
            row_max = sorted_importance[i].max()
            if row_max > 0:
                normalized_importance[i] = sorted_importance[i] / row_max

        # ヒートマップ作成
        fig, ax = plt.subplots(figsize=(14, 10))

        im = ax.imshow(normalized_importance, cmap='YlOrRd', aspect='auto')

        # 軸ラベル
        ax.set_xticks(np.arange(len(self.feature_names)))
        ax.set_xticklabels(self.feature_names, rotation=45, ha='right', fontsize=8)
        ax.set_yticks(np.arange(0, len(sorted_types), 5))
        ax.set_yticklabels([f'User {i}' for i in range(0, len(sorted_types), 5)], fontsize=8)

        ax.set_xlabel('Features', fontsize=12)
        ax.set_ylabel('Users (sorted by type)', fontsize=12)
        ax.set_title('Feature Importance Heatmap (Normalized)', fontsize=14, fontweight='bold')

        # カラーバー
        cbar = plt.colorbar(im, ax=ax)
        cbar.set_label('Normalized Importance', fontsize=10)

        # ユーザータイプの境界線を追加
        prev_type = None
        for i, user_type in enumerate(sorted_types):
            if user_type != prev_type and prev_type is not None:
                ax.axhline(y=i - 0.5, color='blue', linewidth=2)
            prev_type = user_type

        plt.tight_layout()

        heatmap_file = os.path.join(self.results_dir, 'exp2_feature_importance_heatmap.png')
        plt.savefig(heatmap_file, dpi=300, bbox_inches='tight')
        print(f"ヒートマップを保存しました: {heatmap_file}")
        plt.close()


if __name__ == '__main__':
    # 実験実行
    experiment = Experiment2(seed=42)
    results = experiment.run_experiment(n_users=50, decisions_per_user=100)
    experiment.visualize_results(results)
