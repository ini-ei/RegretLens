"""
RegretLens Temporal Learner - 時系列パターン学習エンジン
LSTM/GRUによる意思決定シーケンス学習と予測
"""
import numpy as np
import json
import os
from datetime import datetime
import pickle

# PyTorch (オプション)
try:
    import torch
    import torch.nn as nn
    import torch.optim as optim
    from torch.utils.data import Dataset, DataLoader
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False
    print("Warning: PyTorch not available. Install with: pip install torch")

from ml_engine import extract_features


class DecisionSequenceDataset(Dataset):
    """意思決定シーケンスデータセット（PyTorch用）"""

    def __init__(self, sequences, targets, sequence_length=10):
        """
        Args:
            sequences: 特徴量シーケンス list of arrays
            targets: 後悔スコア list
            sequence_length: シーケンス長
        """
        self.sequences = sequences
        self.targets = targets
        self.sequence_length = sequence_length

    def __len__(self):
        return len(self.sequences)

    def __getitem__(self, idx):
        sequence = torch.FloatTensor(self.sequences[idx])
        target = torch.FloatTensor([self.targets[idx]])
        return sequence, target


class LSTMRegretPredictor(nn.Module):
    """LSTM-based後悔予測モデル"""

    def __init__(self, input_size=18, hidden_size=64, num_layers=2, dropout=0.2):
        super(LSTMRegretPredictor, self).__init__()

        self.hidden_size = hidden_size
        self.num_layers = num_layers

        # LSTM層
        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            dropout=dropout if num_layers > 1 else 0,
            batch_first=True
        )

        # Attention層（簡易版）
        self.attention = nn.Linear(hidden_size, 1)

        # 出力層
        self.fc = nn.Sequential(
            nn.Linear(hidden_size, 32),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(32, 1),
            nn.Sigmoid()  # 0-1の範囲に正規化
        )

    def forward(self, x):
        """
        Args:
            x: (batch_size, sequence_length, input_size)

        Returns:
            output: (batch_size, 1)
        """
        # LSTM forward pass
        lstm_out, (hidden, cell) = self.lstm(x)
        # lstm_out: (batch_size, sequence_length, hidden_size)

        # Attentionメカニズム（簡易版）
        attention_weights = torch.softmax(self.attention(lstm_out), dim=1)
        # attention_weights: (batch_size, sequence_length, 1)

        # 重み付き平均
        context = torch.sum(attention_weights * lstm_out, dim=1)
        # context: (batch_size, hidden_size)

        # 出力層
        output = self.fc(context)
        return output


class GRURegretPredictor(nn.Module):
    """GRU-based後悔予測モデル（LSTMの軽量版）"""

    def __init__(self, input_size=18, hidden_size=64, num_layers=2, dropout=0.2):
        super(GRURegretPredictor, self).__init__()

        self.hidden_size = hidden_size
        self.num_layers = num_layers

        # GRU層
        self.gru = nn.GRU(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            dropout=dropout if num_layers > 1 else 0,
            batch_first=True
        )

        # 出力層
        self.fc = nn.Sequential(
            nn.Linear(hidden_size, 32),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(32, 1),
            nn.Sigmoid()
        )

    def forward(self, x):
        gru_out, hidden = self.gru(x)
        # 最後のタイムステップの出力を使用
        last_output = gru_out[:, -1, :]
        output = self.fc(last_output)
        return output


class TemporalLearner:
    """時系列学習メインクラス"""

    def __init__(self, user_id, model_type='lstm', sequence_length=10):
        """
        Args:
            user_id: ユーザーID
            model_type: 'lstm' or 'gru'
            sequence_length: 使用する過去の意思決定数
        """
        self.user_id = user_id
        self.model_type = model_type
        self.sequence_length = sequence_length
        self.model = None
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.models_dir = os.path.join(os.path.dirname(__file__), 'models')
        os.makedirs(self.models_dir, exist_ok=True)

    def prepare_sequence_data(self, user_history, feedbacks):
        """
        時系列データをシーケンス形式に変換

        Args:
            user_history: ユーザーの意思決定履歴
            feedbacks: フィードバックデータ

        Returns:
            (sequences, targets): 特徴量シーケンスと後悔スコア
        """
        sequences = []
        targets = []

        # 時系列順にソート
        sorted_history = sorted(user_history, key=lambda x: x.get('created_at', ''))

        for i in range(self.sequence_length, len(sorted_history)):
            # 過去sequence_length個の決定を特徴量に変換
            sequence = []

            for j in range(i - self.sequence_length, i):
                decision = sorted_history[j]
                decision_data = {
                    'category': decision.get('category'),
                    'context': decision.get('context', {}),
                    'decision_factors': decision.get('decision_factors', {})
                }

                # この決定時点までの履歴
                past_history = sorted_history[:j]
                past_feedbacks = [f for f in feedbacks if any(
                    d.get('id') == f.get('decision_id') for d in past_history
                )]

                # 特徴量抽出
                features = extract_features(decision_data, past_history, past_feedbacks)

                # 18次元特徴ベクトル
                feature_vector = [
                    features.get('price', 0),
                    features.get('taste_expectation', 3),
                    features.get('health_value', 3),
                    features.get('time_required', 0),
                    features.get('mood_score', 3),
                    features.get('stress_level', 3),
                    features.get('hunger_level', 3),
                    features.get('budget_remaining', 0),
                    features.get('with_others', 0),
                    features.get('hour_of_day', 12),
                    features.get('is_lunch_time', 0),
                    features.get('is_dinner_time', 0),
                    features.get('day_of_week', 0),
                    features.get('weather_encoded', 1),
                    features.get('user_average_regret_this_category', 3),
                    features.get('user_regret_variance', 0),
                    features.get('similar_past_decisions_count', 0),
                    features.get('recent_regret_trend', 3)
                ]
                sequence.append(feature_vector)

            # 現在の決定の後悔スコアを取得
            current_decision = sorted_history[i]
            current_feedback = None
            for f in feedbacks:
                if f.get('decision_id') == current_decision.get('id'):
                    current_feedback = f
                    break

            if current_feedback:
                regret_score = (current_feedback.get('regret_score', 3) - 1) / 4.0  # 0-1に正規化
                sequences.append(sequence)
                targets.append(regret_score)

        return np.array(sequences, dtype=np.float32), np.array(targets, dtype=np.float32)

    def train_model(self, user_history, feedbacks, epochs=50, batch_size=8, lr=0.001):
        """
        時系列モデルを訓練

        Args:
            user_history: ユーザーの意思決定履歴
            feedbacks: フィードバックデータ
            epochs: エポック数
            batch_size: バッチサイズ
            lr: 学習率

        Returns:
            dict: 訓練結果
        """
        if not TORCH_AVAILABLE:
            return {'error': 'PyTorch not available'}

        # データ準備
        sequences, targets = self.prepare_sequence_data(user_history, feedbacks)

        if len(sequences) < 10:
            return {
                'error': f'Insufficient sequence data (got {len(sequences)}, need at least 10)'
            }

        # データセット作成
        dataset = DecisionSequenceDataset(sequences, targets, self.sequence_length)
        dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

        # モデル初期化
        input_size = sequences.shape[2]  # 18
        if self.model_type == 'lstm':
            self.model = LSTMRegretPredictor(input_size=input_size).to(self.device)
        else:
            self.model = GRURegretPredictor(input_size=input_size).to(self.device)

        # 損失関数と最適化
        criterion = nn.MSELoss()
        optimizer = optim.Adam(self.model.parameters(), lr=lr)

        # 訓練ループ
        training_losses = []
        self.model.train()

        for epoch in range(epochs):
            epoch_loss = 0.0
            batch_count = 0

            for batch_sequences, batch_targets in dataloader:
                batch_sequences = batch_sequences.to(self.device)
                batch_targets = batch_targets.to(self.device)

                # Forward pass
                optimizer.zero_grad()
                outputs = self.model(batch_sequences)
                loss = criterion(outputs, batch_targets)

                # Backward pass
                loss.backward()
                optimizer.step()

                epoch_loss += loss.item()
                batch_count += 1

            avg_loss = epoch_loss / batch_count if batch_count > 0 else 0
            training_losses.append(avg_loss)

            if (epoch + 1) % 10 == 0:
                print(f"Epoch [{epoch+1}/{epochs}], Loss: {avg_loss:.4f}")

        # モデル保存
        model_path = self.get_model_path()
        torch.save({
            'model_state_dict': self.model.state_dict(),
            'model_type': self.model_type,
            'sequence_length': self.sequence_length,
            'training_losses': training_losses
        }, model_path)

        print(f"Model saved to: {model_path}")

        return {
            'final_loss': training_losses[-1],
            'training_losses': training_losses,
            'epochs': epochs,
            'training_samples': len(sequences),
            'model_path': model_path
        }

    def predict(self, user_history, feedbacks, return_attention=False):
        """
        時系列モデルで予測

        Args:
            user_history: ユーザーの意思決定履歴
            feedbacks: フィードバックデータ
            return_attention: Attention weightsを返すか

        Returns:
            dict: 予測結果
        """
        if not TORCH_AVAILABLE or self.model is None:
            return {'error': 'Model not trained or PyTorch not available'}

        # 最新のsequence_length個の決定から特徴量を抽出
        sorted_history = sorted(user_history, key=lambda x: x.get('created_at', ''))

        if len(sorted_history) < self.sequence_length:
            return {
                'error': f'Insufficient history (got {len(sorted_history)}, need {self.sequence_length})'
            }

        sequence = []
        for i in range(len(sorted_history) - self.sequence_length, len(sorted_history)):
            decision = sorted_history[i]
            decision_data = {
                'category': decision.get('category'),
                'context': decision.get('context', {}),
                'decision_factors': decision.get('decision_factors', {})
            }

            past_history = sorted_history[:i]
            past_feedbacks = [f for f in feedbacks if any(
                d.get('id') == f.get('decision_id') for d in past_history
            )]

            features = extract_features(decision_data, past_history, past_feedbacks)

            feature_vector = [
                features.get('price', 0),
                features.get('taste_expectation', 3),
                features.get('health_value', 3),
                features.get('time_required', 0),
                features.get('mood_score', 3),
                features.get('stress_level', 3),
                features.get('hunger_level', 3),
                features.get('budget_remaining', 0),
                features.get('with_others', 0),
                features.get('hour_of_day', 12),
                features.get('is_lunch_time', 0),
                features.get('is_dinner_time', 0),
                features.get('day_of_week', 0),
                features.get('weather_encoded', 1),
                features.get('user_average_regret_this_category', 3),
                features.get('user_regret_variance', 0),
                features.get('similar_past_decisions_count', 0),
                features.get('recent_regret_trend', 3)
            ]
            sequence.append(feature_vector)

        # 予測
        self.model.eval()
        with torch.no_grad():
            sequence_tensor = torch.FloatTensor([sequence]).to(self.device)
            prediction = self.model(sequence_tensor)
            predicted_score = prediction.item()

        return {
            'regret_score': predicted_score,
            'model_type': self.model_type,
            'sequence_length': self.sequence_length
        }

    def get_model_path(self):
        """モデル保存パスを取得"""
        filename = f'temporal_{self.model_type}_{self.user_id}.pth'
        return os.path.join(self.models_dir, filename)

    def load_model(self):
        """保存されたモデルを読み込み"""
        model_path = self.get_model_path()

        if not os.path.exists(model_path):
            return False

        if not TORCH_AVAILABLE:
            return False

        checkpoint = torch.load(model_path, map_location=self.device)

        input_size = 18
        if checkpoint['model_type'] == 'lstm':
            self.model = LSTMRegretPredictor(input_size=input_size).to(self.device)
        else:
            self.model = GRURegretPredictor(input_size=input_size).to(self.device)

        self.model.load_state_dict(checkpoint['model_state_dict'])
        self.model_type = checkpoint['model_type']
        self.sequence_length = checkpoint['sequence_length']

        print(f"Model loaded from: {model_path}")
        return True


if __name__ == '__main__':
    print("Temporal Learner - LSTM/GRU-based Regret Prediction")
    print("=" * 60)
    print("This module implements sequence learning for decision patterns.")
    print("")
    print("Usage:")
    print("from temporal_learner import TemporalLearner")
    print("")
    print("learner = TemporalLearner(user_id, model_type='lstm')")
    print("result = learner.train_model(history, feedbacks)")
    print("prediction = learner.predict(history, feedbacks)")
