open Core

let lowercase_equal names name =
  let name = Strhelper.lowercase_string name in
  (* check that name is good, here a case-insensitive comparison *)
  not (S.exists
         (fun n -> String.compare (Strhelper.lowercase_string n) name = 0)
         names)

let unique_keyid = lowercase_equal
and unique_data = lowercase_equal

let valid_keyid id = Strhelper.is_ascii id

let valid_name package =
  let p = function '-' | '_' -> true | _ -> false in
  Strhelper.is_ascii ~p package

let authorisation_of_item x =
  match Strhelper.cut '.' x with
  | Some (pre, _) -> Some pre
  | None -> None

let private_dir = Filename.concat (Sys.getenv "HOME") ".conex"

let private_keys p =
  let is_private s =
    if Strhelper.is_suffix ~suffix:".private" s then
      let p = string_to_path (p.Provider.name) in
      match List.rev (Strhelper.cuts '.' s) with
      | _::id::path when p = List.rev path -> Some id
      | _ -> None
    else
      None
  in
  List.fold_left
    (fun acc s ->
       Utils.option acc (fun s -> s :: acc) (is_private s))
    []
    (Persistency.collect_dir private_dir)

let private_key_path path id =
  let filename =
    let els = path @ [id ; "private"] in
    String.concat "." els
  in
  string_to_path private_dir @ [ filename ]

let key_dir = "keys"

let ids p =
  match p.Provider.read_dir [ key_dir ] with
  | Error _ -> []
  | Ok data ->
    let f = function
      | `File f -> Some f
      | _ -> None
    in
    Utils.filter_map ~f data

let key_path id = [ key_dir ; id ]

let ipath = "index"
let index_path ji = [ ipath ; ji ]

let data_dir = "packages"
let authorisation_filename = "authorisation"

let authorisations p =
  match p.Provider.read_dir [ data_dir ] with
  | Error _ -> []
  | Ok data ->
    let f = function
      | `Dir d -> Some d
      | `File _ -> None
    in
    Utils.filter_map ~f data

let authorisation_path id = [ data_dir ; id ; authorisation_filename ]

let releases_filename = "releases"
let releases_path id = [ data_dir ; id ; releases_filename ]

let checksum_filename = "checksum"

let items p id =
  match p.Provider.read_dir [ data_dir ; id ] with
  | Error _ -> []
  | Ok data ->
    let f = function
      | `Dir d -> Some d
      | `File _ -> None
    in
    Utils.filter_map ~f data

let checksum_dir p =
  match authorisation_of_item p with
  | Some d -> [ data_dir ; d ; p ]
  | None -> [ data_dir ; p ; p ]

let checksum_path p =
  checksum_dir p @ [checksum_filename]

let checksum_files p da =
  let st = match authorisation_of_item da with
    | Some de -> [ data_dir ; de ; da ]
    | None -> [ data_dir ; da ; da ]
  in
  let rec collect1 acc d = function
    | `File f when d = [] && f = checksum_filename -> acc
    | `File f -> (d@[f]) :: acc
    | `Dir dir ->
      let sub = d @ [ dir ] in
      match p.Provider.read_dir (st@sub) with
      | Error _ -> []
      | Ok data ->
        List.fold_left
          (fun acc x -> collect1 acc sub x)
          acc
          data
  in
  match p.Provider.read_dir st with
  | Error _ -> []
  | Ok data ->
    List.fold_left
      (fun acc x -> collect1 [] [] x @ acc)
      []
      data

let is_index = function
  | idx ::id :: [] when idx = ipath -> Some id
  | _ -> None

let is_key = function
  | kd :: id :: [] when kd = key_dir -> Some id
  | _ -> None

let is_authorisation = function
  | dd :: id :: dfn :: [] when dd = data_dir && dfn = authorisation_filename->
    Some id
  | _ -> None

let compare_insensitive a b = Strhelper.lowercase_string a = Strhelper.lowercase_string b

let is_item = function
  | dd :: id :: id2 :: _ when dd = data_dir ->
    (match authorisation_of_item id2 with
     | Some x when compare_insensitive x id -> Some (id, id2)
     | _ -> None)
  | _ -> None

let is_old_item = function
  | dd :: id :: _ when dd = data_dir ->
    (match authorisation_of_item id with
     | Some x -> Some (x, id)
     | _ -> None)
  | _ -> None

let is_compiler = function
  | cc :: v :: vm :: _ when cc = "compilers" -> Some (v, vm)
  | _ -> None
