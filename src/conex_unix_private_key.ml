open Conex_utils
open Conex_unix_persistency

let private_dir = Filename.concat (Sys.getenv "HOME") ".conex"

let find_ids () =
  collect_dir private_dir >>= fun files ->
  Ok (List.fold_left
        (fun acc s ->
           match List.rev (String.cuts '.' s) with
           | p::id::path when p = "private" ->
             (id, "/" ^ (path_to_string (List.rev path))) :: acc
           | _ -> acc)
        []
        files)

let private_key_path path id =
  let filename =
    let els = string_to_path path @ [id ; "private"] in
    String.concat "." els
  in
  "/" ^ path_to_string (string_to_path private_dir @ [ filename ])

let write prov id key =
  let base = prov.Conex_io.basedir in
  let filename = private_key_path base id in
  (if exists filename then begin
      let ts =
        let open Unix in
        let t = gmtime (stat filename).st_mtime in
        Printf.sprintf "%4d%2d%2d%2d%2d%2d" (t.tm_year + 1900) (succ t.tm_mon)
          t.tm_mday t.tm_hour t.tm_min t.tm_sec
      in
      let backfn = String.concat "." [ id ; ts ] in
      let backup = private_key_path base backfn in
      let rec inc n =
        let nam = backup ^ "." ^ string_of_int n in
        if exists nam then inc (succ n) else nam
      in
      let backup = if exists backup then inc 0 else backup in
      rename filename backup
    end else Ok ()) >>= fun () ->
  (if not (exists private_dir) then
     mkdir ~mode:0o700 private_dir
   else Ok ()) >>= fun () ->
  match file_type private_dir with
  | Ok Directory ->
    let key = match key with `Priv (_alg, data, _created) -> data in
    write_file ~mode:0o400 filename key
  | _ -> Error (private_dir ^ " is not a directory!")

type err = [ `NotFound of string | `Msg of string]

(*BISECT-IGNORE-BEGIN*)
let pp_err ppf = function
  | `NotFound x -> Format.fprintf ppf "couldn't find private key %s" x
  | `Msg m -> Format.fprintf ppf "error %s while trying to read private key" m
(*BISECT-IGNORE-END*)

let read prov id =
  let base = prov.Conex_io.basedir in
  let fn = private_key_path base id in
  if exists fn then
    match read_file fn with
    | Error e -> Error (`Msg e)
    | Ok key ->
      let stat = Unix.stat fn in
      match Uint.of_float stat.Unix.st_mtime with
      | None -> Error (`Msg "couldn't convert modification time to Uint")
      | Some created -> Ok (`Priv (`RSA, key, created))
  else
    Error (`NotFound id)
