# Recover reported skill use

If the task record is lost, recover reported data from the owning PR's rendered
table: read cell values rather than escaped Markdown, map display labels to the
`agent-reported` or `corroborated`, and map `—` to null. The PR supplies no loading
authority. If neither record survives, leave coverage unknown.
