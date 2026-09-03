# Restate a guard on its second finding — don't extend it

A guard that draws a second review finding is stated in the wrong terms. It
was written as a list of things the input must not be — a sign check, then a
finiteness check, then a sub-millisecond check — when the rule was always one
statement about the result. Each extension patches the example the reviewer
produced and leaves the next one open, so the class drains out one round at a
time. The second finding is the signal to stop extending and restate: express
the rule in terms of the result, or move it where the invalid state cannot be
produced at all — a parsed/branded type, one constructor, a schema
constraint, a write that carries its own condition. fix-at-the-owning-layer
and close-races-structurally say *where* such a fix goes; this rule says
*when* you must stop patching.

## Check

- Second round in which the same guard, call site, or predicate list gained
  a clause? The next clause is not the fix. Write the invariant in one
  sentence about the output ("the expiry is after now", "every refusal
  namespace is locked", "an occurrence is a row") and derive the check from
  that sentence.
- Can a caller who forgets the check still construct the invalid state? Then
  the check is a convention. Prefer a type only a parser can produce, a
  single chokepoint, or a constraint the store enforces.
- Does one row, object, or flag carry more than one lifecycle (definition,
  in-flight occurrence, last outcome)? Every fix will be a predicate the next
  call site must remember. Split the concepts so the double-fire guard is an
  index, not a memory.
- Is a case list (`stop_reason`, status codes, error kinds) growing an arm
  per round? Make it exhaustive by construction — a `switch` with a
  compile-time default, or the provider's own classification imported
  wholesale — rather than adding the arm the reviewer named.
- Did the fix commit say "the Nth time this guard has come up"? That sentence
  is the finding. Act on it in the same commit, not two rounds later.

## From the history

**Violation — a17k/a17k#433:** a TTL guard drew rounds 1, 3, and 4 (`0` or
negative; `1e400` parsing to `Infinity`; `0.0001` truncating to the same
millisecond). Round 4: "each fix was another statement about what the input
must not be… The rule was always one question about the value being stored:
does this TTL put the expiry after the moment of registration?" One
comparison on the result replaced three predicates. The same PR's
writer-identity guard gained a field in rounds 2, 3, 5, 8, and 9; round 5's
commit already said "a guard that keeps attracting findings is usually
stated in terms of its inputs when it should be stated in terms of its
result" — and two more rounds patched anyway. Round 8 collapsed fourteen of
the PR's twenty-three findings into one `parseDeploymentRegistration(body:
unknown)` returning a branded type.

**Violation — a17k/a17k#445:** `approveConsent` assembled its authority
clauses by hand; six rounds each found a clause it left out. Round 4 named
it — "the third clause added to this one call site across four rounds — one
structural difference rather than three oversights" — and deferred the
restructuring; two more rounds of clauses followed before every `require*`
was made to evaluate the comparison and hand back the clause the write
re-asserts. "All six findings become unrepresentable."

**Violation — a17k/a17k#451:** one scheduled-task row carried the definition,
the in-flight occurrence, and the last outcome. Rounds 1–4 fenced it with a
status check, an occurrence token, a documented re-read, a settle closure.
Round 5: "each fix was a predicate the next call site had to remember… So
occurrences become rows; the double-fire guard is the index." No later round
named the original class again.

**Violation — a17k/a17k#450:** stop-reason handling grew an arm per round
(`max_tokens` on empty text, then on non-empty text, then `pause_turn`), and
the retry set gained `409` and then the provider's retry header the same way.

**Violation — a17k/a17k#452:** three rounds guarded one merge button against
unsaved text, pending drafts, then in-flight mutations, before round 4 found
"the reload itself is the defect" — the handler's `load()` unmounted every
composer. Removing it superseded all three guards.

**Done right — a17k/a17k#435 / #436:** after #433, the request and id types
were branded at the parse boundary before the next surface was built; the
grants API that followed shipped in a single review round.
