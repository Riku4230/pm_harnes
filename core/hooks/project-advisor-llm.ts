import { query } from "@anthropic-ai/claude-code";

async function dailyProjectReview() {
  const cwd = process.env.CLAUDE_CWD || process.cwd();

  const result = await query({
    prompt: `
あなたはプロジェクトアドバイザー。以下を読んで、PMが見落としている
危険信号や改善機会を指摘してください。

読むべきファイル:
1. state/STATUS.json（現在状態）
2. state/RISK.json（リスク台帳）
3. state/WBS.json（スケジュール）
4. state/CHANGELOG.json（直近10件の意思決定）
5. state/SESSION_LOG.json（直近5セッション）

観点:
- 意思決定間の矛盾はないか
- リスクの評価は妥当か（過小/過大評価）
- スケジュールの現実性（このペースで間に合うか）
- コミュニケーション上の懸念（共有漏れ、根回し不足）
- 「やるべきだがやっていないこと」

出力: state/ALERTS.jsonのllm_alertsフィールドにJSON配列で書き出し。
各アラート: {"type": "...", "severity": "high|medium|low", "message": "...", "reasoning": "..."}
高確信のものだけ出力。「かもしれない」レベルは出さない。
llm_checkedフィールドも現在時刻のISO 8601で更新する。
既存のrule_alertsフィールドは変更しないこと。
    `,
    options: {
      cwd,
      allowedTools: ["Read", "Write"],
      permissionMode: "acceptEdits",
      model: "sonnet",
      maxTurns: 5,
    },
  });
}

dailyProjectReview().catch((e) => {
  console.error("project-advisor-llm failed:", e.message);
  process.exit(0);
});
