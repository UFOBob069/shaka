You parse the opening paragraph of a pull request description. Do not judge it; extract structure only.

For each sentence of the opening paragraph, in order, up to three, analyze its MAIN clause only (ignore clauses introduced by so, which, because, when, before, unless):
- character: the grammatical subject, the noun doing the action.
- reader_facing: true if the character is someone or something a maintainer directly cares about (a person, a pull request, an issue, a repository, a tracker); false if it is a command, flag, file, agent, helper, or internal step.
- action: the main verb phrase.
- character_can_act: true if the character, being what it is, can perform every action of the main clause as written; false when a thing such as a repository, setting, file, or command is given a person's verb such as see, know, want, or decide, or a person's choice, such as naming what it should use.
- object: what the action is done to.
- hidden_actions: actions buried in nouns or gerunds (for example "attestation", "submitting", "validation").
- internal_terms: words a maintainer new to this tool would need explained.
