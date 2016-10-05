open Core

val apply : Repository.t -> Diff.diff -> Repository.t

type err = [ verification_error
           | Repository.base_error
           | `InsufficientQuorum of name * S.t
           | `InvalidReleases of name * S.t * S.t
           | `AuthRelMismatch of name * name
           | `NotInReleases of name * S.t
           | `FileNotFound of name
           | `NotADirectory of name
           | `ChecksumsDiff of name * name list * name list * (Checksum.c * Checksum.c) list
           | `NameMismatch of string * string
           | `ParseError of Core.name * string
           | `MissingSignature of Core.identifier
           | `NotFound of string
           | `CounterNotIncreased
           | `CounterNotZero
           | `IllegalId
           | `IllegalName
           | `InvalidKeyTeam
           | `MissingAuthorisation of name ]

val verify_diff : Repository.t -> string -> (Repository.t, [> err ]) result
