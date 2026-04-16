"""
実験5: スケーラビリティ評価
目的: データ量・ユーザー数が増えても動作することを示す

測定項目:
- 訓練時間（秒）
- 予測時間（ミリ秒/件）
- メモリ使用量（MB）
- 予測精度（MAE）
"""
import numpy as np
import json
import os
from datetime import datetime
import time
import psutil
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['font.family'] = 'DejaVu Sans'

from generate_synthetic_data import SyntheticDataGenerator
from experiment1_model_comparison import Experiment1


class Experiment5:
    """実験5: スケーラビリティ評価"""

    def __init__(self, seed=42):
        self.seed = seed
        self.results_dir = 'results'
        os.makedirs(self.results_dir, exist_ok=True)
        self.process = psutil.Process()

    def measure_performance(self, n_users, decisions_per_user):
        """
        性能を測定

        Args:
            n_users: ユーザー数
            decisions_per_user: ユーザーあたりの決定数

        Returns:
            dict: 性能指標
        """
        print(f"\n測定中: {n_users} ユーザー × {decisions_per_user} 決定")

        # メモリ使用量（開始時）
        mem_before = self.process.memory_info().rss / (1024 * 1024)  # MB

        # データ生成
        generator = SyntheticDataGenerator(seed=self.seed)
        dataset = generator.generate_dataset(n_users=n_users, decisions_per_user=decisions_per_user)

        # メモリ使用量（データ生成後）
        mem_after_data = self.process.memory_info().rss / (1024 * 1024)  # MB

        # 実験1のロジックを使用
        exp1 = Experiment1(seed=self.seed)

        # 訓練時間と予測時間の測定
        train_times = []
        predict_times = []
        maes = []

        # サンプリング（全ユーザーだと時間がかかりすぎる場合）
        sample_size = min(n_users, 10)
        sample_users = dataset['users'][:sample_size]

        for user in sample_users:
            user_id = user['user_id']

            user_decisions = [d for d in dataset['decisions'] if d['user_id'] == user_id]
            user_feedbacks = [f for f in dataset['feedbacks'] if f['user_id'] == user_id]

            # 時系列分割
            train_decisions, train_feedbacks, test_decisions, test_feedbacks = \
                exp1.train_test_split_temporal(user_decisions, user_feedbacks, train_ratio=0.8)

            # 訓練時間測定
            start_time = time.time()
            rf_adaptive_result = exp1.evaluate_random_forest_adaptive(
                train_decisions, train_feedbacks, test_decisions, test_feedbacks, user_id
            )
            train_time = time.time() - start_time

            if 'error' not in rf_adaptive_result:
                train_times.append(train_time)
                maes.append(rf_adaptive_result['mae'])

                # 予測時間測定（1件あたり）
                predict_time_per_item = (train_time / len(test_decisions)) * 1000  # ミリ秒
                predict_times.append(predict_time_per_item)

        # メモリ使用量（モデル訓練後）
        mem_after_train = self.process.memory_info().rss / (1024 * 1024)  # MB

        # 統計量
        result = {
            'n_users': n_users,
            'decisions_per_user': decisions_per_user,
            'total_decisions': n_users * decisions_per_user,
            'train_time_mean': float(np.mean(train_times)) if train_times else 0.0,
            'train_time_total': float(np.sum(train_times)) if train_times else 0.0,
            'predict_time_mean_ms': float(np.mean(predict_times)) if predict_times else 0.0,
            'mae_mean': float(np.mean(maes)) if maes else np.nan,
            'memory_data_mb': float(mem_after_data - mem_before),
            'memory_total_mb': float(mem_after_train - mem_before),
            'sample_size': sample_size
        }

        print(f"  訓練時間（平均）: {result['train_time_mean']:.2f}秒")
        print(f"  予測時間（平均）: {result['predict_time_mean_ms']:.2f}ms/件")
        print(f"  MAE: {result['mae_mean']:.4f}")
        print(f"  メモリ使用量: {result['memory_total_mb']:.1f}MB")

        return result

    def run_experiment(self):
        """
        実験5を実行

        Returns:
            dict: 実験結果
        """
        print("=" * 80)
        print("実験5: スケーラビリティ評価")
        print("=" * 80)
        print("")

        # 実験設定
        experiments = [
            {'n_users': 10, 'decisions_per_user': 50},
            {'n_users': 10, 'decisions_per_user': 100},
            {'n_users': 50, 'decisions_per_user': 50},
            {'n_users': 50, 'decisions_per_user': 100},
            {'n_users': 100, 'decisions_per_user': 50},
            {'n_users': 100, 'decisions_per_user': 100},
        ]

        results = []

        for exp_config in experiments:
            result = self.measure_performance(exp_config['n_users'], exp_config['decisions_per_user'])
            results.append(result)

        print("\n実験完了！\n")

        # 結果サマリー
        print("=" * 80)
        print("結果サマリー")
        print("=" * 80)
        print(f"{'ユーザー数':<10} {'決定数/u':<10} {'総決定数':<10} {'訓練時間':<12} {'予測時間':<12} {'MAE':<10} {'メモリ':<10}")
        print("-" * 80)
        for r in results:
            print(f"{r['n_users']:<10} {r['decisions_per_user']:<10} {r['total_decisions']:<10} "
                  f"{r['train_time_mean']:<12.2f} {r['predict_time_mean_ms']:<12.2f} "
                  f"{r['mae_mean']:<10.4f} {r['memory_total_mb']:<10.1f}")
        print("=" * 80)

        # 結果保存
        result_data = {
            'results': results,
            'metadata': {
                'seed': self.seed,
                'timestamp': datetime.now().isoformat()
            }
        }

        result_file = os.path.join(self.results_dir, 'exp5_scalability.json')
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(result_data, f, indent=2, ensure_ascii=False)
        print(f"\n結果を保存しました: {result_file}\n")

        return result_data

    def visualize_results(self, result_data):
        """結果を可視化"""
        print("結果を可視化中...")

        results = result_data['results']

        # データ整理
        n_users_list = [r['n_users'] for r in results]
        decisions_per_user_list = [r['decisions_per_user'] for r in results]
        total_decisions_list = [r['total_decisions'] for r in results]
        train_times = [r['train_time_mean'] for r in results]
        predict_times = [r['predict_time_mean_ms'] for r in results]
        maes = [r['mae_mean'] for r in results]
        memories = [r['memory_total_mb'] for r in results]

        # 図1: 訓練時間とメモリ
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

        # 総決定数 vs 訓練時間
        ax1.scatter(total_decisions_list, train_times, s=100, alpha=0.6, c='blue')
        ax1.plot(sorted(total_decisions_list), np.poly1d(np.polyfit(total_decisions_list, train_times, 1))(sorted(total_decisions_list)),
                'r--', alpha=0.5, label='Linear Fit')

        ax1.set_xlabel('Total Decisions', fontsize=12)
        ax1.set_ylabel('Training Time (seconds)', fontsize=12)
        ax1.set_title('Scalability: Training Time', fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        ax1.legend()

        # 総決定数 vs メモリ使用量
        ax2.scatter(total_decisions_list, memories, s=100, alpha=0.6, c='green')
        ax2.plot(sorted(total_decisions_list), np.poly1d(np.polyfit(total_decisions_list, memories, 1))(sorted(total_decisions_list)),
                'r--', alpha=0.5, label='Linear Fit')

        ax2.set_xlabel('Total Decisions', fontsize=12)
        ax2.set_ylabel('Memory Usage (MB)', fontsize=12)
        ax2.set_title('Scalability: Memory Usage', fontsize=14, fontweight='bold')
        ax2.grid(True, alpha=0.3)
        ax2.legend()

        plt.tight_layout()

        fig_file = os.path.join(self.results_dir, 'exp5_scalability_time_memory.png')
        plt.savefig(fig_file, dpi=300, bbox_inches='tight')
        print(f"グラフ1を保存しました: {fig_file}")
        plt.close()

        # 図2: 予測時間とMAE
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

        # 総決定数 vs 予測時間
        ax1.scatter(total_decisions_list, predict_times, s=100, alpha=0.6, c='purple')

        ax1.set_xlabel('Total Decisions', fontsize=12)
        ax1.set_ylabel('Prediction Time (ms/item)', fontsize=12)
        ax1.set_title('Scalability: Prediction Time', fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)

        # 総決定数 vs MAE
        ax2.scatter(total_decisions_list, maes, s=100, alpha=0.6, c='orange')

        ax2.set_xlabel('Total Decisions', fontsize=12)
        ax2.set_ylabel('MAE', fontsize=12)
        ax2.set_title('Scalability: Prediction Accuracy', fontsize=14, fontweight='bold')
        ax2.grid(True, alpha=0.3)

        plt.tight_layout()

        fig_file = os.path.join(self.results_dir, 'exp5_scalability_predict_mae.png')
        plt.savefig(fig_file, dpi=300, bbox_inches='tight')
        print(f"グラフ2を保存しました: {fig_file}")
        plt.close()


if __name__ == '__main__':
    # 実験実行
    experiment = Experiment5(seed=42)
    results = experiment.run_experiment()
    experiment.visualize_results(results)
