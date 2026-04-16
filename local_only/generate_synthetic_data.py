"""
RegretLens Synthetic Data Generator - 仮想データ生成システム
論文実験用の現実的な意思決定データを生成
"""
import numpy as np
import json
from datetime import datetime, timedelta
import random


class UserProfile:
    """ユーザープロファイル（4つのタイプ）"""

    def __init__(self, user_id, user_type, seed=None):
        """
        Args:
            user_id: ユーザーID
            user_type: 'stress_sensitive', 'price_sensitive', 'mood_dependent', 'random'
            seed: ランダムシード
        """
        self.user_id = user_id
        self.user_type = user_type

        # シード設定（再現性確保）
        if seed is not None:
            np.random.seed(seed)
            random.seed(seed)

        # ユーザータイプ別のパラメータ設定
        if user_type == 'stress_sensitive':
            self.stress_sensitivity = np.random.uniform(0.8, 1.0)
            self.price_sensitivity = np.random.uniform(0.3, 0.6)
            self.mood_sensitivity = np.random.uniform(0.3, 0.6)
            self.baseline_regret = np.random.uniform(0.2, 0.3)

        elif user_type == 'price_sensitive':
            self.stress_sensitivity = np.random.uniform(0.3, 0.6)
            self.price_sensitivity = np.random.uniform(0.8, 1.0)
            self.mood_sensitivity = np.random.uniform(0.3, 0.6)
            self.baseline_regret = np.random.uniform(0.2, 0.3)

        elif user_type == 'mood_dependent':
            self.stress_sensitivity = np.random.uniform(0.3, 0.6)
            self.price_sensitivity = np.random.uniform(0.3, 0.6)
            self.mood_sensitivity = np.random.uniform(0.8, 1.0)
            self.baseline_regret = np.random.uniform(0.2, 0.3)

        else:  # random
            self.stress_sensitivity = np.random.uniform(0.3, 0.7)
            self.price_sensitivity = np.random.uniform(0.3, 0.7)
            self.mood_sensitivity = np.random.uniform(0.3, 0.7)
            self.baseline_regret = np.random.uniform(0.3, 0.5)

    def calculate_regret(self, context, decision_factors):
        """ユーザータイプに基づいて後悔度を計算"""
        regret = self.baseline_regret

        # ストレス要因
        stress_level = context.get('stress_level', 3)
        if stress_level >= 4:
            regret += (stress_level / 5.0) * 0.35 * self.stress_sensitivity

        # 価格要因
        price = decision_factors.get('price', 0)
        regret += (price / 2000.0) * 0.45 * self.price_sensitivity

        # 予算不足
        budget_remaining = context.get('budget_remaining', 5000)
        if budget_remaining < price:
            regret += 0.2 * self.price_sensitivity

        # 気分要因
        mood_score = context.get('mood', 3)
        regret += ((5 - mood_score) / 5.0) * 0.35 * self.mood_sensitivity

        # 悪天候・月曜
        if context.get('weather') in ['雨', '雪']:
            regret += 0.15 * self.mood_sensitivity
        if context.get('day_of_week') == '月曜日':
            regret += 0.15 * self.mood_sensitivity

        # 期待値が低い
        expectation = decision_factors.get('taste_expectation', 3)
        if expectation <= 2:
            regret += 0.2

        # ランダムノイズ（ランダム型は大きい）
        if self.user_type == 'random':
            regret += np.random.uniform(-0.2, 0.2)
        else:
            regret += np.random.uniform(-0.1, 0.1)

        # 0-1の範囲にクリップ
        return np.clip(regret, 0.0, 1.0)


class SyntheticDataGenerator:
    """仮想データ生成クラス"""

    def __init__(self, seed=42):
        """
        Args:
            seed: 全体のランダムシード
        """
        self.seed = seed
        np.random.seed(seed)
        random.seed(seed)

        # カテゴリと確率
        self.categories = {
            '食事': 0.40,
            '買い物': 0.30,
            '娯楽': 0.15,
            '学習': 0.10,
            '仕事': 0.05
        }

        # 天気と確率
        self.weather_options = {
            '晴れ': 0.50,
            '曇り': 0.30,
            '雨': 0.15,
            '雪': 0.05
        }

        # 曜日
        self.weekdays = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日']

    def generate_context(self, date):
        """コンテキストを生成"""
        # 曜日
        day_of_week = self.weekdays[date.weekday()]

        # 時刻（40%ランチ、30%ディナー、30%その他）
        time_category = np.random.choice(['lunch', 'dinner', 'other'], p=[0.4, 0.3, 0.3])
        if time_category == 'lunch':
            hour = np.random.randint(11, 14)
        elif time_category == 'dinner':
            hour = np.random.randint(18, 21)
        else:
            hour = np.random.choice([8, 9, 10, 14, 15, 16, 17, 21, 22, 23])
        time_of_day = f"{hour}:00"

        # 天気
        weather = np.random.choice(list(self.weather_options.keys()),
                                   p=list(self.weather_options.values()))

        # 気分スコア（正規分布、月曜-0.5、雨-0.5）
        mood_score = np.random.normal(3, 1)
        if day_of_week == '月曜日':
            mood_score -= 0.5
        if weather == '雨':
            mood_score -= 0.5
        mood_score = np.clip(mood_score, 1, 5)

        # ストレスレベル（正規分布、月火+0.5、月末+0.8、夜+0.7）
        stress_level = np.random.normal(3, 1.2)
        if day_of_week in ['月曜日', '火曜日']:
            stress_level += 0.5
        if date.day >= 25:  # 月末
            stress_level += 0.8
        if hour >= 20:  # 夜
            stress_level += 0.7
        stress_level = np.clip(stress_level, 1, 5)

        # 空腹度（食事時間前は高い）
        if time_category in ['lunch', 'dinner']:
            hunger_level = np.random.normal(4, 0.8)
        else:
            hunger_level = np.random.normal(3, 1)
        hunger_level = np.clip(hunger_level, 1, 5)

        # 予算残高（月初・月中・月末で変化）
        if date.day <= 10:
            budget_remaining = np.random.randint(7000, 10001)
        elif date.day <= 20:
            budget_remaining = np.random.randint(4000, 7001)
        else:
            budget_remaining = np.random.randint(1000, 4001)

        # 同伴者（30%が一緒）
        with_others = np.random.random() < 0.3

        return {
            'time_of_day': time_of_day,
            'day_of_week': day_of_week,
            'weather': weather,
            'mood': round(float(mood_score), 1),
            'stress_level': round(float(stress_level), 1),
            'hunger_level': round(float(hunger_level), 1),
            'budget_remaining': int(budget_remaining),
            'with_others': with_others
        }

    def generate_decision_factors(self, category, context):
        """決定要因を生成"""
        # カテゴリ別の価格分布
        if category == '食事':
            price = int(np.random.normal(800, 300))
            price = np.clip(price, 400, 2000)
        elif category == '買い物':
            price = int(np.random.lognormal(np.log(1500), 0.5))
            price = np.clip(price, 500, 5000)
        elif category == '娯楽':
            price = int(np.random.normal(1500, 500))
            price = np.clip(price, 800, 3000)
        else:  # 学習、仕事
            price = int(np.random.normal(1000, 400))
            price = np.clip(price, 300, 3000)

        # 期待度（正規分布、高価格なら+0.5～1.0）
        taste_expectation = np.random.normal(3.5, 0.8)
        if price > 1500:
            taste_expectation += np.random.uniform(0.5, 1.0)
        taste_expectation = np.clip(taste_expectation, 1, 5)

        # 健康価値（カテゴリ依存）
        if category == '食事':
            health_value = np.random.normal(3, 0.8)
        elif category == '学習':
            health_value = np.random.normal(4, 0.5)
        else:
            health_value = np.random.normal(3, 1)
        health_value = np.clip(health_value, 1, 5)

        # 所要時間（カテゴリ依存）
        if category == '食事':
            time_required = int(np.random.normal(40, 15))
        elif category == '娯楽':
            time_required = int(np.random.normal(120, 30))
        elif category == '買い物':
            time_required = int(np.random.normal(60, 20))
        else:
            time_required = int(np.random.normal(90, 30))
        time_required = max(10, time_required)

        return {
            'price': int(price),
            'taste_expectation': round(float(taste_expectation), 1),
            'health_value': round(float(health_value), 1),
            'time_required': int(time_required)
        }

    def generate_user_data(self, user_profile, n_decisions=100, start_date=None):
        """1ユーザー分のデータを生成"""
        if start_date is None:
            start_date = datetime(2025, 8, 1)

        decisions = []
        feedbacks = []

        for i in range(n_decisions):
            # 日付（約3ヶ月分、毎日ではない）
            days_offset = int(i * (90 / n_decisions))
            decision_date = start_date + timedelta(days=days_offset)

            # カテゴリ選択
            category = np.random.choice(list(self.categories.keys()),
                                       p=list(self.categories.values()))

            # コンテキスト生成
            context = self.generate_context(decision_date)

            # 決定要因生成
            decision_factors = self.generate_decision_factors(category, context)

            # 決定テキスト
            decision_text = f"{category}の選択"

            # 意思決定レコード
            decision = {
                'id': f"u{user_profile.user_id}_d{i}",
                'user_id': user_profile.user_id,
                'category': category,
                'decision_text': decision_text,
                'context': context,
                'decision_factors': decision_factors,
                'created_at': decision_date.isoformat()
            }
            decisions.append(decision)

            # 後悔度計算（ユーザープロファイルに基づく）
            regret_score_normalized = user_profile.calculate_regret(context, decision_factors)
            regret_score = regret_score_normalized * 4 + 1  # 0-1 → 1-5

            # 満足度（後悔度と負の相関）
            satisfaction_score = 6 - regret_score + np.random.uniform(-0.5, 0.5)
            satisfaction_score = np.clip(satisfaction_score, 1, 5)

            # フィードバックレコード
            feedback = {
                'decision_id': decision['id'],
                'user_id': user_profile.user_id,
                'regret_score': round(float(regret_score), 1),
                'satisfaction_score': round(float(satisfaction_score), 1),
                'regret_reasons': [],
                'created_at': (decision_date + timedelta(hours=2)).isoformat()
            }
            feedbacks.append(feedback)

        return decisions, feedbacks

    def generate_dataset(self, n_users=100, decisions_per_user=100,
                        user_type_distribution=None):
        """
        完全なデータセットを生成

        Args:
            n_users: ユーザー数
            decisions_per_user: ユーザーあたりの決定数
            user_type_distribution: ユーザータイプの分布 (dict)

        Returns:
            dict: 全ユーザーのデータ
        """
        if user_type_distribution is None:
            user_type_distribution = {
                'stress_sensitive': 0.30,
                'price_sensitive': 0.30,
                'mood_dependent': 0.20,
                'random': 0.20
            }

        # ユーザータイプの割り当て
        user_types = []
        for user_type, ratio in user_type_distribution.items():
            count = int(n_users * ratio)
            user_types.extend([user_type] * count)

        # 端数調整
        while len(user_types) < n_users:
            user_types.append('random')
        user_types = user_types[:n_users]

        # シャッフル
        random.shuffle(user_types)

        # データ生成
        all_data = {
            'users': [],
            'decisions': [],
            'feedbacks': [],
            'metadata': {
                'n_users': n_users,
                'decisions_per_user': decisions_per_user,
                'total_decisions': n_users * decisions_per_user,
                'user_type_distribution': user_type_distribution,
                'seed': self.seed,
                'generated_at': datetime.now().isoformat()
            }
        }

        for user_id in range(n_users):
            user_type = user_types[user_id]

            # ユーザープロファイル作成（再現性のため固定シード）
            profile_seed = 100 + user_id
            user_profile = UserProfile(user_id, user_type, seed=profile_seed)

            # ユーザーデータ生成
            decisions, feedbacks = self.generate_user_data(
                user_profile,
                n_decisions=decisions_per_user
            )

            all_data['users'].append({
                'user_id': user_id,
                'user_type': user_type,
                'stress_sensitivity': user_profile.stress_sensitivity,
                'price_sensitivity': user_profile.price_sensitivity,
                'mood_sensitivity': user_profile.mood_sensitivity,
                'baseline_regret': user_profile.baseline_regret
            })

            all_data['decisions'].extend(decisions)
            all_data['feedbacks'].extend(feedbacks)

            if (user_id + 1) % 10 == 0:
                print(f"Generated data for {user_id + 1}/{n_users} users...")

        print(f"\nDataset generation complete!")
        print(f"Total users: {len(all_data['users'])}")
        print(f"Total decisions: {len(all_data['decisions'])}")
        print(f"Total feedbacks: {len(all_data['feedbacks'])}")

        return all_data

    def save_dataset(self, dataset, filename='synthetic_dataset.json'):
        """データセットをJSONファイルに保存"""
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(dataset, f, indent=2, ensure_ascii=False)
        print(f"Dataset saved to: {filename}")
        return filename


if __name__ == '__main__':
    # テスト実行
    print("Synthetic Data Generator")
    print("=" * 60)

    generator = SyntheticDataGenerator(seed=42)

    # 小規模データセット生成（テスト用）
    dataset = generator.generate_dataset(n_users=10, decisions_per_user=20)

    # 保存
    generator.save_dataset(dataset, 'test_synthetic_data.json')

    print("\nSample user profile:")
    print(json.dumps(dataset['users'][0], indent=2, ensure_ascii=False))

    print("\nSample decision:")
    print(json.dumps(dataset['decisions'][0], indent=2, ensure_ascii=False))

    print("\nSample feedback:")
    print(json.dumps(dataset['feedbacks'][0], indent=2, ensure_ascii=False))
