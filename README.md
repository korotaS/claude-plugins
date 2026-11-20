# claude-plugins

A personal Claude Code plugin marketplace. One plugin so far:

- **autonomous-pr**: take one feature or fix from a request to a reviewed,
  CI-tested PR with signed commits. Manual only, never triggers by itself.
  Commits go ahead without asking; push and PR actions wait for approval.

## Install

The marketplace is this repo, https://github.com/korotaS/claude-plugins. On every machine:

```bash
claude plugin marketplace add korotaS/claude-plugins
claude plugin install autonomous-pr@korotas
```

Or from inside a session: `/plugin marketplace add korotaS/claude-plugins`,
then `/plugin install autonomous-pr@korotas`.

Invoke it as `/autonomous-pr:autonomous-pr <what to build>`. Plugin skills are
namespaced, so typing `/autonomous-pr` in the slash menu finds it.

Update everywhere after a change here: bump `version` in
`plugins/autonomous-pr/.claude-plugin/plugin.json` and in
`.claude-plugin/marketplace.json`, push, then on each machine:

```bash
claude plugin marketplace update korotas
claude plugin update autonomous-pr@korotas
```

### Where each surface reads skills from

| surface | reads | how to get autonomous-pr there |
| --- | --- | --- |
| Claude Code CLI or desktop Code tab, **local** session on your laptop | the laptop's `~/.claude` | the two commands above, run on the laptop |
| Desktop Code tab connected to a **remote server** (SSH), or the CLI on that server | the server's `~/.claude` | the two commands above, run on that server |
| **Cloud** sessions (claude.ai/code) | the repo being worked on | add the snippet below to that repo's `.claude/settings.json` |
| claude.ai **chat** | uploaded skills | not supported: no git, Docker or `gh` there, and the upload format refuses `disable-model-invocation` |

Cloud sessions, per repo (`.claude/settings.json`, committed):

```json
{
  "extraKnownMarketplaces": {
    "korotas": {"source": {"source": "github", "repo": "korotaS/claude-plugins"}}
  },
  "enabledPlugins": {"autonomous-pr@korotas": true}
}
```

The marketplace repo is public, so cloud sessions can read it.

Without GitHub, copy the folder by hand (it lands as a personal skill,
invoked as plain `/autonomous-pr`):

```bash
rsync -a plugins/autonomous-pr/skills/autonomous-pr/ <host>:~/.claude/skills/autonomous-pr/
```

Do not install both the plugin and the personal copy on one machine, or the
slash menu shows the skill twice.

## Tests

`plugins/autonomous-pr/evals/` holds three dry-run cases against a toy Cython
repo. Run them with `claude plugin eval plugins/autonomous-pr --scaffold --allow-tools Write,Edit,Bash`
(real, billed model runs).
