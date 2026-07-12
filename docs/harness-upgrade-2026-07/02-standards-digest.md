# 02 — 2026.07 외부표준 다이제스트

> 원천: 리서치 에이전트 6축(R-A Anthropic / R-B 타 벤더 / R-C 프론티어 실전 / R-D 방법론·안전 / R-E 관측·메모리·컨텍스트 / R-F 최신 10주 스윕), 2026-07-13 수행. 규율: 주장마다 (출처, 게시일) + [FACT]=출처 직접 확인 / [INFERENCE]=종합 해석. 2026-06 감사가 기매핑한 소스(Anthropic context-engineering·Cognition traces·Kiro·12-factor·Ralph·SWE-agent ACI·Hamel)는 **델타만**.
> 검증 실패·상충은 §9에 명시. 이 문서는 스냅샷 — 표준은 움직인다(특히 OTel GenAI는 Development 상태).

## 1. Anthropic 플랫폼 (R-A)

### Claude Code 5-7월 릴리스 중 하네스-관련
- Opus 4.8 + Claude Code v2.1.154 (2026-05-28): effort 4단계·fast mode·**dynamic workflows**(계획→수백 병렬 서브에이전트→검증; v2.1.160에서 트리거 키워드 `ultracode`로 개명, 06-02 GA) [FACT] (code.claude.com/docs/en/changelog; anthropic.com/news/claude-opus-4-8, 2026-05-28)
- 서브에이전트: 5단계 중첩(v2.1.172, 06-10) · **background-by-default**(v2.1.198, 07-01) + worktree 작업 자동 commit/push/draft-PR · 백그라운드 권한 프롬프트 메인 세션 표면화(v2.1.186) [FACT] (changelog)
- Agent teams(실험, env 게이트): v2.1.178(06-15)이 TeamCreate/TeamDelete **제거**(breaking) — 암묵 팀 + `Agent(name=...)` 스폰; `/resume`·rewind가 팀원 미복원 [FACT] (code.claude.com/docs/en/agent-teams)
- 권한: 파라미터-인지 규칙 `Tool(param:value)`(v2.1.178) · **기본 권한 모드 Auto→Manual**(v2.1.200, 07-03) · `sandbox.credentials`(자격증명 읽기 차단, v2.1.187) · auto 모드 파괴 명령 방어 강화 + transcript 변조 차단(v2.1.205) [FACT] (changelog; techtimes.com 2026-07-07)
- Hooks: Stop/SubagentStop이 `additionalContext` 주입 가능(v2.1.163, 06-04) · 플러그인 hook 셸 보간 인젝션 픽스(v2.1.207, 07-11) [FACT] (changelog)
- 메모리: auto memory `MEMORY.md` 인덱스는 시작 시 첫 200줄/25KB만 로드; 공식 문서가 "메모리는 컨텍스트이지 강제 설정이 아님 — 차단은 PreToolUse hook으로"를 명시 [FACT] (code.claude.com/docs/en/memory)
- `/insights`(2월): 30일 세션 마이닝 → CLAUDE.md 규칙/skill/hook 제안; **Dreaming**(research preview, 05-06): 야간 세션 리뷰로 메모리 큐레이션(인간 리뷰 옵션) [FACT] (claude.com/blog/new-in-claude-managed-agents; simonwillison.net 2026-05-06)
- Vault(Managed Agents, 06-09): 샌드박스엔 placeholder 시크릿만, 실키는 네트워크 경계에서 허용 도메인에만 부착 — 프롬프트 인젝션이 모델 컨텍스트에서 탈취 불가 [FACT] (claude.com/blog/whats-new-in-claude-managed-agents)

### 엔지니어링 블로그 (기준선 이후 델타)
- 신규 context-engineering 포스트 없음(2025-09-29 것이 여전히 canonical) [FACT] (anthropic.com/engineering 인덱스)
- "How we contain Claude"(2026-05-28): 격리=행동 감시가 아닌 **접근 경계**(gVisor/Seatbelt·Bubblewrap/풀 VM); **사용자가 권한 프롬프트의 ~93% 승인(주의 감소)**; auto 분류기는 위험 명령 ~17% 놓침 → 심층방어이지 대체 아님; 자체 egress 프록시가 최약 계층이었고 표준 프리미티브는 견딤 [FACT] (anthropic.com/engineering/how-we-contain-claude)
- "Scaling Managed Agents"(2026-04-08): session(내구 이벤트 이력)/harness(오케스트레이션 루프)/sandbox(실행) 분리; **"하네스는 모델이 못하는 것에 대한 가정을 인코딩하며 그 가정은 낡는다"**(Sonnet 4.5용 컨텍스트 리셋이 Opus 4.5에선 불필요했던 사례) [FACT] (anthropic.com/engineering/managed-agents)
- "Harness design for long-running apps"(2026-03-24): planner/generator/**evaluator** 삼각; **fresh-context 외부 평가가 자기리뷰를 이김**(에이전트는 자기 작업 과대평가); 명시적 pass/fail 임계 + few-shot 캘리브레이션; 새 모델 도착 시 하네스 구성요소를 하나씩 벗겨 측정 [FACT] (anthropic.com/engineering/harness-design-long-running-apps)

### Claude 5 패밀리 하네스 함의
- Fable 5/Mythos 5(06-09): 1M 기본·128K 출력·adaptive thinking 상시(끌 수 없음, effort가 제어) [FACT] (platform.claude.com docs; infoq.com 2026-06)
- **Fable 5 공식 프롬프팅 가이드**: 턴이 분→시간 단위로 실행 — 하네스를 블로킹이 아닌 비동기 체크로 재구성; **"진행 주장을 세션 tool result 대비 감사" 지시가 조작된 상태 보고를 거의 제거**; 자기비평보다 fresh-context 검증자 서브에이전트; **이전 모델용으로 쓰인 과처방 skill이 출력을 열화 — 리뷰·제거하라**; 남은 토큰 카운트다운 노출 금지(자기절단 유발) [FACT] (platform.claude.com/docs/.../prompting-claude-fable-5)
- Sonnet 5(06-30): Claude Code 기본, 네이티브 1M; 토크나이저 변경으로 동일 입력 ~1.0-1.35× 토큰 [FACT] (anthropic.com/news/claude-sonnet-5)
- v2.1.173 "모델명 정규화 — 중복 `[1m]` suffix 제거" — 이 하네스의 `[1m]` 창 워크어라운드에 직접 저촉 가능; 업그레이드마다 `/context` 재검증 필요 [FACT+INFERENCE] (changelog)

## 2. 타 벤더 (R-B)

- **OpenAI Codex**: sandbox 티어(read-only/workspace-write/danger-full) × 승인 모드에 신규 `writes` 모드(v0.144.0, 07-09); **hook/이벤트 표면 신설**(command·subagent·review 등 canonical 이벤트 타입, 07-09); AGENTS.md가 환경 변화에 반응·서브에이전트 위임 승인(v0.143.0); "world state" 롤아웃 간 환경 컨텍스트 영속(메모리 인접); `@codex review` P0/P1만 플래그, repo AGENTS.md의 Review guidelines 준수; rollout 토큰 예산이 소진 시 턴 중단 [FACT] (developers.openai.com/codex/changelog)
- **AGENTS.md 표준**: Linux Foundation 산하 Agentic AI Foundation 관리(2025-12-09~, 멤버 170+), 60k+ repo·~28 도구 채택; nearest-file 우선 [FACT] (agents.md; openai.com/index/agentic-ai-foundation)
- **반증 데이터**: ETH Zurich 연구(138 repo, arXiv 2602.11988) — **LLM-생성 컨텍스트 파일은 성공률 -3%·비용 +20%; 인간-작성도 ~+4%뿐이며 최소(<150줄)일 때만** [FACT] (marktechpost.com 2026-02-25; morphllm.com)
- **Google**: Gemini CLI → Antigravity CLI 전환(05-19 발표, 06-18 개인 제공 종료); Antigravity = Agent Manager(병렬 에이전트 관제) + **Artifacts**(task list·plan·스크린샷·브라우저 녹화 = 원시 로그 대신 리뷰 가능한 증거물) + 브라우저 에이전트 검증 + 지식베이스 [FACT] (developers.googleblog.com 2026-05-19, 2025-11-20)
- **Amazon Kiro**: GA 2025-11-17(일부 블로그의 "2026-05 GA"는 공식 기록과 상충 — 기각, §9); specs(`requirements.md` EARS/`design.md`/`tasks.md`) + **Bugfix Specs** 신설 + "Run all Tasks" 의존 그래프 동시 웨이브; steering `.kiro/steering/` — **inclusion 모드 always/fileMatch/manual/auto**; hooks pre-exit-2 차단; 07-01 Sonnet 5 기본 [FACT] (kiro.dev/docs, kiro.dev/changelog)
- **Microsoft**: Copilot coding agent — 임시 Actions env·59분 캡·**egress 방화벽 기본-on**(단 Bash 프로세스만 커버, MCP 미커버 문서화); Agent Framework 1.0 GA(04-02) + BUILD 2026 명시적 **"Agent Harness"**(파일시스템 skill 발견·plan-vs-execute·세션 메모리 파일·자동 압축·승인 미들웨어·**자동 OTel 트레이싱**); CodeAct(모델이 도구 여럿을 호출하는 파이썬 프로그램 하나를 작성, Hyperlight 마이크로VM 실행 — 52% 빠름/64% 토큰 절감, alpha) [FACT] (docs.github.com; devblogs.microsoft.com BUILD 2026)
- [INFERENCE] 통합 물결(Gemini CLI→Antigravity, Q→Kiro, AutoGen/SK→MAF) — 플랫폼 종속 config보다 **파일-기반 이식 자산(AGENTS.md·markdown skill)이 마이그레이션을 살아남는다** (R-B 종합)

## 3. 프론티어 실전 관행 (R-C)

- **Cursor**: 2.0(2025-10-29)이 리뷰+테스트를 병목으로 명명 — 네이티브 브라우저 도구(에이전트 자가 QA)·8병렬 에이전트+최선 실행 자동 평가; 로컬 sandbox(Seatbelt/Landlock+seccomp/WSL2, 02-18) — 샌드박스 에이전트가 40% 덜 멈춤; 6월: Auto-review 권한 모드(허용목록→sandbox→LLM 분류기 삼중) 기본화·Bugbot pre-push `/review`·`/automate` 반복 에이전트 [FACT] (cursor.com/blog, changelog)
- **Cognition/Devin**: "Devin이 Devin을 빌드"(02-27) — 주당 Devin PR 659 머지; **Playbooks**(성공 기준+금지 행동 명시 재사용 절차) + **Knowledge**(트리거 조건 딸린 상시 규약); 좁은 스코프 세션 + 인간은 단계가 아닌 PR 리뷰; **Auto-Fix 루프**: 리뷰 코멘트·lint·CI 실패를 체크 green까지 자동 반복; **Session Insights**: 세션 채점 후 다음 실행용 개선 프롬프트 방출 [FACT] (cognition.com/blog)
- **Factory Missions**(GA ~03월): orchestrator/worker/**validator** 3역 분리; **검증 계약을 구현 전에 정의**; **교차-프로바이더 검증**(자기 학습편향 검증 회피); computer-use 검증 워커가 실제 UI 클릭 [FACT] (factory.ai/news/missions-architecture; 05-11 발표 요약)
- **OpenAI "Harness engineering"**(02월): 엔지니어 3명·~1M LOC·5개월 1,500 PR·수기 코드 0; **~100줄 AGENTS.md는 versioned docs/로의 '지도'**(큰 AGENTS.md는 "썩는다"); 계층 아키텍처를 Codex-생성 린터+구조 테스트로 강제; 배경 에이전트가 청소 리팩토링 PR 자동 머지 [FACT] (openai.com/index/harness-engineering — 원문 403, 2차 검증)
- **Meta**: Confucius 내부 SDK(계층 작업 메모리·영속 노트·meta-agent 개선 루프, arXiv 2512.10398); 50+ 에이전트가 **컨텍스트 파일 59종 사전 계산**(조사 2일→30분, 도구 호출 -40%)(eng blog 04-06); Zuckerberg 7월 타운홀 "에이전트 진전이 기대만큼 가속되지 않았다"(2차) [FACT] (engineering.fb.com; computerworld.com)
- **Amazon 교훈**: Kiro 표준화 SVP 메모 + 주간사용 80% OKR → 게이밍 → **KiroRank 토큰 리더보드 폐쇄(05-29)** — 사용량 지표를 타깃으로 삼으면 게임된다 [FACT-2차] (mlq.ai citing Business Insider) / Sev-1 인과 주장은 [CONTESTED, §9]
- **GitHub Agent HQ**: mission control(에이전트 함대 할당·조향·추적)·custom agents `.github/agents/*.agent.md`·지정 브랜치 제한+방화벽 Actions [FACT] (github.blog)
- **Docker Fleet**(05-01): 7역할을 **SKILL.md 파일로 정의**(로컬과 CI에서 동일 skill 실행)·worker→reviewer Ralph 루프 5회 캡·인간이 머지 권한 보유 [FACT] (docker.com/blog)

## 4. 방법론·안전 (R-D)

- **12-factor agents**: 공식 개정 없음(2025-09 마지막 push); 저자 Horthy의 2026 방향 = **RPI(Research→Plan→Implement)** + "Dumb Zone"(컨텍스트 ~40% 초과 시 recall 저하, 10만 세션 분석) + Frequent Intentional Compaction [FACT] (github.com/humanlayer/12-factor-agents; LinearB Dev Interrupted 2026-02)
- **하네스=모델급 변수 정량화**: Claw-SWE-Bench(arXiv 2606.12344, 06-10) — 동일 모델에서 하네스만으로 Pass@1 19.1%→73.4%(+54.3pp); 모델 교체 효과 29.4pp ≈ 하네스 교체 27.4pp. 서베이(arXiv 2606.20683)가 하네스를 6책무(Observation/Context/Control/Action/State/Verification)로 분류 [FACT]
- 반대 극단: mini-swe-agent — bash 단일 도구 ~100줄로 SWE-bench Verified >74% — [INFERENCE] 도구 개수보다 **계약 표준화·컨텍스트 관리가 레버리지**
- **METR Time Horizon 1.1**(01-29): Opus 4.5 P50=320분; Mythos Preview **P50 ≥16h**(CI 8.5-55h, 05-08) + "16h 초과는 현 스위트로 신뢰 불가"; **80%-horizon은 50%의 약 1/5** — [INFERENCE] 무감독 자율 구간은 80%-horizon(프론티어 기준 1-3h) 이하로 슬라이스, 그 경계에 체크포인트 [FACT] (metr.org/blog, metr.org/time-horizons)
- **Eval 방법론 수렴**: Anthropic "Demystifying evals"(01-09) — 20-50 현실 과제·trajectory+최종 상태 채점·**pass^k**·judge를 인간 라벨로 정기 검증·"Read the transcripts!"; Hamel/Shankar FAQ(01-15) — error analysis 최우선·**binary Pass/Fail judge**·100+ 라벨 TPR/TNR 보정·**100% pass율은 경고 신호**; transition failure matrix [FACT] (anthropic.com/engineering; hamel.dev)
- **보안**: 프롬프트 인젝션 "아키텍처의 영구 속성일 수 있음"(06-14 평가 확산); 설계 어휘 = lethal trifecta(Willison) + **Agents Rule of Two**(Meta, 2025-10-31: 세 속성 중 ≤2만); 2026 델타 = 입력 필터 대신 **다운스트림 행동 모니터링 + reader(도구 없음)/doer(원문 미접촉) 분리** [FACT] (ai.meta.com; sophos.com; techtimes.com)
- **Anthropic sandbox-runtime(srt)**: OS 프리미티브 + 프록시 경유 도메인 화이트리스트, write·network **deny-by-default**, 내부 권한 프롬프트 84% 감소, **Windows 지원 추가** [FACT] (anthropic.com/engineering/claude-code-sandboxing; github.com/anthropic-experimental/sandbox-runtime)
- **skill/MCP 공급망**: Snyk ToxicSkills(02월) — 서드파티 마켓 스킬 3,984개 중 13.4% critical·76 확정 악성; Datadog — dynamic-context 명령은 **모델이 스킬을 보기 전에 실행**; "rug pull"(승인 후 변경)·approve-once-trust-forever 결함; NSA MCP CSI(05월) — 서명·핀·드리프트 경보 권고 [FACT] (snyk.io; securitylabs.datadoghq.com; media.defense.gov)

## 5. 관측·메모리·컨텍스트 (R-E)

- **OTel GenAI semconv**: 여전히 Development(비-stable); v1.36 전환 기준선, ~v1.41까지 워크플로 span·스트리밍 메트릭·reasoning 토큰 추가; 표준 span=`invoke_agent`/`execute_tool`/`invoke_workflow`, 핵심 속성=`gen_ai.operation.name`·`usage.input/output_tokens`·`tool.name` 등; Datadog/Honeycomb/New Relic 지원 [FACT] (opentelemetry.io/docs/specs/semconv/gen-ai; greptime.com 2026-05-09) — [INFERENCE] 지금 정렬해두면 백엔드 이식 무료
- **런 기록 실무**: 스팬별 토큰+정규화 비용·도구 args/results·컨텍스트 창 사용률·결과 verdict; **대부분의 에이전트 사고는 도구 호출 실패·컨텍스트 절단·폭주 루프이지 모델 오류가 아님**; LangSmith "문제 trace → 재생 → 회귀 eval 데이터셋 원클릭" 루프 [FACT] (braintrust.dev; blog.langchain.com; digitalapplied.com)
- **비용 거버넌스**: Uber 4개월 만에 연간 AI 예산 소진 → **월 $1,500/인/도구 캡**(06-02); $47K/11일 LangChain 루프(관측만 있고 강제 없음); DN42 사고 — 재시도마다 중복 스택 생성 $6,531(06-12 HN); 합의 = **강제는 에이전트 밖에서**(프롬프트-레벨 "$X에서 멈춰"는 실패; 게이트웨이 하드 캡 + iteration circuit breaker; `max_iterations` 기본 무한이 흔한 결함) [FACT] (techcrunch.com 2026-06-02; lantian.pub; waxell.ai; truefoundry.com)
- **메모리**: Anthropic memory tool GA — 파일 조작 + "ALWAYS VIEW YOUR MEMORY DIRECTORY… ASSUME INTERRUPTION" 자동 주입; Letta sleep-time agents(백그라운드 통합, 주 에이전트에서 편집 도구 제거); Mem0 Memory Decay는 검색-시점 재랭킹이지 eviction 아님·OSS TTL 없음 — **수명주기는 사용자 책임**; 서베이 합의 = Formation→Evolution(통합/갱신/망각)→Retrieval, **"통합 정책에 대한 침묵이 프로덕션 실패가 사는 곳"** [FACT] (platform.claude.com; docs.letta.com; mem0.ai; arXiv 2512.13564; hindsight.vectorize.io 2026-05-21)
- **메모리 = 공격 표면**: 메모리 포이즈닝이 OWASP Agentic Top-10 **ASI06**; MemoryGraft/MINJA — 심어진 "경험"이 세션 넘어 지속 [FACT] (workos.com 2026-06-09)
- **컨텍스트**: context rot 실증(Chroma 07-2025, 18모델 — 길이에 따라 비균일 저하); 1M GA에도 **실질 rot 시작 ~300-400K**(커뮤니티 실측) — 1M은 대형 코퍼스 단발 분석용이지 세션 위생 대체 아님; Anthropic context editing(도구 결과 клир): 단독 29%·메모리 도구 병용 39% 성능 향상; 4-operation 모델 **write/select/compress/isolate**(arXiv 2510.26493); 멀티에이전트 리서처가 단일 Opus 대비 +90.2%(토큰 사용이 분산의 80% 설명 — 서브에이전트는 1-2K 요약 반환) [FACT] (trychroma.com/research/context-rot; claude.com/blog/1m-context-ga; towardsdatascience.com)

## 6. 최신 10주 스윕 — 신조류 (R-F)

- **"Harness engineering" 정식 명명**: Hashimoto(02-05) 주조 → Böckeler canonical 논문(martinfowler.com, 04-02) — "Agent = Model + Harness"; feedforward(규약·spec·skill) vs feedback(테스트·린터·리뷰 에이전트); **싼 computational 센서는 상시, 비싼 inferential 센서(LLM-judge)는 선택 실행**; Osmani(04-19): "관찰된 모든 실패를 내구 메커니즘으로 전환"(규칙→AGENTS.md, 파괴 명령→차단 hook) [FACT]
- **역풍**: HumanLayer "Skill Issue"(03-12) — 투기적 하네스 복잡성 경계, 실제 실패 후에만 config 추가; ThoughtWorks Radar 34(04-15) — SDD·harness engineering "semantic diffusion" 지적, Ralph loop 등 전부 **Assess**(Adopt 아님) [FACT] (thoughtworks.com/radar)
- **Loop engineering**(6월 담론): Steinberger "에이전트를 프롬프트하지 말고 에이전트를 프롬프트하는 루프를 설계하라"(06-07); Cherny(Claude Code 리드) "내 일은 루프를 쓰는 것"; 반론 Ronacher "The Coming Loop"(06-23) — **comprehension debt**(이해 부채)와 비가독 머신-스웜 변경 경고 [FACT] (oreilly.com; lucumr.pocoo.org)
- **자기개선 하네스**: Lilian Weng 서베이(07-04, ~35편) — 하네스는 에이전트가 탐색 가능한 실행 가능 설계 공간; **안전 규범: 권한/보안 경계는 자기수정 루프 밖에**; 평가자는 held-out 테스트+trace 검사로 reward hacking 방어. Self-Harness(arXiv 2606.09498): trace에서 실패 채굴→하네스 수정 제안→**회귀-검증 통과분만 유지**(+14-21pt) [FACT] (lilianweng.github.io; arxiv.org)
- **Fleet 운영 규범 성숙**: 파일당 단일-작성자 소유·의존성 설치 직렬화·핸드오프마다 검증 게이트·인간 머지 권한(07-01 필드 리포트; Docker Fleet 05-01) [FACT] (developersdigest.tech; docker.com)
- **SDD는 거버넌스 문제로 재프레임**(06-11): 도구는 이겼고 싸움은 spec 수명주기 관리로; GitHub Spec Kit ~111k stars·버전 피닝 추가(06-16) [FACT] (medium.com/@enrico.papalini; github.com/spec-kit)
- 개인 하네스 공개 사례 다수 검색 — **verify-suite/seal-test 패턴을 공개한 개인 하네스는 미발견**(Lancini 04월·freek.dev 03월 셋업 포스트는 존재하나 자기검증 스위트 없음) [FACT-부재증거] (blog.marcolancini.it; freek.dev)

## 7. 빅테크 공통 하네스 패턴 × 우리 하네스 (종합표)

"보유"는 01-structure-map 실측 기준. ◐ = 부분 보유.

| # | 공통 패턴 (출처 예) | 우리 | 실측 근거 (01 참조) |
|---|---|---|---|
| P1 | 헌법/규칙 파일 — 짧은 '지도', 세부는 versioned docs로 (OpenAI harness-eng; ETH <150줄; Kiro steering) | **보유** | CLAUDE.md ≤200줄 seal #1 + docs/ai-context 위임. ◐: Kiro식 inclusion 모드(fileMatch/manual) 없음 — 상시 로드만 |
| P2 | spec-first 수명주기 + 승인 게이트 (Kiro specs; Cursor Plan Mode; Devin Playbooks; SDD 거버넌스) | **보유** | RPIC + durable spec/사이클 plan + Gate R/P + seal #27. 업계 대비 성숙 |
| P3 | 결정론 게이트가 루프의 정지 조건 (Devin Auto-Fix; OpenAI 생성 린터; Bugbot) | **보유** | 차단 hook 4종 + verify-setup 70 + run-all 156 + seal — 개인 하네스로는 미공개 수준(§6) |
| P4 | OS-레벨 sandbox + 권한 티어 + egress 제어 (srt; Codex 티어; Copilot 방화벽; Cursor sandbox) | **부재** | bypassPermissions + hook 토크나이저뿐(01 §6-11). srt Windows 지원 확보로 도입 장벽 하락 |
| P5 | 런 관측가능성 — 스팬별 토큰/비용/도구/verdict, mission control (OTel gen_ai; GitHub HQ; Devin Desktop) | **부재** | hook_log 로컬 파일뿐(01 §6-7). 세션/사이클 run-log·게이트 발화 통계 없음 |
| P6 | 하네스 자체의 eval 루프 (Devin Session Insights; Google A/B; Self-Harness 회귀-검증) | ◐ | seal-regression·failopen-surface 메타검증은 보유(업계 희귀); 세션-레벨 인사이트 추출(/insights 등) 미사용, 20-50 과제 행동 회귀 스위트 없음 |
| P7 | 메모리 — 큐레이션+수명주기(통합/decay)+포이즈닝 방어 (memory tool; Letta sleep-time; ASI06) | ◐ | MEMORY.md 큐레이션은 우수; 통합/프루닝 정책·쓰기 리뷰 부재(01 §6-9) |
| P8 | 멀티에이전트 — orchestrator/worker/validator 분리 + **교차모델 검증자** (Factory; Confucius; 함대 규범) | ◐ | wrapper 3종 역할 분리는 보유; 전원 동일 모델 패밀리(01 §6-6) — 교차 검증자 부재; 파일 단일-작성자 규범 비명문 |
| P9 | 자가 QA — 브라우저/computer-use로 실물 구동 검증 (Cursor 브라우저; Factory validation worker; Antigravity Artifacts) | ◐ | ui-design §3④ Playwright 실측 규정은 보유; closeout 일반 절차엔 "실물 구동" 미포함, 증거물(artifact) 규약 없음 |
| P10 | 인간 체크포인트 — 단계가 아닌 PR/머지에; 사용량 지표 게이밍 경계 (Cognition; Amazon 교훈) | **보유** | closeout-pr-cycle 머지 하드게이트 + 명시 위임 시만 auto. 게이팅은 결과 품질(green CI) 기준 — Amazon 반면교사와 정합 |
| P11 | 비용/반복 예산 — 에이전트 **밖** 강제 (Uber 캡; Cloudflare 한도; circuit breaker) | **부재** | goal-loop에 iteration/토큰 ceiling 없음(01 §6-8), 프롬프트-레벨 지시뿐 |
| P12 | 스캐폴드 노화 관리 — 모델 업그레이드 시 하네스 가정 벗겨 재측정 (Anthropic managed-agents; Fable 5 가이드) | **부재** | 누적 단방향(01 §6-10); 과처방 skill이 Fable 5 출력을 열화한다는 공식 가이드와 직접 충돌 |
| P13 | 공급망 — skill/플러그인 서명·핀·드리프트 경보 (NSA; Microsoft; ToxicSkills) | ◐ | superpowers 등 플러그인 버전 캐시는 있으나 업데이트 diff 리뷰·핀 규약 없음 |
| P14 | 증거물-우선 검증 — 로그가 아닌 리뷰 가능한 artifact (Antigravity Artifacts; Kiro property-testing) | ◐ | plan 체크박스+검증 커맨드 출력이 사실상 artifact; 사이클당 내구 증거물 규약은 없음 |

## 8. [INFERENCE] 이 하네스에의 함의 (요약 — 갭 도출은 04)

1. 우리의 hook-기반 결정론 강제는 이제 **공식 교리**(Anthropic 문서가 "메모리·CLAUDE.md는 컨텍스트, 강제는 hook" 명시) — 방향 유지, 게이트를 프롬프트로 옮기지 말 것.
2. 최대 격차는 P4(sandbox)·P5(관측)·P11(예산) — 셋 다 "강제는 에이전트 밖" 원칙의 미충족 표면이고, 무인 goal-loop 확대와 정면 긴장.
3. P12(스캐폴드 노화)는 Fable 5 공식 가이드와의 직접 충돌이라 긴급 — 과처방 skill 텍스트가 현 모델 출력을 열화 중일 수 있음.
4. 검증자 교차-모델 분리(P8)는 자기채점 편향의 구조 해소책 — ccs 멀티모델 라우팅이 이미 있어 도입 비용 낮음.
5. ETH·HumanLayer·ThoughtWorks 역풍 공통: **모든 신규 규칙은 실제 실패에 추적 가능해야**(5-Whys 등록 절차와 정합) — 이번 업그레이드도 투기적 추가 금지.

## 9. 상충·검증 실패 기록 (정직성)

- Kiro GA: 공식 2025-11-17 (kiro.dev) vs 일부 블로그 "2026-05 GA" — **공식 채택, 블로그 기각**.
- Amazon Kiro 의무화↔Sev-1 인과: 2차 블로그 순환 주장, Amazon 반박 — **[CONTESTED] 미채택**.
- $47K LangChain 사고: 예산-도구 벤더 블로그 단일 소스 — 방향성 증거로만 사용.
- OpenAI harness-engineering 원문 403 — 2차 요약 2건으로 검증.
- OTel 2026 블로그 게시일 미회수; Antigravity 공식 문서 JS-렌더로 미접근(공식 블로그+3자 가이드 표기).
- METR 대시보드 점값 차트-렌더로 직접 추출 실패 — 일부 수치 2차 출처.
- R-A/R-D 에이전트 간 "contain Claude" 게시일 표기 상이(05-25 vs 05-28) — 크로스체크 불가, 5월 하순으로만 확정.
