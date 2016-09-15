open Core

type t

val repository : ?store:Keystore.t -> ?quorum:int -> Provider.t -> t
val provider : t -> Provider.t
val quorum : t -> int

val change_provider : t -> Provider.t -> t

val verify_index : t -> Index.t -> (identifier, verification_error) result

val pp_ok : Format.formatter -> [< `Signed of identifier | `Quorum of S.t | `Both of identifier * S.t ] -> unit

type base_error = [
  | `InvalidName of name * name
  | `InvalidResource of name * resource * resource
  | `NotSigned of name * resource * S.t
]

val pp_error : Format.formatter -> [< base_error | `InsufficientQuorum of name * S.t | `MissingSignature of identifier | `AuthRelMismatch of name * name | `NotInReleases of name * S.t ] -> unit

val verify_key : t -> Publickey.t ->
  ([ `Quorum of S.t | `Both of identifier * S.t ],
   [ base_error | `InsufficientQuorum of name * S.t | `MissingSignature of identifier ]) result

val verify_authorisation : t -> Authorisation.t ->
  ([ `Quorum of S.t ],
   [ base_error | `InsufficientQuorum of name * S.t ]) result

val verify_releases : t -> Authorisation.t -> Releases.t ->
  ([ `Signed of identifier | `Quorum of S.t | `Both of identifier * S.t ],
   [ base_error | `AuthRelMismatch of name * name ]) result

val verify_checksum : t -> Authorisation.t -> Releases.t -> Checksum.t ->
  ([ `Signed of identifier | `Quorum of S.t | `Both of identifier * S.t ],
   [ base_error | `AuthRelMismatch of name * name | `NotInReleases of name * S.t ]) result

val add_index : t -> Index.t -> t

val add_trusted_key : t -> Publickey.t -> t

val all_keyids : t -> S.t
val all_authors : t -> S.t
val all_janitors : t -> S.t
val all_authorisations : t -> S.t

type r_err = [ `NotFound of string | `NameMismatch of string * string ]
type 'a r_res = ('a, r_err) result

val pp_r_err : Format.formatter -> r_err -> unit

val read_key : t -> identifier -> Publickey.t r_res
val write_key : t -> Publickey.t -> unit

val read_index : t -> identifier -> Index.t r_res
val write_index : t -> Index.t -> unit

val read_authorisation : t -> name -> Authorisation.t r_res
val write_authorisation : t -> Authorisation.t -> unit

val read_releases : t -> name -> Releases.t r_res
val write_releases : t -> Releases.t -> unit

val read_checksum : t -> name -> Checksum.t r_res
val write_checksum : t -> Checksum.t -> unit

(* XXX: return value clearly wrong! *)
val compute_checksum : t -> name -> Checksum.t r_res
