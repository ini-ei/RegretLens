# 論文用 図・表の一覧

## 図一覧

| 番号 | 説明 | ファイル | 形式 |
|------|------|----------|------|
| 図1 | ハイブリッド予測アーキテクチャ | (TikZで作成) | フローチャート |
| 図2 | システム構成 | (TikZで作成) | 構成図 |
| 図3 | 実験1: モデル性能比較 | figures/exp1_mae_comparison.png | 棒グラフ |
| 図4 | 実験3: ユーザータイプ別MAE | figures/exp3_usertype_mae.png | 棒グラフ |
| 図5 | ユーザータイプ別の特徴量重要度 | figures/feature_importance_by_type.png | 横棒グラフ |

### 追加で生成済み（本文未使用）
- figures/exp2_jaccard_distribution.png - Jaccard距離の分布
- figures/exp4_lstm_comparison.png - 時系列モデル比較

## 表一覧

| 番号 | 説明 |
|------|------|
| 表1 | 実験1: モデル性能比較（MAE, 標準偏差） |
| 表2 | 実験2: 特徴量選択の効果 |
| 表3 | 実験3: ユーザータイプ別精度 |
| 表4 | 実験4: 時系列モデル比較 |

## TeXへの変換時の注意

### 図1, 図2のTikZ化
図1と図2はマークダウン内のASCIIアートで表現されています。
TeXではTikZを使ってフローチャート/構成図として描画してください。

### 図3-5の挿入
```latex
\begin{figure}[htbp]
  \centering
  \includegraphics[width=0.8\linewidth]{figures/exp1_mae_comparison.png}
  \caption{実験1: モデル性能比較}
  \label{fig:exp1}
\end{figure}
```

### 表の形式
マークダウンの表をLaTeXのtabular環境に変換してください。

```latex
\begin{table}[htbp]
  \centering
  \caption{実験1: モデル性能比較}
  \label{tab:exp1}
  \begin{tabular}{lcc}
    \hline
    手法 & MAE & 標準偏差 \\
    \hline
    ルールベース & 0.1365 & 0.0375 \\
    RF（全18特徴量） & 0.0842 & 0.0191 \\
    RF + 適応的選択 & 0.0833 & 0.0193 \\
    \hline
  \end{tabular}
\end{table}
```

### 数式
マークダウン内の数式（$$で囲まれた部分）はそのままLaTeXで使用可能です。

例：
```latex
I_j = \frac{1}{n} \sum_{i=1}^{n} |\text{SHAP}_{ij}|
```

## ファイル構成

```
local_only/paper/
├── 論文_v2.md          # 最終版マークダウン
├── generate_figures.py  # グラフ生成スクリプト
├── README_figures.md    # このファイル
└── figures/
    ├── exp1_mae_comparison.png
    ├── exp2_jaccard_distribution.png
    ├── exp3_usertype_mae.png
    ├── exp4_lstm_comparison.png
    └── feature_importance_by_type.png
```
