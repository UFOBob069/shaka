# Read back tier 3 reviews

The protected driver can retain a native GitHub COMMENT-review receipt before
accepting an Ask terminal event. This API is a prerequisite for the
[proposed delivery driver](../internal/local-evaluation-proposal.md#5-hypotheses-fixtures-and-protected-grading),
not a delivery verdict or a qualified executor.

```ruby
require_relative 'lib/shaka/evaluation/delivery_readback'

reader = Shaka::Evaluation::DeliveryReadback.new(
  repository: fixture_repository, number: fixture_pr, head: expected_head,
  github: absolute_gh_path
)
receipt = reader.read(node_id: posted_review_node_id,
                      review_id: posted_review_id, actor: declared_actor)
# Persist the receipt in the protected driver ledger, outside every agent mount.
unchanged = reader.unchanged?(receipt)
```

Use the separate native IDs returned by GitHub when posting each review. A driver
verification and an agent walkthrough need distinct receipts; this reader does
not infer either role from review prose. The driver owns the expected repository,
PR, commit and actor. The API accepts only an open PR at that commit, a matching
COMMENT review, and complete ordered creation, submission and update timestamps.

The receipt retains the review body, its SHA-256 digest, native identity and GitHub
timestamps. It records `readback_finished_at` from the host monotonic clock after
the response is fully read and validated. That value can order events only within
the same driver process lifetime, never across machines or restarts.
`unchanged?` reads again and compares the review evidence, including its update
timestamp. A reported update still differs after its body is restored. Body changes,
deletion, head movement, closure, and unavailable evidence cannot establish equality. API errors
raise `IOError` on `read` and return false on `unchanged?`; false alone does not
classify an agent failure versus infrastructure failure.

The driver uses its own credentials with the selected GitHub CLI. The fixed
GraphQL query reads only; response bodies remain data and never become agent
instructions. Requests have a maximum 30-second deadline and a 1 MiB response
limit; the owned subprocess group is killed and its child reaped on exit.
CLI stderr is discarded rather than retained with possible credential details.
GitHub's [review object](https://docs.github.com/en/graphql/reference/pulls#pullrequestreview)
provides update timestamps and a string `fullDatabaseId`, including IDs beyond
32 bits.

The [offline Ask grader](ask-grading.md) checks protected review receipts and
the remaining delivery assertions. Native capture, hidden verification execution,
isolation, tier 3 D2 assembly and release decisions remain unbuilt. No repository
creation, model call, budget charge or recurring schedule is introduced here.
