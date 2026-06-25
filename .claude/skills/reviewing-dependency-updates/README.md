# reviewing-dependency-updates

## 概要

Dependabot / Renovate / 手動bumpによって作成された依存更新PRをレビューするためのskillです。「CIがgreenだからマージ」という単一指標での判断を避け、security-firstの方針に基づく3フェーズのチェックリストでPRごとに `merge` / `hold` / `block` のいずれかに分類します。最終的なマージ操作は必ずユーザー承認を得てから実行し、自動マージは行いません。

中核となる前提として、Dependabot / Renovate が作成するPR自体は信頼できても、bump先の **パッケージ本体は第三者コード** であり、green CIはあくまでプロジェクトのテストが通ることのみを保証する点に注意します。

## いつ使うか

- Dependabot や Renovate が開いた依存更新PRを approve / merge する直前。
- 手動の依存bump PR(`package.json`、`go.mod`、`Cargo.toml` 等の更新)をレビューするとき。
- `gh pr list` で複数の依存更新PRが上がっており、どれをマージすべきか判断したいとき。
- 月例の依存棚卸し・脆弱性チェックなど、定期的な依存衛生作業を行うとき。
- GitHub Security Advisory に該当パッケージの告知が出たとき。

## 3フェーズ・チェックリスト

各フェーズは順番に実施し、**いずれかでblockerが見つかった時点で即座に `do-not-merge` 分類とし、以降のフェーズは中止** します。

### Phase 1: basic CI / mergeability

基本的なマージ可否を機械的に確認するフェーズです。CIマトリクス・コンフリクト・バージョン跳び幅を見て、そもそも安全にmergeできる状態かを判定します。

確認項目:

- **CI status**: マトリクス全セル(OS × 言語バージョン等)が SUCCESS であること。`CANCELLED` のみであれば再実行可否を判断し、`FAILURE` があれば `gh run view <RUN_ID> --log-failed` で原因を特定する。
- **Mergeability**: `gh pr view <NUMBER> --json mergeable,mergeStateStatus` で `mergeable=MERGEABLE` かつ `mergeStateStatus=CLEAN` であること。
- **Version-jump class** の分類:
  - **patch (x.y.Z)**: 低リスク。通常はマージ可能。
  - **minor (x.Y.0)**: 中リスク。changelogレビュー必須。
  - **major (X.0.0)**: 高リスク。Phase 2 / 3 を完全に実施すること。
- 利用コマンド例:
  - `gh pr list --state open --json number,title,headRefName,labels`
  - `gh pr view <NUMBER> --json title,mergeable,mergeStateStatus,statusCheckRollup,files,additions,deletions`

### Phase 2: supply-chain trust

サプライチェーン視点でパッケージの公開元・メンテナの信頼性を確認するフェーズです。typosquatting・アカウント乗っ取り・悪意あるメンテナの混入といった攻撃面を見ます。

確認項目:

- **GitHub Security Advisory**: `gh api repos/{owner}/{repo}/vulnerability-alerts` もしくは GitHub の Security タブで、対象パッケージに既知の脆弱性が存在しないか確認。当該PRがsecurity fixを含むなら優先度を上げる。
- **公開元の信頼性**:
  - `actions/*` / `github/*` / `golang.org/x/*` などの公式org公開物 → 高信頼。
  - それ以外はメンテナンス健全性(最終更新日・メンテナ人数・activity)を確認。
- **異常検知シグナル**: ダウンロード数 / star数の急変化、新規メンテナの追加 → typosquatting / アカウント乗っ取りの可能性。
- **transitive dependencies**: `go.sum` / `package-lock.json` / `pnpm-lock.yaml` 等のdiffが予想外に大きくないか。
- **GitHub Actions固有**: タグ pinning (`@v6`) ではなく commit-SHA pinning (`@sha`) を優先する。

### Phase 3: breaking-change & runtime-compatibility

破壊的変更とランタイム互換性を確認する最終フェーズです。release notes、API変更、言語バージョン要件の引き上げなど、メジャー / マイナー bump で見落とすと壊れるポイントを潰します。

確認項目:

- **Breaking changes**: release notes / CHANGELOG を読み、API変更・削除された機能・挙動変更を洗い出す。
- **言語バージョン要件の引き上げ**:
  - `go.mod` の `go` ディレクティブ、`package.json` の `engines`、`pyproject.toml` の `requires-python` 等。
  - **常にCIマトリクスの最低バージョンと整合性を確認**。例: 依存が `go 1.24` を要求するがCIに `go 1.19` が残っている → `do-not-merge`。
- **プロジェクト固有の依存マニフェスト**: `alldeps` 形式のファイルや内部manifestの更新漏れがないか、lockfileの整合性が保たれているか。
- **ランタイム挙動**: タイムゾーン・ロケール・デフォルト値の変更など、テストで拾いきれない実行時挙動の差分を changelog から確認。

## 分類結果

各PRは最終的に以下のいずれかに分類します。

| 分類 | 判定基準 |
|----|----|
| **merge** | CI全green + security懸念なし + breaking changeなし |
| **hold (caution)** | major bump + CI全green + security懸念なし。ただしbreaking changeあり・影響範囲限定 |
| **block (do-not-merge)** | CI failure / security懸念あり / 互換性破壊あり |

レポートは以下の表形式でユーザーに提示します:

```
| PR | Version change | CI | Security | Breaking | Verdict | Recommended action |
|----|---------------|----|----------|----------|---------|--------------------|
```

各PRごとに判断理由を簡潔に添え、推奨アクション(`merge` / `close` / `hold`)を明示します。**推奨アクションの実行はユーザーの明示的な承認後にのみ行い、自動マージは絶対にしない** 点を厳守します。

## 注意点・前提

見落としやすい論点を以下にまとめます。

- **CIだけで判断しない**: green CIは「プロジェクトのテストが通った」ことのみ保証し、パッケージ本体の安全性は保証しない。Phase 2 / 3 を必ず通すこと。
- **major bumpを routine 扱いしない**: 必ず breaking change と互換性を確認する。
- **「Dependabotだから安全」は誤り**: bump先のパッケージは第三者コード。
- **changelog未読でのマージ禁止**: release notesを読まずに merge しない。
- **transitive依存のdiff肥大化を見逃さない**: `go.sum` / lockfileのdiff行数を確認。
- **GitHub Actionsはtag pinningよりSHA pinningを優先**: `@v6` ではなく `@<commit-sha>` で固定する。
- **バッチマージしない**: 1つマージするとbase shaが変わり、後続PRのCI再実行や追加コンフリクトの原因になる。1件ずつ順番に処理する。
- **言語バージョン要件は CI matrix の最低値で評価**: 自分のローカル環境が満たしていても、CI matrix の古いバージョンで動かなければNG。
- **lockfile / 内部manifestの整合性**: アプリケーションコードのbumpだけでなく、lockfileや `alldeps` 系ファイルの更新漏れもチェック。

## Red Flags(STOP before merging)

以下のいずれかに該当する場合、マージ前に必ず立ち止まって精査します。

- CIのいずれかのセルが FAILURE(CANCELLED-only は調査対象、即停止ではない)。
- major bumpかつchangelog未読。
- 言語バージョン要件が引き上げられている(`go` ディレクティブ、`engines` 等)。
- パッケージのメンテナが最近変更された。
- transitive依存のdiffが異常に大きい。
- 関連する Security Advisory が存在する。

## 関連

- `SKILL.md` — 英語原本(本READMEはこれを日本語で要約したもの)。
- `gh pr list` / `gh pr view` / `gh run view` — Phase 1 で使う `gh` CLI コマンド群。
- `gh api repos/{owner}/{repo}/vulnerability-alerts` — Phase 2 の脆弱性確認API。
