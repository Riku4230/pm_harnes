# Loop Monitor Policy

## 目的
同じ作業の繰り返し（レビュー↔修正、確認↔変更）が発散していないか検知する。

## ルール
- 同種のスキルが3回連続で実行された場合、ユーザーに確認する
- 「このまま続けますか？別のアプローチを検討しますか？」
- 強制停止はしない。判断はPMに委ねる

## 検知パターン
| パターン | 閾値 | アクション |
|---|---|---|
| risk-check → wbs-update → risk-check（リスク↔計画ループ） | 3回 | 「スコープを確定すべきでは？」 |
| meeting-import → draft-update → meeting-import（確認↔共有ループ） | 3回 | 「合意形成の方法を見直すべきでは？」 |
| context-sync → context-review → context-sync（同期↔改善ループ） | 3回 | 「根本的な構造問題がないか確認」 |

## 実装
SESSION_LOG.jsonの直近のスキル実行履歴を確認。
session-start.shで検知し、警告として表示する。
