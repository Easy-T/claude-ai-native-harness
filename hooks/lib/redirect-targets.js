// hooks/lib/redirect-targets.js
// 셸로 코드 파일을 작성하는 패턴 탐지 (enforce-rpi-bash 가 사용).
// 입력: env CMD = 셸 명령 문자열, env CODE_EXT_REGEX = 코드 확장자 JS 정규식 source (_common.sh code_ext_regex).
// 출력: 리다이렉션(>/>>)·tee 의 첫 '코드 확장자' 대상 (/dev/null 제외). 없으면 빈 문자열.
const cmd = process.env.CMD || "";
const codeExt = new RegExp(process.env.CODE_EXT_REGEX || "\\.(sh|py|js)$", "i");
const targets = [];
// > file | >> file | tee [-a] file  (>&fd, >&-, 2> 등 fd 리다이렉션은 코드 확장자가 아니라 자동 제외)
const re = /(?:>>?|\btee\s+(?:-a\s+)?)\s*("?)([^\s">|;&()]+)\1/g;
let m;
while ((m = re.exec(cmd)) !== null) targets.push(m[2]);
const hit = targets.find(p => codeExt.test(p) && !/^\/dev\/null$/.test(p));
if (hit) process.stdout.write(hit);
