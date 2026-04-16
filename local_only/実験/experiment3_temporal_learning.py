"""
実験3: 時系列学習の効果
目的: 過去のシーケンスを考慮する効果を示す

比較対象:
1. Random Forest（単発予測） - 1件ずつ独立に予測
2. LSTM（シーケンス予測） - 過去10件から予測
3. Simple RNN（比較用） - 過去10件から予測（LSTMより単純）
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
import warnings
warnings.filterwarnings('ignore')

# TensorFlow/Keras
try:
    os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # TensorFlowの警告を抑制
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import LSTM, Dense, Dropout, SimpleRNN
    KERAS_AVAILABLE = True
except ImportError:
    KERAS_AVAILABLE = False
    print("Warning: Keras not available")

from generate_synthetic_data import SyntheticDataGenerator
from ml_engine import extract_features, prepare_training_data


class Experiment3:
    """実験3: 時系列学習の効果"""

    def __init__(self, seed=42):
        self.seed = seed
        self.results_dir = 'results'
        os.makedirs(self.results_dir, exist_ok=True)
        np.random.seed(seed)
        if KERAS_AVAILABLE:
            tf.random.set_seed(seed)

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

    def prepare_sequences(self, decisions, feedbacks, sequence_length=10):
        """
        時系列シーケンスデータを準備

        Args:
            decisions: 意思決定リスト
            feedbacks: フィードバックリスト
            sequence_length: シーケンスの長さ

        Returns:
            X_seq: シーケンス特徴量 (n_samples, sequence_length, n_features)
            y: 後悔スコア (n_samples,)
        """
        X_full, y_full = prepare_training_data(decisions, feedbacks)

        if len(X_full) < sequence_length + 1:
            return None, None

        X_seq = []
        y_seq = []

        # シーケンスを作成
        for i in range(sequence_length, len(X_full)):
            X_seq.append(X_full[i-sequence_length:i])
            y_seq.append(y_full[i])

        return np.array(X_seq), np.array(y_seq)

    def evaluate_random_forest(self, train_decisions, train_feedbacks, test_decisions, test_feedbacks):
        """Random Forest（単発予測）を評価"""
        X_train, y_train = prepare_training_data(train_decisions, train_feedbacks)

        if len(X_train) < 10:
            return np.nan

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

        X_test = np.array(X_test_full)
        actuals = np.array(actuals)

        # 予測
        X_test_scaled = scaler.transform(X_test)
        predictions = model.predict(X_test_scaled)
        predictions = np.clip(predictions, 0, 1)

        return mean_absolute_error(actuals, predictions)

    def evaluate_lstm(self, train_decisions, train_feedbacks, test_decisions, test_feedbacks,
                     use_simple_rnn=False, sequence_length=10):
        """LSTM/SimpleRNN（シーケンス予測）を評価"""
        if not KERAS_AVAILABLE:
            return np.nan

        # 全データでシーケンス準備
        all_decisions = train_decisions + test_decisions
        all_feedbacks = train_feedbacks + test_feedbacks

        X_seq, y_seq = self.prepare_sequences(all_decisions, all_feedbacks, sequence_length)

        if X_seq is None or len(X_seq) < 20:
            return np.nan

        # 訓練/テスト分割（時系列順守）
        n_train = len(train_decisions) - sequence_length
        if n_train < 10:
            return np.nan

        X_train = X_seq[:n_train]
        y_train = y_seq[:n_train]
        X_test = X_seq[n_train:]
        y_test = y_seq[n_train:]

        if len(X_test) == 0:
            return np.nan

        # 特徴量の標準化
        n_samples, seq_len, n_features = X_train.shape
        X_train_reshaped = X_train.reshape(-1, n_features)
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train_reshaped)
        X_train_scaled = X_train_scaled.reshape(n_samples, seq_len, n_features)

        X_test_reshaped = X_test.reshape(-1, n_features)
        X_test_scaled = scaler.transform(X_test_reshaped)
        X_test_scaled = X_test_scaled.reshape(len(X_test), seq_len, n_features)

        # モデル構築
        model = Sequential()

        if use_simple_rnn:
            model.add(SimpleRNN(32, input_shape=(sequence_length, n_features)))
        else:
            model.add(LSTM(32, input_shape=(sequence_length, n_features)))

        model.add(Dropout(0.2))
        model.add(Dense(16, activation='relu'))
        model.add(Dense(1, activation='sigmoid'))

        model.compile(optimizer='adam', loss='mse', metrics=['mae'])

        # 訓練
        model.fit(X_train_scaled, y_train, epochs=20, batch_size=16, verbose=0, validation_split=0.2)

        # 予測
        predictions = model.predict(X_test_scaled, verbose=0).flatten()
        predictions = np.clip(predictions, 0, 1)

        return mean_absolute_error(y_test, predictions)

    def run_experiment(self, n_users=30, decisions_per_user=200):
        """
        実験3を実行

        Args:
            n_users: ユーザー数
            decisions_per_user: ユーザーあたりの決定数（長期データ）

        Returns:
            dict: 実験結果
        """
        print("=" * 80)
        print("実験3: 時系列学習の効果")
        print("=" * 80)
        print(f"ユーザー数: {n_users}")
        print(f"決定数/ユーザー: {decisions_per_user}（約6ヶ月分の長期データ）")
        print("")

        # データ生成
        print("データ生成中...")
        generator = SyntheticDataGenerator(seed=self.seed)
        dataset = generator.generate_dataset(n_users=n_users, decisions_per_user=decisions_per_user)
        print("")

        # ユーザーごとに評価
        results = {
            'random_forest': [],
            'simple_rnn': [],
            'lstm': []
        }

        for user_idx, user in enumerate(dataset['users']):
            user_id = user['user_id']

            user_decisions = [d for d in dataset['decisions'] if d['user_id'] == user_id]
            user_feedbacks = [f for f in dataset['feedbacks'] if f['user_id'] == user_id]

            # 時系列分割（80/20）
            train_decisions, train_feedbacks, test_decisions, test_feedbacks = \
                self.train_test_split_temporal(user_decisions, user_feedbacks, train_ratio=0.8)

            # 手法1: Random Forest（単発予測）
            mae_rf = self.evaluate_random_forest(train_decisions, train_feedbacks, test_decisions, test_feedbacks)
            results['random_forest'].append(mae_rf)

            # 手法2: Simple RNN（シーケンス予測）
            mae_rnn = self.evaluate_lstm(train_decisions, train_feedbacks, test_decisions, test_feedbacks,
                                        use_simple_rnn=True, sequence_length=10)
            results['simple_rnn'].append(mae_rnn)

            # 手法3: LSTM（シーケンス予測）
            mae_lstm = self.evaluate_lstm(train_decisions, train_feedbacks, test_decisions, test_feedbacks,
                                         use_simple_rnn=False, sequence_length=10)
            results['lstm'].append(mae_lstm)

            if (user_idx + 1) % 5 == 0:
                print(f"評価完了: {user_idx + 1}/{n_users} ユーザー")

        print("\n実験完了！\n")

        # 統計量計算
        summary = {}
        for method_name, mae_list in results.items():
            mae_array = np.array([m for m in mae_list if not np.isnan(m)])
            if len(mae_array) > 0:
                summary[method_name] = {
                    'mae_mean': float(np.mean(mae_array)),
                    'mae_std': float(np.std(mae_array)),
                    'mae_min': float(np.min(mae_array)),
                    'mae_max': float(np.max(mae_array)),
                    'n_users': len(mae_array)
                }

        # 結果表示
        print("=" * 80)
        print("結果サマリー")
        print("=" * 80)
        for method_name, stats_dict in summary.items():
            print(f"\n{method_name}:")
            print(f"  MAE = {stats_dict['mae_mean']:.4f} ± {stats_dict['mae_std']:.4f}")
            print(f"  範囲: [{stats_dict['mae_min']:.4f}, {stats_dict['mae_max']:.4f}]")
            print(f"  評価ユーザー数: {stats_dict['n_users']}")

        print("=" * 80)

        # 結果保存
        result_data = {
            'summary': summary,
            'results_by_user': results,
            'metadata': {
                'n_users': n_users,
                'decisions_per_user': decisions_per_user,
                'sequence_length': 10,
                'seed': self.seed,
                'timestamp': datetime.now().isoformat()
            }
        }

        result_file = os.path.join(self.results_dir, 'exp3_temporal_learning.json')
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(result_data, f, indent=2, ensure_ascii=False)
        print(f"\n結果を保存しました: {result_file}\n")

        return result_data

    def visualize_results(self, result_data):
        """結果を可視化"""
        print("結果を可視化中...")

        # 図1: 棒グラフ + 箱ひげ図
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

        methods = ['random_forest', 'simple_rnn', 'lstm']
        method_labels = ['Random Forest\n(Single)', 'Simple RNN\n(Sequence)', 'LSTM\n(Sequence)']

        mae_means = [result_data['summary'][m]['mae_mean'] for m in methods if m in result_data['summary']]
        mae_stds = [result_data['summary'][m]['mae_std'] for m in methods if m in result_data['summary']]

        # 棒グラフ
        x_pos = np.arange(len(mae_means))
        colors = ['#ff9999', '#66b3ff', '#99ff99']
        bars = ax1.bar(x_pos, mae_means, yerr=mae_stds, capsize=5, color=colors[:len(mae_means)],
                      alpha=0.8, edgecolor='black')

        ax1.set_xlabel('Method', fontsize=12)
        ax1.set_ylabel('MAE (Mean Absolute Error)', fontsize=12)
        ax1.set_title('Exp3: Temporal Learning Effect', fontsize=14, fontweight='bold')
        ax1.set_xticks(x_pos)
        ax1.set_xticklabels(method_labels[:len(mae_means)], fontsize=10)
        ax1.grid(axis='y', alpha=0.3)

        for bar, mean_val in zip(bars, mae_means):
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height,
                    f'{mean_val:.4f}',
                    ha='center', va='bottom', fontsize=10)

        # 箱ひげ図
        mae_data = [
            [m for m in result_data['results_by_user'][method] if not np.isnan(m)]
            for method in methods if method in result_data['summary']
        ]

        bp = ax2.boxplot(mae_data, tick_labels=method_labels[:len(mae_data)], patch_artist=True)
        for patch, color in zip(bp['boxes'], colors[:len(mae_data)]):
            patch.set_facecolor(color)
            patch.set_alpha(0.8)

        ax2.set_xlabel('Method', fontsize=12)
        ax2.set_ylabel('MAE', fontsize=12)
        ax2.set_title('MAE Distribution by User', fontsize=14, fontweight='bold')
        ax2.grid(axis='y', alpha=0.3)

        plt.tight_layout()

        fig_file = os.path.join(self.results_dir, 'exp3_temporal_learning.png')
        plt.savefig(fig_file, dpi=300, bbox_inches='tight')
        print(f"グラフを保存しました: {fig_file}")
        plt.close()


if __name__ == '__main__':
    if not KERAS_AVAILABLE:
        print("Error: Keras/TensorFlow not available. Please install with: pip install tensorflow keras")
        exit(1)

    # 実験実行
    experiment = Experiment3(seed=42)
    results = experiment.run_experiment(n_users=30, decisions_per_user=200)
    experiment.visualize_results(results)
