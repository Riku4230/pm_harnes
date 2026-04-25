import { query } from "@anthropic-ai/claude-code";
import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

async function selfImprove() {
  const cwd = process.env.CLAUDE_CWD || process.cwd();

  // Phase 1: check（決定論的、高速）
  const checkIssues: string[] = [];

  // context-routingの参照先が存在するか
  const routingPath = path.join(cwd, ".claude/rules/02-context-routing.md");
  if (fs.existsSync(routingPath)) {
    const content = fs.readFileSync(routingPath, "utf-8");
    const refs = content.match(/(?:state|docs)\/[\w.]+/g) || [];
    for (const ref of refs) {
      if (!fs.existsSync(path.join(cwd, ref))) {
        checkIssues.push(`Missing file: ${ref} (referenced in context-routing)`);
      }
    }
  }

  // anti-patterns件数チェック
  const antiPath = path.join(cwd, ".claude/rules/03-anti-patterns.md");
  if (fs.existsSync(antiPath)) {
    const lines = fs.readFileSync(antiPath, "utf-8").split("\n");
    const entries = lines.filter((l) => l.match(/^## AP-\d+/));
    if (entries.length > 10) {
      checkIssues.push(`anti-patterns has ${entries.length} entries (>10, needs pruning)`);
    }
  }

  // rules総行数チェック
  const rulesDir = path.join(cwd, ".claude/rules");
  if (fs.existsSync(rulesDir)) {
    let totalLines = 0;
    for (const f of fs.readdirSync(rulesDir)) {
      if (f.endsWith(".md")) {
        totalLines += fs.readFileSync(path.join(rulesDir, f), "utf-8").split("\n").length;
      }
    }
    if (totalLines > 60) {
      checkIssues.push(`Rules total ${totalLines} lines (>60 limit)`);
    }
  }

  // Phase 2: entropy + feedback-loop（LLM推論）
  const improvementsPath = path.join(cwd, "state/IMPROVEMENTS.json");
  let itemCount = 0;
  if (fs.existsSync(improvementsPath)) {
    try {
      const data = JSON.parse(fs.readFileSync(improvementsPath, "utf-8"));
      itemCount = (data.items || []).length;
    } catch {}
  }

  if (checkIssues.length > 0 || itemCount >= 3) {
    const checkContext = checkIssues.length > 0
      ? `\n\n決定論チェックで以下の問題を検出:\n${checkIssues.map((i) => `- ${i}`).join("\n")}`
      : "";

    const result = await query({
      prompt: `
あなたはハーネスエンジニア。PM-Harnessの改善提案を行ってください。
${checkContext}

読むべきファイル:
1. state/IMPROVEMENTS.json（蓄積された改善提案）
2. state/SESSION_LOG.json（直近のセッション履歴）
3. .claude/rules/ 配下の全ファイル

分析:
- IMPROVEMENTS.jsonの頻出パターンを特定
- rules/の不要ルール（長期間効果不明）を特定
- 改善案を以下の3層に分類:
  ①で防げたはず → スキーマ/hook/allowed-toolsの強化提案
  ②で検出できたはず → L1センサーにチェック追加提案
  新規対応 → 新しいスキルやルールの提案

出力: state/REVIEW_PROPOSALS.jsonに以下の形式で書き出し:
{
  "proposals": [
    {"target": "変更対象ファイル", "action": "追加|修正|削除", "reason": "根拠", "priority": "high|medium|low", "layer": "1|2|3"}
  ],
  "check_issues": ${JSON.stringify(checkIssues)},
  "last_run": "現在時刻ISO 8601",
  "improvements_processed": 処理したIMPROVEMENTS件数
}
全変更はユーザー承認後に適用。自律的にrules/skills/を書き換えてはいけない。
      `,
      options: {
        cwd,
        allowedTools: ["Read", "Write"],
        permissionMode: "acceptEdits",
        model: "sonnet",
        maxTurns: 8,
      },
    });
  }
}

selfImprove().catch((e) => {
  console.error("self-improve failed:", e.message);
  process.exit(0);
});
