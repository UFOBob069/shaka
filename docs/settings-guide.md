# Choose your settings

Give Shaka a task:

```text
$shaka <task or issue link>
```

If the project has no Shaka setup, the agent asks whether to prepare individual
or team settings. It finds your existing checks, explains the AI review choices,
and defaults to Ask. The [settings reference](settings.md) owns the options and defaults.

## Use individual or team settings

**Individual setup** lets you try Shaka before your team adopts it. Your choices
stay in your local copy of a repository without shared Shaka settings, outside commits.
To choose it upfront:

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

Individual settings support reviewer choices, writing limits, opening instructions,
and WIP preferences. Custom code-review instructions and decision-checkpoint settings
still use the shared source or defaults; [#481](https://github.com/shakacode/shaka/issues/481)
tracks making all supported settings configurable individually.
See [current experience and recovery limits](expected-experience.md#individual-setup).

For shared team settings:

```text
$shaka Set up Shaka for this repository.
```

The agent opens a settings PR for you to review. Its choices become the team's
defaults after it merges into the default branch. Individual settings do not
override team settings.

[Merged #426](https://github.com/shakacode/shaka/pull/426) lets you
[try a settings PR on one task](settings.md#preview-settings-before-adopting-them)
before adoption. The PR keeps the experiment visible.

## Choose a merge policy

With **Ask**, review the ready PR, then merge it yourself or tell the agent to merge.
With **Auto**, the agent merges after required checks, reviews, and approvals.
Some changes still need your decision.

```text
$shaka <task or issue link>
Use merge policy Auto. Go.
```

`Go` starts work; it does not authorize merging. See
[merge choices](working-with-shaka.md#choose-a-merge-policy).

## Choose AI reviewers

A separate AI session reviews the code before publication. Choose reviewers you can
access through their tools or API credentials:

```text
$shaka Prefer Claude for code review.
```

Shaka first prefers a provider that did not implement the change, then follows your
configured order. The list supplies choices; the [reviewer count](settings.md#reviewlocal_review_count)
determines how many run. Reviews can run concurrently. Additional reviewers add
cost and may increase elapsed time. A fresh context does not guarantee a better review.

For custom instructions:

```text
$shaka Focus code reviews on compatibility.
```

The agent starts from Shaka's defaults when preparing replacement instructions.
Use one prompt for all local reviewers or one for a particular reviewer. Team
instructions come from the default branch; individual support is tracked in
[#481](https://github.com/shakacode/shaka/issues/481). See
[custom review instructions](settings.md#reviewprompt_file).

## Keep PR explanations useful

```text
$shaka Keep PR descriptions under 200 words.
```

Shaka checks [writing limits](settings.md#prose_limits) before publishing descriptions
and code walkthroughs, including with individual settings. Recommendations and
review replies follow agent instructions; code does not check their length.

An [opening check](settings.md#opening_check) advises whether the first sentence
leads with what improves for the reader. It does not verify the whole description.
[Merged #425](https://github.com/shakacode/shaka/pull/425) added independent opening
reviewer choices and a way to disable the check completely after #420.
Both team and individual settings support these options.

## Decide what happens next

Shaka recommends what to do next at a
[decision checkpoint](pr-verification.md#decision-checkpoint) and records the owner's
choice for later. See that guide for the terms and current report labels.
Individual checkpoint settings are part of [#481](https://github.com/shakacode/shaka/issues/481).

## Resume unfinished work

**WIP Details** records the chat locator, checkout path, state, and next action.
A locator helps you resume the owning chat when your host can reach it.
Currently, [the location setting](settings.md#wipinclude_locations) hides both
the locator and path together. [#482](https://github.com/shakacode/shaka/issues/482)
tracks keeping locators while independently controlling checkout-path visibility.
