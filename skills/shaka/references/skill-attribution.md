# Record skills used

Append each applied skill, including Shaka, to the existing durable task record at
first use. Add entries for different phases or revisions; include available reports
from authorized workers and reviewers. Inspecting instructions, installed skills,
and unused requests do not establish applied use.

Retain the complete list on resume and supply it as description `skills_used` on
publication. The optional JSON key keeps older callers compatible; missing records
leave coverage unknown. Keep Shaka's own entries, named `shaka` with source
`ShakaCode/shaka`; the table omits them, and a Shaka-only record then reports no
other skills. Use the resolved name, public source and available revision
(otherwise `UNKNOWN`), phase, and one-line contribution:

```json
{
  "name": "to-spec",
  "source": "AI Hero",
  "revision": "UNKNOWN",
  "phase": "planning",
  "contribution": "Prepared acceptance criteria",
  "evidence": "agent-reported",
  "corroboration": null
}
```

Select `agent-reported` with null `corroboration`, or `corroborated` when a native
event or recorded tool call confirms invocation/loading; name that record in
`corroboration`. Both labels are agent-assessed. Ruby validates metadata, not
evidence truth, procedural compliance, or completeness.

When the task record is lost, load [skill recovery](skill-attribution-recovery.md)
before starting a replacement list.

Before publication, replace private names, sources, revisions, and contribution
details with `Undisclosed private skill`, `UNKNOWN`, or a public-safe account of use.
Keep transcripts, private links, and local paths out of every public field.
