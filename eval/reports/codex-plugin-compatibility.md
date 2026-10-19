# Codex plugin compatibility trial

Native installation and marketplace refresh work with Shaka's existing skill.
An update removes the helper path an active Shaka chat saved. Keep this package
experimental until helper lifetime, runtime selection, and installation identity
have a compatible design. This PR records the trial; it does not enable a
marketplace in consumer projects or change the shipped workflow.

## Reproduce

From the repository root, with Ruby 3.4+, Git, and a Codex CLI supporting
`plugin add`, `plugin marketplace upgrade`, and `debug prompt-input`:

```sh
ruby eval/bin/codex-plugin-trial > /tmp/shaka-plugin-trial.json
```

The runner builds a disposable Git marketplace and empty Codex profile. Git's
`insteadOf` rewrites an example HTTPS URL to that local repository. Codex performs
its actual Git snapshot, installation, refresh, and prompt-catalog operations;
network transport and GitHub authentication are not tested. Each child command
has a 30-second deadline. The temporary package, profile, and Git configuration
are removed when the run ends. No model is invoked.

The package copies only the Shaka skill using the existing installer tree copier.
Other distributed guides and dependencies come from the gem's inventory. It adds
a portable manifest and a trial icon. Skill hashes include contents and normalized
permissions; both installed versions matched the source. No workflow instructions
were rewritten. The predecessor's manifest and manifest tests were inspected;
this trial adapts its thin packaging approach without its policy validator.

## Observations

Run on October 15, 2026, Pacific/Honolulu, using Codex CLI 0.162.1 and Ruby 3.4.6.
The Shaka input was `3c670de809d9da6f1900266726672ac512214853`; only trial files
were added to that tree. [Captured results](codex-plugin-compatibility.json)
contain the machine-readable observations.

| Probe | Result |
| --- | --- |
| Fresh installation | Native CLI installed portable package 0.1.0 in the isolated cache. |
| Skill discovery | Prompt input listed `shaka:shaka`; the existing bare `shaka` skill also remained visible. |
| Helper execution | Installed helper rendered the validated workflow, including with package files made read-only. |
| Git marketplace update | Committed package 0.1.1, upgraded the marketplace, and listed installed plugins. Codex activated 0.1.1 and copied its new marker file. |
| Skill preservation | Both installed skill trees matched the source hash; updated helper rendered the workflow. |
| Active-chat helper | The 0.1.0 helper no longer existed after refresh and plugin listing. |
| Installation/update identity | Doctor reported `uninstalled`; update-check recommended the official installer. Workflow identity reported the release with commit unknown. |
| Project Ruby | A sentinel interpreter on PATH intercepted helper launch. An explicit `SHAKA_RUBY` pointing at Ruby 3.4.6 restored execution. This tests dispatch, not an actual older Ruby. |

## Decision and limits

Proceed with retaining this compatibility evidence; defer public distribution.
The smallest useful next design must preserve the saved helper for an active chat,
give a plugin installation appropriate identity and update guidance, and resolve a
compatible Ruby independently of the project. A second workflow, hooks, and an MCP
server are unnecessary for this trial. No runtime remedy is implemented here.

This is a fresh Codex profile on an already configured machine, not a clean OS.
Existing user skills were visible. Desktop UI installation, the onboarding button,
public submission, remote downloads, interrupted updates, and completion of a real
PR by a newly onboarded user remain untested. Setup time, interventions, adoption,
and token savings are unknown. A successful probe process means observations were
collected; its JSON can still contain compatibility failures.
If a command or cache probe fails, the runner emits its earlier observations and
`trial_error`, then exits nonzero. The update probe uses the observed 0.162.1 cache
layout; a later layout change is a runner error requiring investigation, not
evidence that Shaka itself regressed.

The portable manifest, onboarding field, and local-executor declaration follow
[OpenAI packaging guidance](https://developers.openai.com/plugins/build/plugins)
and [desktop-only guidance](https://developers.openai.com/plugins/deploy/desktop-only).
Their presence does not establish public-directory approval or desktop UI behavior.
