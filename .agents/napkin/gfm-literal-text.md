# Inline HTML does not make GFM text literal

Date: 2026-10-12

Why it matters: GitHub's Markdown API rendered links and images inside an inline
`<code>` element after `CGI.escapeHTML`. HTML escaping alone preserved Markdown syntax.

Do instead: For transcribed assessment text, encode Markdown punctuation as character
entities, as `LocalReviewAssessmentView#literal` does. Verify the rendered HTML has
no injected links or images. Keep retained JSON in a literal `<pre>` block.
