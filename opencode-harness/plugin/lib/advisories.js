// opencode-harness/plugin/lib/advisories.js
// Pure selector for tool.execute.after advisories (spec §16.A). Ported from the CC
// surface-constitution.sh (§5/§8) + surface_bypass (RPI). NO side effects — governance.js
// owns dedup + the model-visible output append. Advisories reach the model only on NATIVE
// tools (opencode session/tools.ts returns the same `output` object); MCP tools are excluded.
import { normalizePath } from "./code-exts.js";

// Tools whose tool.execute.after output-mutation reaches the model (native, not MCP).
export const NATIVE_TOOLS = new Set(["bash", "edit", "write", "apply_patch", "read"]);
// Tools that actually mutate state — eligible for the RPI-bypass surface.
const WRITE_TOOLS = new Set(["bash", "edit", "write", "apply_patch"]);
// Tools that write a FILE (carry filePath) — eligible for the §5/§8 file advisories.
const FILE_WRITE_TOOLS = new Set(["edit", "write", "apply_patch"]);

// §5 trigger: dependency manifests (surface-constitution.sh:19, basename match).
export const MANIFEST_RE = /(?:^|\/)(package\.json|go\.mod|requirements\.txt|pyproject\.toml|Cargo\.toml|pom\.xml|build\.gradle(?:\.kts)?|Gemfile|composer\.json|pubspec\.yaml)$|\.csproj$/;
// §8 trigger: UI extensions (surface-constitution.sh:31).
export const UI_RE = /\.(tsx|jsx|vue|svelte|css|scss|sass|less|styl)$/i;

const TEXT = {
  "rpi-bypass": "⚠ RPI 게이트 우회 (RPI_SKIP 설정) — 이 도구 호출에 RPI 사이클이 미적용입니다. 의도된 우회인지 확인하세요. (advisory · 1세션 1회 · 차단 아님)",
  adr: "[§5 ADR] 의존성 매니페스트 수정 감지 — 아키텍처 영향(의존성 추가/삭제)이면 docs/ai-context/architecture.md 에 ADR 을 append-only 로 작성하세요. (advisory · 1세션 1회 · 차단 아님)",
  ui: "[§8 UI] UI/UX 시각 파일 수정 감지 — ui-design 스킬을 skill 도구로 호출하세요 (design.md 주입 + Anti-Slop Checklist 검증). (advisory · 1세션 1회 · 차단 아님)",
};

// Returns the advisories that apply to this call. Pure; caller dedups per session.
export function advisoriesFor({ tool, args, env } = {}) {
  args = args || {};
  env = env || {};
  const t = String(tool || "").toLowerCase();
  const out = [];
  if (env.RPI_SKIP && WRITE_TOOLS.has(t)) out.push({ kind: "rpi-bypass", text: TEXT["rpi-bypass"] });
  if (FILE_WRITE_TOOLS.has(t)) {
    const fp = normalizePath(args.filePath || args.notebookPath || "");
    if (fp) {
      if (MANIFEST_RE.test(fp)) out.push({ kind: "adr", text: TEXT.adr });
      if (UI_RE.test(fp)) out.push({ kind: "ui", text: TEXT.ui });
    }
  }
  return out;
}
