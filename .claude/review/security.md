# Security pass

The `reviewer` applies this on top of `checklist.md` when a diff touches
authentication, authorization, secrets, input parsing, file paths, shell
commands, queries, deserialization, outbound network calls or dependencies.

Report only issues with a concrete exploit path: who controls the input, how it
reaches the sink, and what they gain. "Could be insecure" is not a finding.

## Input reaching a dangerous sink
- **Shell:** is user-influenced data passed to a shell? Use argument arrays,
  not string interpolation, and never `shell=True` with untrusted input.
- **Queries:** are SQL, NoSQL or LDAP queries parameterized?
- **Paths:** can a user-supplied path escape its intended directory (`..`,
  absolute paths, symlinks)? Is it resolved and checked against a base?
- **Templates and HTML:** is output escaped for its context? Watch for
  `innerHTML`, `dangerouslySetInnerHTML`, `|safe` and `v-html`.
- **Deserialization:** is untrusted data loaded with `pickle`, `yaml.load`
  (not `safe_load`), Java serialization or `eval`?
- **URLs:** can a user make the server fetch an arbitrary URL (SSRF), or
  redirect to an arbitrary site?

## Identity and access
- Is every new endpoint or handler behind the same authentication as its
  neighbours?
- Is authorization checked on the *object* (this user owns this record), not
  just on the route?
- Are tokens, sessions and password resets single-use, expiring, and compared
  in constant time?

## Secrets and data
- Are any secrets, tokens or keys hard-coded, logged, or included in error
  messages or test fixtures?
- Is sensitive data (PII, credentials) written to logs, analytics or caches?
- Is randomness for security (tokens, IDs that must be unguessable) drawn from
  a cryptographic source?

## Dependencies and supply chain
- Is a new dependency well known, maintained, and pinned? Is it pulled from
  the expected registry?
- Do new CI steps or scripts download and run code? Is it pinned by version or
  hash?
- Do workflow changes widen permissions (`permissions:`, `pull_request_target`,
  secrets exposed to forks)?
