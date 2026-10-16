**Did we build the right thing?** Assume for this review that the implementation
is technically correct. Re-read the original problem, intended users, desired
outcome, and project constraints. Evaluate the finished change as a whole.

- Does the observed result improve the intended outcome for those users?
- Did building it reveal an unnecessary, misguided, or poorly framed request?
- Has scope drifted? Compare actual files, commits, review rounds, and repairs
  with what the plan expected. Mark missing impact or frequency evidence unknown.
- Is the benefit proportional to dependencies, configuration, abstractions,
  coupling, failure paths, tests, and future maintenance?
- Is the reported verification proportionate to what a failure would reach and
  to whether a revert undoes it? Weigh the evidence as given rather than
  re-reviewing code, and name paths that were not exercised.
- Does repeated review churn reveal an approach problem rather than isolated bugs?
- Could a simpler formulation, existing capability, or no change deliver the
  outcome? Name any guarantees lost and evidence that losing them is acceptable.
- Will future work have to understand and build around unjustified complexity?
- Knowing the result and cost, would we choose this approach again?

Focus on product fit, architecture, scope, and value. Another minor code nit is
not a reason to run this review. Conclude **Proceed**, **Simplify/reframe**, or
**Do not merge**, with concrete reasons and the smallest useful next action.

Assess every question, but report only evidence that affects the decision. Do not
write a paragraph for each criterion or repeat the conclusion in the summary,
reasons, and next action. Omit generic assurances and claims of significance.

For routine **Proceed** results, aim for 60–100 visible words. Give a short summary
with the concrete reason and a concise next action. Supporting reasons and the
alternative are published in collapsed details; keep them selective too.
List every substantive unresolved concern in concerns so it remains visible.
Use more explanation when a blocker or consequential tradeoff needs it.
Discuss revision or replacement only when the result calls for that decision.
