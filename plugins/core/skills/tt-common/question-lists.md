# Question lists

Some steps work out a whole list of questions before asking the first one:
design choices, an independent check's findings, open questions at a stage's
exit, candidate constraints, a work unit's engineer checks. Asking them one
response at a time, with an edit to a document after each answer, costs a full
turn per question. A question list records them once, by script, so they can
be answered one at a time in the chat or all together outside it, and then
carried out in one pass.

Use one only where every question is known before the first is asked. A
question that depends on the answer before it stays a conversation.

`<scripts>` is `<common>/scripts`. **`questions.sh` is the only writer of a
list**: never edit one by hand.

## 1. Write the list (one response)

The list is `<feature folder>/.tt/<Prefix> - Questions/<name>.md`, named for
what it holds (`design-choices`, `brief-check`, `open-questions`,
`constraints`, `validation-WU3`). Create it, then add every question at once:

```bash
bash "<scripts>/questions.sh" init "<list>" --title "<Prefix>: <what these are>" --for "<what the answers feed>" --feature "<Prefix>"
bash "<scripts>/questions.sh" add "<list>" <<'EOF'
title: <the question, in one line>
ref: <what it refers to, e.g. "WU3 check 2" or "Open question 3" (optional)>
context: <what the person needs to decide it: the facts, the repo's precedent
  (path:line), what each option leads to; more lines indented two spaces>
take: <your view and why, in one or two sentences (optional)>
option: <key> | <title> | <what it means, its cost> | recommended
option: <key> | <title> | <detail> | note
---
title: <the next question>
...
EOF
```

- Two to four options per question, the recommended one marked `recommended`
  (at most one). `note` marks an option that needs the person's words when it
  is chosen (a reason, what they saw, what to write instead).
- The context must stand on its own: a front end may show it without the
  conversation. Name paths, IDs (with their words from `ids.sh gloss`) and
  values; never "as discussed".
- A list never holds an `Other` option of its own. Where "something else" is a
  real answer, add it as an option with `note`.

## 2. Put them to the person

Run `bash "<scripts>/decide.sh" mode`.

- **`chat`**: one question at a time, as the step always did: the question,
  its context and your take in a few lines, then `AskUserQuestion` with the
  options in the list's order, recommended first. Record each answer with
  `bash "<scripts>/questions.sh" decide "<list>" Q<n> <key> [--note "<their words>"]`
  in the same response as the next question. Carry nothing out yet.
- **`elsewhere`**: the person answers outside the chat. Say in one line how
  many questions wait and the list's path, and that they should say "continue"
  when they have answered. Then **end your turn**: ask nothing.

## 3. Carry them out (one pass)

`bash "<scripts>/questions.sh" list --tsv "<list>"` gives
`id state decision ref title`. Rows still `open` in `elsewhere` mode are
waiting: say which, and end your turn again. For the rows in state `apply`,
read each one's note with `questions.sh show "<list>" Q<n>`, do what the step
says the answers lead to, then mark each done with
`bash "<scripts>/questions.sh" applied "<list>" Q<n> "<what was done, in a few words>"`.
Check the answers against each other first: if two conflict, put just those
to the person again.

On a resume, the list's states say where things stand: questions with no
decision are asked (or waited for), decided ones are carried out.
