{
  "permissions": {
    "allow": [
      {{STACK_ALLOW_LIST}}
    ],
    "deny": [
      "Bash(rm -rf*)",
      "Bash(git push --force*)",
      "Bash(npm publish*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/pre-commit-deny.sh" }
        ]
      }
    ]
  }
}
