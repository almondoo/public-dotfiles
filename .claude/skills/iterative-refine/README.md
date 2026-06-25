# iterative-refine

## 概要

`iterative-refine` は、同一セッション内で `implement → verify → fix → re-verify` のサイクルを回す反復改良ループのための skill である。あらかじめ終了条件を明示的に定義することで、「だいたい良さそう」での早期打ち切り、無関係なファイルへのスコープ逸脱、verification 基準の暗黙のすり替えといった、無制限な self-refinement に伴いがちな失敗モードを防ぐ。会話境界を越えて生存する必要があるループには使わず、その場合は `/loop` (ScheduleWakeup ベース) を使う。

## いつ使うか

- 「全テストを pass させて」
- 「type エラー / lint エラーをすべて潰して」
- 「`<objective check>` が通るまで X を refactor して」
- レビュー指摘を順次反映していき、verification command が通るまで詰める作業
- その他、ループの終了条件が **客観的なチェック (exit code 等)** で判定できるタスク全般

逆に、以下のケースには使わない:

- 反復を要しない単発タスク (1 回の編集、1 回のコマンド実行で完結するもの)
- 終了条件が主観でしか判定できないタスク (例: 「見た目をもっと良くして」)
- セッションをまたぐ必要があるループ (`/loop` を使う)

## 必要な入力

ループ開始前に、以下が揃っていなければ `AskUserQuestion` でユーザーに確認する:

1. **Goal** — 達成したい状態を 1 文で表したもの (例: 「現在の branch で `pnpm test` が全件 pass する」)
2. **Verification command** — 成功か否かを exit code で決定論的に判定できる shell コマンド (例: `pnpm test && pnpm tsc --noEmit && pnpm lint`)
3. **Max iterations** — 最大反復回数 (デフォルト 5)
4. **Scope** — 編集を許可するファイル / glob、および触ってはならないファイル。未指定なら「現在の diff に含まれるファイルとそのテスト」をデフォルトにする

## ループ構造

各 iteration `N = 1..MAX` について、次の手順で進める:

- **verify フェーズ**: verification command を実行し、stdout / stderr を取得する
- **判定フェーズ**: exit code が 0 なら success として終了。そうでなければ失敗を分解し、失敗ごとに `TaskCreate` で 1 タスク作成する
- **fix フェーズ**: 最小限の修正を当て、解消したタスクから `TaskUpdate completed` していく
- **oscillation チェック**: 今回の verification 出力を前 iteration の出力と比較し、(末尾空白除去後に) byte-equal なら `oscillation_count` を 1 増やす。差分があれば 0 にリセット
- **継続判定**: `oscillation_count >= 2` なら oscillation として停止。`N == MAX` なら max-iterations として停止。いずれでもなければ次の iteration へ

フェーズ間で守るべき条件:

- **verification command 自体は変更しない**: goalpost を mid-loop で動かすことは禁止
- **scope 外のファイルは編集しない**: 「ついでに」直したくなる衝動は scope creep の兆候
- **`escape-attempt` は他のあらゆる継続条件に優先**: 「あと 1 回だけ」と思っても、それが escape を伴うなら回さない

## 明示的な終了条件

優先順位順に、以下のいずれかで必ず停止する。`escape-attempt` は `oscillation` / `max-iterations` よりも常に優先される。

| Code | 発火条件 | 必要なアクション |
|---|---|---|
| `success` | verification の exit code が 0 | 最終 verification 出力 (末尾 20 行程度) を報告して終了 |
| `escape-attempt` | テストを skip / disable しようとした、assertion を弱めようとした、snapshot / expected ファイルを producer の代わりに編集しようとした、verification command 自体を書き換えようとした | 直ちに停止し、`AskUserQuestion` でユーザーに状況を上げる |
| `oscillation` | 2 iteration 連続で verification 出力が同一 (進捗なし) | 停止して、試した内容を報告し、ユーザーに方針を確認 |
| `max-iterations` | success せずに `N` が `MAX` に到達 | 停止し、現時点の best state と残課題を報告 |

## アンチパターン (verification cheating)

以下はすべて **escape attempt** に該当する。これらに手を出したくなった時点で「もっと頑張れ」のサインではなく「停止して報告せよ」のサインと解釈する。

- verification command 自体の書き換え (goalpost shift)
- 失敗テストの skip / 無効化 — `.skip`、`xfail`、`@pytest.mark.skip`、`it.skip`、`it.todo`、コメントアウト等
- assertion や expected value を「通る値」に書き換える assertion weakening
- producer を直さずに snapshot / expected-output ファイルだけを更新する
- 現 diff に含まれているという理由だけで、本来のタスクと無関係なファイルを「ついで」に修正する scope creep
- ユーザーの明示的許諾なく、広域に lint / type エラーを抑止する: `// @ts-ignore`、`# type: ignore`、`eslint-disable`、`noqa` 等

## 出力形式

ループを停止する際は、診断しやすいよう以下の形式で必ず報告する:

```
Reason: <success | oscillation | max-iterations | escape-attempt>
Iterations: N / MAX
Final verification (exit <code>):
  <last ~20 lines of output>
Changes made:
  <git diff --stat or equivalent>
Unresolved (if applicable):
  - <failure 1>
  - <failure 2>
Next-step suggestion: <one sentence>
```

## 関連

- `SKILL.md` (英語原本、本ドキュメントの source of truth)
- `superpowers:test-driven-development` — red → green → refactor の内部に類似ループを内包。test-first が明示されているタスクではこちらを優先
- `superpowers:verification-before-completion` — 完了宣言前の 1 回の verification を必須化する規律。`iterative-refine` はその 1 回チェックを、明示的終了条件付きの多 iteration ループへ拡張したもの
- `superpowers:systematic-debugging` — hypothesis → test → refine を bug-hunt にスコープしたもの。タスクが「バグを見つける」ならこちらを優先し、「verification を通す」なら `iterative-refine` を使う
- `/loop` (top-level skill) — `ScheduleWakeup` ベースのセッション横断ループ。会話境界を越えて待機が必要な場合 (例: CI を 30 分待つ) に使う。`iterative-refine` はあくまでセッション内専用
