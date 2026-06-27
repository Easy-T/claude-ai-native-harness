# Deny Patterns — {{PROJECT_NAME}}

> 이 파일 = 프로젝트의 **전체 금지 정책**(사람/AI가 읽는 SSOT). 형식: `- ❌ ` 마커로 시작.
> 환경(dev/staging/prod) 구분 없음 — 모든 환경에 동일 적용.
>
> **⚠ 강제 범위(정직한 공개 — 이 목록 전부가 자동 차단되는 것이 아님):**
> - **하드 차단(opencode `opencode.json` `permission.bash` deny, 네이티브 L3):** 아래 중 **bash-명령 형태의
>   보편 파괴 명령만** — `rm -rf`/`rm -fr`(및 `~`·`/` 변종)·`npm/yarn/pnpm publish`·`git push --force `(인자형;
>   안전한 `--force-with-lease`는 미차단). 이건 **best-effort 가드(speed-bump)이지 샌드박스가 아님**: opencode
>   glob 매칭은 셸-인지가 아니라, 플래그 순서·env 프리픽스(`git -c x push --force`)·이색 띄어쓰기 변종은 우회 가능.
> - **문서-only(자동 강제 X, 리뷰·규율 + 전역 하네스 게이트로 적용):** SQL(`DROP TABLE`·`TRUNCATE`·…)·prod 직접
>   접근(`ssh prod`·`kubectl exec`·`psql -h prod-`)·컨텍스트 의존 git(`reset --hard` 공유브랜치·`--no-verify`)·
>   머지된 마이그레이션 수정 — 이들은 bash-패턴으로 환원 불가하여 정적 게이트의 사정거리 **밖**.
> - **새 deny 추가 시:** 이 문서에 `- ❌ `로 기록(정책). bash-명령 형태면 `opencode.json` `permission.bash`에도
>   추가해야 **하드 차단**됨(아니면 advisory). CC의 동적 파싱 훅 `pre-commit-deny.sh`를 정적 permission으로 대체한 결과.

## Schema / DB
- ❌ DROP TABLE
- ❌ TRUNCATE
- ❌ DELETE FROM (without WHERE)
- ❌ ALTER TABLE (use migration file instead)

## Migrations
- ❌ 머지된 마이그레이션 파일 수정 (always create new migration)

## Git
- ❌ git push --force origin main
- ❌ git push --force origin master
- ❌ git reset --hard (공유 브랜치)
- ❌ --no-verify

## Filesystem
- ❌ rm -rf /
- ❌ rm -rf ~
- ❌ rm -rf *

## Production Direct Access (모든 직접 접근 금지)
- ❌ ssh prod
- ❌ kubectl exec (prod context)
- ❌ psql -h prod-
- ❌ 운영 자격증명을 코드/커밋에 포함

## (허용) — 다음은 deny 아님
- ✅ npm install / pip install / cargo build (dev에서 자유)
- ✅ git push (force 아닌 경우)
- ✅ 마이그레이션 파일 신규 생성

## Past Incidents (이 프로젝트 사고 기록)
{{#INCIDENTS}}
- {{date}}: {{description}} → 그래서 `{{rule}}`
{{/INCIDENTS}}

(부트스트랩 시 INCIDENTS는 비어 있음. 사고가 발생할 때마다 한 줄 추가.)
