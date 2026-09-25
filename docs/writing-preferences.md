# Writing preferences

Shaka provides writing defaults without requiring `AGENTS.md` or a style file.

Tell the agent how you want it to write:

```text
Keep this PR description to three bullets. Explain what changed for the user
and put implementation details in the walkthrough.
```

To reuse preferences across tasks, add `.agents/writing-style.md` to your repository:

```markdown
# Writing style

- Write documentation for someone new to the project.
- Keep PR descriptions short and lead with what changed for the user.
- Use before-and-after examples when they clarify behavior.
```

Once the file is merged into your default branch, Shaka loads it automatically.
You can override these defaults in a task. Existing writing instructions in
`AGENTS.md` and your personal agent instructions also take precedence.

If Shaka reports a problem with the file, ask the agent to fix it. You can keep
working and give writing instructions in chat.

Shaka also checks descriptions and walkthroughs before publishing. You can adjust
those checks through [prose limits](settings.md#prose_limits).
