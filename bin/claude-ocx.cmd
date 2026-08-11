@echo off
REM claude-ocx.cmd - launcher for Orca terminals (PowerShell/cmd default shell).
REM PowerShell resolves bare `bash` to the WSL launcher (Bash/Service/E_UNEXPECTED),
REM so call Git Bash by absolute path. Use a login shell (-l) so PATH includes
REM coreutils; the npm `claude` shim needs sed/dirname/uname.
REM Model selection: set OCX_MODEL before launching (default gpt-5.6-sol).
"C:\Program Files\Git\bin\bash.exe" -lc "exec ~/.claude/bin/claude-ocx \"$@\"" claude-ocx %*
