"""
実験4: ユーザータイプ別の予測精度
目的: どんな後悔タイプでも予測できることを示す

実験1のデータを再利用して、ユーザータイプ別に分析
"""
import numpy as np
import json
import os
from datetime import datetime
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['font.family'] = 'DejaVu Sans'

from generate_synthetic_data import SyntheticDataGenerator
from experiment1_model_comparison import Experiment1


class Experiment4:
    """実験4: ユーザータイプ別の予測精度分析"""

    def __init__(self, seed=42):
        self.seed = seed
        self.results_dir = 'results'
        os.makedirs(self.results_dir, exist_ok=True)

    def run_experiment(self, n_users=100, decisions_per_user=100):
        """
        実験4を実行（実験1のデータを再分析）

        Args:
            n_users: ユーザー数
            decisions_per_user: ユーザーあたりの決定数

        Returns:
            dict: 実験結果
        """
        print("=" * 80)
        print("実験4: ユーザータイプ別の予測精度")
        print("=" * 80)
        print(f"ユーザー数: {n_users}")
        print(f"決定数/ユーザー: {decisions_per_user}")
        print("")

        # データ生成（実験1と同じ）
        print("データ生成中...")
        generator = SyntheticDataGenerator(seed=self.seed)
        dataset = generator.generate_dataset(n_users=n_users, decisions_per_user=decisions_per_user)
        print("")

        # 実験1のロジックを再利用
        exp1 = Experiment1(seed=self.seed)

        # ユーザータイプ別に結果を集計
        type_results = {
            'stress_sensitive': {'maes': [], 'users': []},
            'price_sensitive': {'maes': [], 'users': []},
            'mood_dependent': {'maes': [], 'users': []},
            'random': {'maes': [], 'users': []}
        }

        print("ユーザータイプ別に評価中...")

        for user_idx, user in enumerate(dataset['users']):
            user_id = user['user_id']
            user_type = user['user_type']

            # このユーザーのデータを抽出
            user_decisions = [d for d in dataset['decisions'] if d['user_id'] == user_id]
            user_feedbacks = [f for f in dataset['feedbacks'] if f['user_id'] == user_id]

            # 時系列分割（80/20）
            train_decisions, train_feedbacks, test_decisions, test_feedbacks = \
                exp1.train_test_split_temporal(user_decisions, user_feedbacks, train_ratio=0.8)

            # 提案手法（Random Forest + 適応的特徴量選択）で評価
            rf_adaptive_result = exp1.evaluate_random_forest_adaptive(
                train_decisions, train_feedbacks, test_decisions, test_feedbacks, user_id
            )

            if 'error' not in rf_adaptive_result:
                mae = rf_adaptive_result['mae']
                type_results[user_type]['maes'].append(mae)
                type_results[user_type]['users'].append(user_id)

            if (user_idx + 1) % 20 == 0:
                print(f"  評価完了: {user_idx + 1}/{n_users} ユーザー")

        print("\n実験完了！\n")

        # 統計量計算
        type_mapping = {
            'stress_sensitive': 'ストレス敏感型',
            'price_sensitive': '価格敏感型',
            'mood_dependent': '気分依存型',
            'random': 'ランダム型'
        }

        summary = {}
        for user_type_en, user_type_ja in type_mapping.items():
            maes = type_results[user_type_en]['maes']
            if maes:
                summary[user_type_ja] = {
                    'mae_mean': float(np.mean(maes)),
                    'mae_std': float(np.std(maes)),
                    'mae_min': float(np.min(maes)),
                    'mae_max': float(np.max(maes)),
                    'mae_median': float(np.median(maes)),
                    'n_users': len(maes)
                }

        # 結果表示
        print("=" * 80)
        print("ユーザータイプ別の結果サマリー")
        print("=" * 80)
        for user_type_ja, stats_dict in summary.items():
            print(f"\n{user_type_ja} (n={stats_dict['n_users']}):")
            print(f"  MAE = {stats_dict['mae_mean']:.4f} ± {stats_dict['mae_std']:.4f}")
            print(f"  中央値 = {stats_dict['mae_median']:.4f}")
            print(f"  範囲: [{stats_dict['mae_min']:.4f}, {stats_dict['mae_max']:.4f}]")

        print("=" * 80)

        # 結果保存
        result_data = {
            'summary': summary,
            'type_results': {
                type_mapping[k]: {
                    'maes': v['maes'],
                    'users': v['users']
                }
                for k, v in type_results.items()
            },
            'metadata': {
                'n_users': n_users,
                'decisions_per_user': decisions_per_user,
                'seed': self.seed,
                'timestamp': datetime.now().isoformat()
            }
        }

        result_file = os.path.join(self.results_dir, 'exp4_user_type_analysis.json')
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

        # 図1: 箱ひげ図（ユーザータイプ別MAE分布）
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

        user_types = list(result_data['summary'].keys())
        mae_data = []
        colors = ['#ff9999', '#66b3ff', '#99ff99', '#ffcc99']

        for user_type in user_types:
            mae_data.append(result_data['type_results'][user_type]['maes'])

        # 箱ひげ図
        bp = ax1.boxplot(mae_data, tick_labels=user_types, patch_artist=True, showmeans=True)

        for patch, color in zip(bp['boxes'], colors):
            patch.set_facecolor(color)
            patch.set_alpha(0.7)

        ax1.set_xlabel('User Type', fontsize=12)
        ax1.set_ylabel('MAE', fontsize=12)
        ax1.set_title('Exp4: MAE Distribution by User Type', fontsize=14, fontweight='bold')
        ax1.grid(axis='y', alpha=0.3)

        # 棒グラフ（平均MAE）
        mae_means = [result_data['summary'][ut]['mae_mean'] for ut in user_types]
        mae_stds = [result_data['summary'][ut]['mae_std'] for ut in user_types]

        x_pos = np.arange(len(user_types))
        bars = ax2.bar(x_pos, mae_means, yerr=mae_stds, capsize=5, color=colors, alpha=0.7, edgecolor='black')

        ax2.set_xlabel('User Type', fontsize=12)
        ax2.set_ylabel('Mean MAE', fontsize=12)
        ax2.set_title('Average MAE by User Type', fontsize=14, fontweight='bold')
        ax2.set_xticks(x_pos)
        ax2.set_xticklabels(user_types, fontsize=10)
        ax2.grid(axis='y', alpha=0.3)

        # 値を棒の上に表示
        for bar, mean_val in zip(bars, mae_means):
            height = bar.get_height()
            ax2.text(bar.get_x() + bar.get_width()/2., height,
                    f'{mean_val:.4f}',
                    ha='center', va='bottom', fontsize=10)

        plt.tight_layout()

        # 保存
        fig_file = os.path.join(self.results_dir, 'exp4_user_type_analysis.png')
        plt.savefig(fig_file, dpi=300, bbox_inches='tight')
        print(f"グラフを保存しました: {fig_file}")

        plt.close()

        # 図2: テーブル形式のサマリー
        self.create_summary_table(result_data)

    def create_summary_table(self, result_data):
        """サマリーテーブルを作成"""
        print("\n" + "=" * 80)
        print("ユーザータイプ別の統計テーブル")
        print("=" * 80)

        # ヘッダー
        print(f"{'ユーザータイプ':<15} {'ユーザー数':>8} {'平均MAE':>10} {'標準偏差':>10} {'中央値':>10} {'最小値':>10} {'最大値':>10}")
        print("-" * 80)

        # データ行
        for user_type, stats in result_data['summary'].items():
            print(f"{user_type:<15} {stats['n_users']:>8} "
                  f"{stats['mae_mean']:>10.4f} {stats['mae_std']:>10.4f} "
                  f"{stats['mae_median']:>10.4f} {stats['mae_min']:>10.4f} {stats['mae_max']:>10.4f}")

        print("=" * 80)

        # テキストファイルにも保存
        table_file = os.path.join(self.results_dir, 'exp4_user_type_table.txt')
        with open(table_file, 'w', encoding='utf-8') as f:
            f.write("ユーザータイプ別の統計テーブル\n")
            f.write("=" * 80 + "\n")
            f.write(f"{'ユーザータイプ':<15} {'ユーザー数':>8} {'平均MAE':>10} {'標準偏差':>10} {'中央値':>10} {'最小値':>10} {'最大値':>10}\n")
            f.write("-" * 80 + "\n")
            for user_type, stats in result_data['summary'].items():
                f.write(f"{user_type:<15} {stats['n_users']:>8} "
                       f"{stats['mae_mean']:>10.4f} {stats['mae_std']:>10.4f} "
                       f"{stats['mae_median']:>10.4f} {stats['mae_min']:>10.4f} {stats['mae_max']:>10.4f}\n")
            f.write("=" * 80 + "\n")

        print(f"テーブルを保存しました: {table_file}\n")


if __name__ == '__main__':
    # 実験実行
    experiment = Experiment4(seed=42)
    results = experiment.run_experiment(n_users=100, decisions_per_user=100)
    experiment.visualize_results(results)
