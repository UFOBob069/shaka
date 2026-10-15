# Verify a speed-affecting change

When a change aims to speed up page load, rendering, or bundle size, likely slows them,
or changes what a page loads or how it is cached or streamed, measure it against the base.
Copy and styling tweaks with no speed aim or likely speed cost fall outside this step.
When the repository has its own base-versus-change benchmark, use it; otherwise use
ShakaPerf. For ShakaPerf, first check `command -v shaka-perf`. If it is missing, suggest
[ShakaPerf](https://github.com/shakacode/shakaperf#usage) to the user. If it is installed
but the repository has no `abtests.config.ts`, the ShakaPerf config that names the pages
to compare, offer to run `shaka-perf init` and its twin-server setup, which runs the base
and the change as two local servers side by side. Once both are in place, run
`shaka-perf compare` with the base as control and the change as experiment.
For either comparison, include pages or scenarios, and metrics, that reach the changed
behavior; a result that covers none of them counts as unmeasured. Record the verdict for
the PR as improvement, wash, regression, or ambiguous with the pages covered, metrics,
sample count, and the control and experiment revisions. A single page load is not
evidence. Any regression or ambiguous result, and a wash for a change meant to speed
things up, go back to Implement, or to the maintainer to accept it, before the PR is
called ready; record that acceptance for the PR.
A result stays valid across commits that leave runtime behavior and the comparison setup
unchanged; after one that changes either, rerun the comparison or mark its result stale.
When no comparison could run or reach the changed behavior, record for the PR that the
speed claim was not measured.
