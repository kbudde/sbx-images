# Asking the user for evidence

The user is not only the reporter — they are the only person with hands on the
affected machine. This skill's job is to get their evidence **early and often**,
not to reconstruct their environment from documentation.

## Why this file exists

The session that prompted it ran **206 assistant turns to 17 user turns**. Twelve
of those seventeen user turns were the user *volunteering* command output or
correcting a wrong diagnosis — evidence the agent never asked for. The agent
researched alone for hours, published three wrong causes in sequence, and the
answer arrived only when the user volunteered *"btw. did you check open github
issues?"*

The cost is in the arithmetic: each wrong diagnosis was a full research pass,
and each was killed by a single command the user could have run in the first ten
minutes.

## Ask for evidence, do not interrogate

There are two different things, and only one of them is discouraged:

| Asking | Verdict |
|---|---|
| "Tell me more about the problem / what exactly did you mean?" | Discouraged. This shifts the work of describing the bug onto the user and usually does not change which cause you investigate. |
| "Run this command and paste the output." | **Default.** This is the highest-yield move available, and it is under-used. |

The skill's earlier wording ("Ask one question… do not interrogate the user
before doing any work") was read as *do not ask*, and produced an agent that
guessed instead of asking. Ask for **artifacts**, freely, as many times as the
diagnosis moves.

## The pattern

Every evidence request should be copy-pasteable and should say what it decides.
Do not ask for "the logs" — ask for the one line that separates two hypotheses.

```text
I have two candidate causes and this settles which:

  <exact command>

Please paste the output — I need the `reason=` / status line, not a summary.
```

Three properties worth keeping:

- **One command, or a short block.** A request the user has to adapt is a
  request they will answer vaguely.
- **Name the field you need.** "Paste the output" invites a paraphrase; "the
  line containing `reason=`" gets the evidence.
- **Say what it would prove.** It tells the user the ask is not busywork, and it
  commits you to a falsifiable claim.

## Ask early, and re-ask when the diagnosis moves

The rhythm is: form a hypothesis → ask for the one artifact that would kill or
confirm it → update the page → repeat. Do not spend a research pass confirming
something the user can settle in one command.

Two failure modes to avoid, both observed:

- **Silence.** Long autonomous research stretches leave the user unable to help
  and unable to tell whether progress is being made.
- **Late asking.** Asking for the decisive artifact *after* publishing a cause
  means the cause was never load-bearing. Ask before, not after.

## Where the evidence usually lives

Adapt to the reported tool; these are the common ones.

**The tool's own logs.** Most CLIs write somewhere discoverable, and most have a
verbose or JSON mode. Prefer the structured one — it survives the user's
paraphrasing:

```bash
<tool> <failing-command> --json 2>&1 | tail -40
<tool> <failing-command> -vvv 2>&1 | tail -40
```

**A running service or daemon.** Its own status endpoint, then the platform's
log collector:

```bash
<tool> status --json          # or: health, doctor, diag
journalctl --user -u <unit> -n 200 --no-pager     # systemd
tail -200 ~/.local/state/<tool>/log/*.log         # file-based
```

**A container.** Logs and state are separable; ask for both when state is
suspect:

```bash
docker logs --tail 200 <container>
docker exec <container> <tool> status --json
docker exec <container> printenv | grep -i <PREFIX>   # never dump the whole env to a public channel
```

For `sbx` / Docker Sandboxes specifically, the workload's own tool is reachable
with `sbx exec <sandbox> -- <command>`, and lifecycle-hook output usually lands
in the sandbox's process log rather than the host's.

**A GUI or web client.** Ask for the browser console and the network response
body — the UI's error text is usually a rewritten summary:

```text
Open the browser devtools → Network → reproduce → paste the failing
response body and status code.
```

**A config-driven failure.** Ask for the *effective* value, not the file. Merged
defaults, environment overrides and generated catalogs mean the file is not what
the program read:

```bash
<tool> config get <key>          # effective
<tool> config list --json | jq <path>
```

## What not to ask for

- **Secrets.** Never request a key, token, or full environment dump. Ask for a
  presence check instead: `printenv | grep -c <PREFIX>`, or the tool's own
  masked view (`effective=env:pr…ed`).
- **The whole log.** Ask for the tail, or the matching line. A 5 MB paste costs
  context and buries the signal.
- **Anything already in the transcript.** Re-read the thread before asking; the
  user has often pasted it already.
- **Permission to proceed.** Asking to ask is a wasted turn.

## Recording what you learned

When the user's evidence settles a hypothesis, the page's `# Evidence` section
should cite it as what it is: an artifact the user produced, with the command
that produced it. That is what makes the finding reproducible for the next
session — and it credits the person who actually did the work.
