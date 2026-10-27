# Swift helper pre-push validation

The active backend is the Swift helper with native Globe cycling. Its push gate
must accept the tested native-menu candidate rather than require an Fcitx trial.

Use a standalone standard-library Python validator from `.githooks/pre-push`.
An approval binds the pushed Git tree's input files to a freshly rebuilt helper,
the installed binary, the host/OS and normalized input settings. It preserves
hashed copies of the settled F18 results, their helper log, the accepted physical
report/trace/log, actual resident readiness, and successful scoped test runs.
Raw records are checked again when approval is consumed; summary pass flags alone
are insufficient. No typing, source switching, installation or permission change
occurs in the hook.

Compare the pushed commit's protected blobs, including additions, deletions and
file modes. Do not fingerprint unrelated dirty files or untracked experiments.
Documentation-only changes do not need another physical trial. Changed native
runtime files need a matching approval. Experimental Fcitx changes continue
through the existing experiment gate and fail closed if it is unavailable.

Validation must cover a valid native candidate, wrong source/layout, missing
physical confirmation, changed evidence/binary/settings, a different pushed
commit despite a matching working tree, multiple refs, deletions/new branches,
and normal unrelated changes. Exercise the actual shell hook against the already
accepted candidate without pushing or injecting keys.

## Evidence and approval contract

The CLI accepts the current native-menu verification artifacts. Automatic rows
must have ordered unique snapshot tokens, matching request targets, settled
source/context/layout, retained focus/text and finite completion timing. Request
logs must cover ABC -> Korean, Korean -> ABC and, in ko-en-ja, Japanese -> Korean.
A synthetic source/layout run alone cannot supply physical acceptance.

The separate physical trace must contain real sourcePID=0 key-down events in the
required sources, correct layouts, Korean composition and matching d/k/s/l/z
translations. Counts are recomputed from raw records and compared with the
accepted report and helper log. The user's full physical checklist confirmation
is required separately, including Globe and Japanese behavior; the validator
must not infer Japanese kana composition from an ABC base layout or source ID.

Approval requires a fresh release build matching the installed and physically
tested SHA-256. The chosen commit is exported for make/Swift tests; only then is
an atomic approval pointer published. Prior approvals survive failed validation.
The working Swift package must match the candidate commit before and after this
process. Startup Accessibility is checked from the actual LaunchAgent PID's
latest ready record, not a CLI process's inherited permission. This is startup
evidence, not continuous proof that permission was never revoked. If macOS has
pruned that record, restart the helper and recheck readiness.

The stored source manifest contains Git blob hashes and modes for the Swift
package, input LaunchAgents, bootstrap/setup scripts, native input support and
Makefile. Each pushed ref is checked against it, including newly added/deleted
files. All evidence files and the manifest are hashed and revalidated. Approval
is host/configuration specific. It is a local consistency gate, not a signed
attestation against an owner who can edit Git configuration or local evidence.

Fcitx/experimental files delegate to the old gate, which must be available and
pass independently. A mixed native/experiment update is never authorized solely
by the Swift report. Hook code, docs and test-only changes do not themselves
alter the helper runtime and do not require another keyboard trial.

## Current acceptance

The existing accepted candidate a6db5fe was rebuilt to the exact installed hash
ffb71284e6ce472afa8992f562844d86a230ba5c0e04dcf100a02a078e6fe5ab.
Its raw evidence validates 80 automatic F18 transitions, 227 physical key-downs
and 66 physical-session helper requests. Both scoped test commands passed.
The actual shell hook accepted the same native update range that the old Fcitx
gate rejected. No keys were injected and the helper binary was not reinstalled.

Regression coverage: 41 gate tests pass, including wrong physical translation,
stale source/layout snapshots, changed evidence/binary/configuration, a different
pushed tree despite a matching working copy, runtime file additions/deletions,
mode changes and renames out of protected directories, missing/failed legacy
gates, active trials and failed approval builds/tests. The full workspace suite
also passes. Git ref deletions and unrelated docs do not trigger a keyboard run.
