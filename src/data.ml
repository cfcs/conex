open Core

(* crappy data implementation using "structured" strings *)
type key = string
type value =
  | String of string
  | Int of int64

type t =
  | Entry of key * t
  | List of t list
  | Leaf of value

(* we do not recurse into the tree, just working on the top *)
let rec get t key =
  match t with
  | Entry (k, v) when k = key -> Some v
  | List xs ->
     let isit = function None -> false | Some _ -> true in
     (try List.find isit (List.map (fun x -> get x key) xs) with Not_found -> None)
  | Leaf _ -> None
  | Entry _ -> None

let get_exn t key =
  match get t key with
  | Some x -> x
  | None -> invalid_arg ("couldn't find key: " ^ key)

let extract_string_exn = function
  | Leaf (String x) -> x
  | _ -> invalid_arg "couldn't find string"

let extract_int_exn = function
  | Leaf (Int x) -> x
  | _ -> invalid_arg "couldn't find int"

let rec to_string = function
  | Entry (k, v) -> k ^ ":" ^ (to_string v)
  | List xs -> "[" ^ (String.concat ",\n"  (List.map to_string xs)) ^ "]"
  | Leaf (String s) -> "\"" ^ s ^ "\""
  | Leaf (Int i) -> Int64.to_string i

let rec parse' data =
  let is_entry buf =
    let ws = try String.index buf ' '
             with Not_found -> String.length buf
    and colon = try String.index buf ':'
                with Not_found -> String.length buf
    in
    colon < ws
  and is_leaf buf =
    let str = String.get buf 0 = '"'
    and num =
      let ws = try String.index buf ' '
               with Not_found -> String.length buf
      and comma = try String.index buf ','
                  with Not_found -> String.length buf
      in
      let bound = min ws comma in
      try int_of_string (String.sub buf 0 bound) >= 0
      with _ -> false
    in
    str || num
  and is_list buf = String.get buf 0 = '['
  and is_nl buf = String.get buf 0 = '\n'
  in
  let parse_entry buf =
    let colon = String.index buf ':' in
    let colon' = succ colon in
    match parse' (String.sub buf colon' (String.length buf - colon')) with
    | Some value, rst -> (Some (Entry (String.sub buf 0 colon, value)), rst)
    | None, _ -> invalid_arg "couldn't parse rhs of an entry"
  and parse_leaf buf =
    if String.get buf 0 = '"' then
      let stop = String.index_from buf 1 '"' in
      let stop' = succ stop in
      (Some (Leaf (String (String.sub buf 1 (pred stop)))),
       String.sub buf stop' (String.length buf - stop'))
    else
      let rec go idx =
        match String.get buf idx with
        | '0' .. '9' -> go (succ idx)
        | _ -> idx
      in
      let stop = go 0 in
      let ss = String.sub buf 0 stop in
      (Some (Leaf (Int (Int64.of_string ss))),
       String.sub buf stop (String.length buf - stop))
  and parse_list buf =
    let rec go str acc =
      if String.get str 0 = ']' then
        let rest = String.sub str 1 (pred (String.length str)) in
        (Some (List (List.rev acc)), rest)
      else
        match parse' str with
        | Some d, rst ->
           if String.get rst 0 = ',' then
             go (String.sub rst 1 (pred (String.length rst))) (d :: acc)
           else if String.get rst 0 = ']' then
             let rest = String.sub rst 1 (pred (String.length rst)) in
             (Some (List (List.rev (d :: acc))), rest)
           else
             invalid_arg "unknown list"
        | None, _ -> invalid_arg "couldn't parse list entry"
    in
    go (String.sub buf 1 (pred (String.length buf))) []
  in
  if data = "" then
    (None, "")
  else if is_nl data then
    parse' (String.sub data 1 (pred (String.length data)))
  else if is_list data then
    parse_list data
  else if is_leaf data then
    parse_leaf data
  else if is_entry data then
    parse_entry data
  else
    invalid_arg ("invalid string: " ^ data)

let parse data =
  let rec go str acc =
    match parse' str with
    | None, "" -> List.rev acc
    | Some x, "" -> List.rev (x :: acc)
    | None, rst -> go rst acc
    | Some x, rst -> go rst (x :: acc)
  in
  match go data [] with
  | [] -> invalid_arg "empty"
  | [x] -> x
  | xs -> List xs

let normalise = to_string


let signature_to_data (id, ts, s) =
  List [
    Entry ("keyid", Leaf (String id)) ;
    Entry ("created", Leaf (Int ts)) ;
    Entry ("sig", Leaf (String s))
  ]

let data_to_signature signature =
  let keyid = extract_string_exn (get_exn signature "keyid")
  and created = extract_int_exn (get_exn signature "created")
  and sigval = extract_string_exn (get_exn signature "sig")
  in
  (keyid, created, sigval)

let parse_signed_data data =
  match get data "signatures" with
  | Some (List t) ->
     let signed = get_exn data "signed" in
     (signed, List.map data_to_signature t)
  | Some _ -> invalid_arg "signatures must be a list"
  | None -> (data, [])

let r_to_data (name, resource, digest) =
  List [ Leaf (String name) ;
         Leaf (String (resource_to_string resource)) ;
         Leaf (String digest) ]

let data_to_r = function
  | List (n::k::d::[]) ->
    let name = extract_string_exn n
    and resource = extract_string_exn k
    and digest = extract_string_exn d
    in
    (match string_to_resource resource with
     | None -> invalid_arg "bad resource string"
     | Some r -> (name, r, digest))
  | _ -> invalid_arg "bad resource"

let index_to_data i =
  List [ Entry ("signed", List [ Entry ("counter"   , Leaf (Int i.Index.counter)) ;
                                 Entry ("version"   , Leaf (Int i.Index.version)) ;
                                 Entry ("identifier", Leaf (String i.Index.identifier)) ;
                                 Entry ("resources" , List (List.map r_to_data i.Index.resources)) ]) ;
         Entry ("signatures", List (List.map signature_to_data i.Index.signatures)) ]

let index_to_string i =
  let data = index_to_data i in
  let signed, _ = parse_signed_data data in
  normalise signed

let index_to_raw i = normalise (index_to_data i)

let data_to_index data =
  let signed, signatures = parse_signed_data data in
  let counter = extract_int_exn (get_exn signed "counter")
  and version = extract_int_exn (get_exn signed "version")
  and identifier = extract_string_exn (get_exn signed "identifier")
  and rs = get_exn signed "resources"
  in
  let resources = match rs with
    | List r -> List.map data_to_r r
    | _ -> invalid_arg "unknown resources"
  in
  Index.index ~counter ~version ~resources ~signatures identifier

let string_to_index s =
  try Ok (data_to_index (parse s)) with Invalid_argument a -> Error a


let publickey_to_data pubkey =
  let pem = match pubkey.Publickey.key with
    | None -> "NONE"
    | Some x -> Publickey.encode_key x
  in
  List [ Entry ("counter", Leaf (Int pubkey.Publickey.counter)) ;
         Entry ("version", Leaf (Int pubkey.Publickey.version)) ;
         Entry ("keyid"  , Leaf (String pubkey.Publickey.keyid)) ;
         Entry ("key"    , Leaf (String pem)) ]

let publickey_to_string p = normalise (publickey_to_data p)

let data_to_publickey data =
  let counter = extract_int_exn (get_exn data "counter")
  and version = extract_int_exn (get_exn data "version")
  and keyid = extract_string_exn (get_exn data "keyid")
  and key = extract_string_exn (get_exn data "key")
  in
  let key =
    match key with
    | "NONE" -> None
    | _ -> match Publickey.decode_key key with
      | Some k -> Some k
      | None -> invalid_arg "cannot decode public key"
  in
  Publickey.publickey ~counter ~version keyid key

let string_to_publickey s =
  try data_to_publickey (parse s) with Invalid_argument a -> Error a


let releases_to_data r =
  let id s = Leaf (String s) in
  List [ Entry ("name"     , Leaf (String r.Releases.name)) ;
         Entry ("counter"  , Leaf (Int r.Releases.counter)) ;
         Entry ("version"  , Leaf (Int r.Releases.version)) ;
         Entry ("releases" , List (List.map id (S.elements r.Releases.releases))) ]

let releases_to_string r = normalise (releases_to_data r)

let data_to_releases data =
  let id x = extract_string_exn x in
  let name = extract_string_exn (get_exn data "name")
  and counter = extract_int_exn (get_exn data "counter")
  and version = extract_int_exn (get_exn data "version")
  and releases = match get_exn data "releases" with
    | List es -> S.of_list (List.map id es)
    | _ -> invalid_arg "releases not a list"
  in
  Releases.releases ~counter ~version ~releases name

let string_to_releases s =
  try data_to_releases (parse s) with Invalid_argument a -> Error a


let authorisation_to_data d =
  let id s = Leaf (String s) in
  List [ Entry ("name"      , Leaf (String d.Authorisation.name)) ;
         Entry ("counter"   , Leaf (Int d.Authorisation.counter)) ;
         Entry ("version"   , Leaf (Int d.Authorisation.version)) ;
         Entry ("authorised", List (List.map id (S.elements d.Authorisation.authorised))) ]

let authorisation_to_string a = normalise (authorisation_to_data a)

let data_to_authorisation data =
  let id x = extract_string_exn x in
  let name = extract_string_exn (get_exn data "name")
  and counter = extract_int_exn (get_exn data "counter")
  and version = extract_int_exn (get_exn data "version")
  and authorised = match get_exn data "authorised" with
    | List es -> S.of_list (List.map id es)
    | _ -> invalid_arg "authorised not a list"
  in
  Authorisation.authorisation ~counter ~version ~authorised name

let string_to_authorisation s =
  try Ok (data_to_authorisation (parse s)) with Invalid_argument a -> Error a


let team_to_data d =
  let id s = Leaf (String s) in
  List [ Entry ("name"   , Leaf (String d.Team.name)) ;
         Entry ("counter", Leaf (Int d.Team.counter)) ;
         Entry ("version", Leaf (Int d.Team.version)) ;
         Entry ("members", List (List.map id (S.elements d.Team.members))) ]

let team_to_string a = normalise (team_to_data a)

let data_to_team data =
  let id x = extract_string_exn x in
  let name = extract_string_exn (get_exn data "name")
  and counter = extract_int_exn (get_exn data "counter")
  and version = extract_int_exn (get_exn data "version")
  and members = match get_exn data "members" with
    | List es -> S.of_list (List.map id es)
    | _ -> invalid_arg "members not a list"
  in
  Team.team ~counter ~version ~members name

let string_to_team s =
  try Ok (data_to_team (parse s)) with Invalid_argument a -> Error a


let checksum_to_data c =
  List [ Entry ("filename", Leaf (String c.Checksum.filename)) ;
         Entry ("byte-size", Leaf (Int c.Checksum.bytesize)) ;
         Entry ("sha256", Leaf (String c.Checksum.checksum)) ]

let checksums_to_data cs =
  let csums = Checksum.fold (fun c acc -> checksum_to_data c :: acc) cs.Checksum.files [] in
  List [ Entry ("counter", Leaf (Int cs.Checksum.counter)) ;
         Entry ("version", Leaf (Int cs.Checksum.version)) ;
         Entry ("name", Leaf (String cs.Checksum.name)) ;
         Entry ("files", List csums) ]

let checksums_to_string c = normalise (checksums_to_data c)

let data_to_checksum data =
  let filename = extract_string_exn (get_exn data "filename")
  and bytesize = extract_int_exn (get_exn data "byte-size")
  and checksum = extract_string_exn (get_exn data "sha256")
  in
  { Checksum.filename ; bytesize ; checksum }

let data_to_checksums data =
  let counter = extract_int_exn (get_exn data "counter")
  and version = extract_int_exn (get_exn data "version")
  and name = extract_string_exn (get_exn data "name")
  and sums = get_exn data "files"
  in
  let files = match sums with
    | List elements -> List.map data_to_checksum elements
    | _ -> invalid_arg "unknown files"
  in
  Checksum.checksums ~counter ~version name files

let string_to_checksums s =
  try Ok (data_to_checksums (parse s)) with Invalid_argument a -> Error a

