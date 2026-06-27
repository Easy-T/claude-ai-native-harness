{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "rm -fr *": "deny",
      "rm -r -f *": "deny",
      "rm -rfv *": "deny",
      "rm -rf ~*": "deny",
      "rm -fr ~*": "deny",
      "rm -rf /*": "deny",
      "git push --force *": "deny",
      "git push -f *": "deny",
      "npm publish*": "deny",
      "yarn publish*": "deny",
      "pnpm publish*": "deny"
    },
    "webfetch": "allow"
  }
}
