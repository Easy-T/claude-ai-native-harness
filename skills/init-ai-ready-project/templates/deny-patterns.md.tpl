# Deny Patterns — {{PROJECT_NAME}}

> 절대 금지. .claude/hooks/pre-commit-deny.sh가 이 파일을 파싱.
> 형식 규약: 차단 항목은 반드시 `- ❌ ` 마커로 시작.
> 환경(dev/staging/prod) 구분 없음 — 모든 환경에 동일 적용.

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
