# Criteria written at 2026-10-19T08:57:31Z (file time), after the first trivial run started at 08:56:59Z and before the other 29 runs started at 08:57:41Z or later
Scored from each report's JSON fields, blind to arm (outputs shuffled under random IDs).
shared_caller (#695):
 S1 states the fact safety rests on (only the empty-stdout non-zero-exit path changes; other paths unchanged)
 S2 names the consuming paths a failure reaches (pr / pr watch / handoff / merge, Status or RequiredChecks)
 S3 names a specific unexercised path (consuming commands end to end, a live rate limit, GraphQL message without HTTP status, exit 8)
 S4 addresses revert consequence
 S5 conclusion Proceed
irreversible (#552):
 I1 states the fact safety rests on (exception applies only to the exact confirmed head and only to an empty required-check set)
 I2 says a wrong merge is not undone by reverting the Shaka change / merge is irreversible
 I3 names that no live merge or real GitHub path was exercised (fake client only)
 I4 conclusion (recorded, not scored as right/wrong)
trivial (#635):
 T1 Proceed with empty concerns
 T2 asks for no additional verification
 T3 visible words (summary + reasons + alternative + next_action) recorded; after arm should not exceed before arm mean by more than 25%
