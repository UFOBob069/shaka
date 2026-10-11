# Choose your settings

Tell your agent how you want to work. It can prepare the configuration for you:

> $shaka Set up Shaka for this repository. Find its test and lint commands,
> explain the AI review choices, and keep merge policy Ask.

Start with the choices below. The [settings reference](settings.md) has the exact
options, defaults, and advanced behavior.

## Try it individually or set it up for your team

An **individual trial** lets you try Shaka before your team adopts it. It works
in a repository without shared Shaka settings. Your choices stay in your local
copy of the repository and are kept out of commits:

> $shaka Set up Shaka just for me in this repository. Keep the settings out of
> my commits and use merge policy Ask.

You can choose AI reviewers and adjust how Shaka writes PR descriptions. See
[what individual trials currently support](expected-experience.md#individual-trials-available-tools-incomplete-guided-experience)
for the remaining real-use verification gaps.

Use [shared repository setup](configure-repository.md) when the team wants the
same configuration. The agent opens a settings PR for you to review. Those
choices take effect after that PR merges into the default branch.

## Choose a merge policy

With **Ask**, you review the ready PR and decide when to merge. With **Auto**, the
agent merges when the required checks, reviews, and approvals are satisfied.
You can choose the policy for one task:

> $shaka Fix this issue. Use merge policy Ask.

See [merge choices](working-with-shaka.md#choose-a-merge-policy) for examples and
[`merge.preference`](settings.md#mergepreference) for the configuration.

## Choose AI reviewers

Shaka asks a separate AI session to review the code before publishing it. Choose
the provider, model, and thinking effort for these local reviews. Each provider
needs its command-line tool installed and signed in on your machine:

> Configure local AI reviews to try Claude first, then Codex. Use medium effort.

You can request more than one AI reviewer. Each additional review adds time and
cost. The PR records the review models and available usage for each commit.

See [reviewer choices](settings.md#reviewlocal_review_agents),
[reviewer setup](settings.md#add-a-second-reviewer), and
[multiple reviewers](settings.md#reviewlocal_review_count).

You can also choose what local reviewers look for. For shared team settings, ask:

> Create a review prompt that emphasizes regressions, missing tests, and
> compatibility with existing installations. Start from Shaka's default instructions.

Use one prompt for all local reviewers or give a particular reviewer its own.
The prompt takes effect after its settings PR merges. See
[custom review prompts](settings.md#reviewprompt_file) for the options and limits.

## Keep PR explanations useful

Ask the agent to keep PR descriptions, code walkthroughs, recommendations, and
review replies clear and concise. For example:

> Keep PR descriptions under 200 words. Use short sentences in walkthroughs and
> review replies. Link to the code instead of repeating implementation details.

Shaka enforces [`prose_limits`](settings.md#prose_limits) when publishing PR
descriptions and walkthroughs. For recommendations and review replies, the
agent follows your writing instructions; those limits are not checked in code.

## Resume unfinished work

An unfinished PR's **WIP Details** includes a link back to the agent chat, so you
can pick up where you left off. It also records the current state and next action.

For location privacy, custom prompts, opening checks, branch names, and other
advanced choices, use the [settings reference](settings.md).
