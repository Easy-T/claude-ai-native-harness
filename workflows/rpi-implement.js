export const meta = {
  name: 'rpi-implement',
  description: 'RPIC Phase I (d) canonical 2-stage pipeline — execute(opus) → review(inherit)',
  phases: [
    { title: 'Implement', detail: 'plan task별 execute-strict (opus, heavy→xhigh/light→high, per-task effort override 허용)' },
    { title: 'Verify', detail: 'task별 review-strict (모델 무지정=세션 상속 — 검증자 하향 금지)' },
  ],
}
// 역할×모델 매트릭스 canonical 캐리어 (spec 2026-07-25 §10, SSOT: docs/ai-context/model-policy.md).
// args = [{title, promptVerbatim, files[], successCriteria, heavy, effort?, worktree}]
// - promptVerbatim: plan task 본문 원문 (TDD-verbatim — 요약 금지, RED/GREEN 증거 포함 강제)
// - heavy: 코드/TDD/다파일=true(effort xhigh), 순수 문서·기계 편집=false(high — Opus 5 기본값 밑으로 불가)
//   (§0 품질-우선 상향 2026-07-26: 종전 high/medium은 비-ultracode 상속(xhigh/max)보다 낮아지는 역전 결함)
// - effort: per-task 선언적 override (max 포함 양방향 — 명시=선언이라 DOWNGRADE 규율 정합)
// - worktree: 같은 파일을 동시 수정하는 task ≥2일 때 true (stage2는 같은 worktree에서 리뷰)
// 불변식: stage1 model 고정 opus / stage2 model·effort 무지정(상속) / schema 금지(wrapper StructuredOutput 부재)
// / 커밋은 여기서 하지 않는다(병렬 index.lock 경합 — 메인이 그룹 커밋).
if (!Array.isArray(args) || args.length === 0) {
  throw new Error('rpi-implement: args must be a non-empty task array — [{title, promptVerbatim, files, successCriteria, heavy, effort?, worktree}]')
}
const results = await pipeline(
  args,
  (t, _o, i) => agent(
    `plan task 본문 verbatim — 이대로 수행 (요약·재서술 금지, RED/GREEN 증거를 보고에 원문 인용):\n\n${t.promptVerbatim}\n\n` +
    `scope: 명시 파일만 수정 — ${JSON.stringify(t.files)}. 커밋하지 말 것(메인이 그룹 커밋).`,
    {
      agentType: 'execute-strict',
      model: 'opus',
      effort: t.effort ?? (t.heavy ? 'xhigh' : 'high'),
      label: `implement:${t.title}`,
      phase: 'Implement',
      ...(t.worktree ? { isolation: 'worktree' } : {}),
    }
  ),
  (stage1Report, t) => agent(
    `task: "${t.title}" 구현 검증 (stage1 산출 대조 — 아래 보고와 실파일 diff를 모두 읽고 판정).\n\n` +
    `stage1 보고 원문:\n${String(stage1Report).slice(0, 30000)}\n\n검증 대상 파일: ${JSON.stringify(t.files)}\n\n` +
    `success_criteria: PASS only if ALL:\n${t.successCriteria}\n` +
    `- stage1 보고에 RED 증거(실패 출력)와 GREEN 증거(통과 출력)가 모두 있음 (없으면 FAIL — TDD-verbatim 규약)\n` +
    `- 수정 파일이 명시 목록 ${JSON.stringify(t.files)} 밖으로 나가지 않음`,
    {
      agentType: 'review-strict',
      label: `verify:${t.title}`,
      phase: 'Verify',
      ...(t.worktree ? { isolation: 'worktree' } : {}),
    }
  )
)
const flat = results.filter(Boolean)
log(`rpi-implement: ${flat.length}/${args.length} task 파이프라인 완료`)
return { tasks: args.map((t, i) => ({ title: t.title, verdict: results[i] ? String(results[i]).slice(0, 2000) : 'DROPPED(stage 오류)' })) }
