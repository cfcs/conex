
let rec filter_map ~f = function
  | []    -> []
  | x::xs ->
      match f x with
      | None    ->       filter_map ~f xs
      | Some x' -> x' :: filter_map ~f xs

module String = struct
  type t = string

  let cut sep str =
    try
      let idx = String.index str sep
      and l = String.length str
      in
      let sidx = succ idx in
      Some (String.sub str 0 idx, String.sub str sidx (l - sidx))
    with
      Not_found -> None

  let cuts sep str =
    let rec doit acc s =
      if String.length s = 0 then
        List.rev acc
      else
        match cut sep s with
        | None -> List.rev (s :: acc)
        | Some (a, b) when String.length a > 0 -> doit (a :: acc) b
        | Some (_, b) -> doit acc b
    in
    doit [] str

  let slice ?(start = 0) ?stop str =
    let stop = match stop with
      | None -> String.length str
      | Some x -> x
    in
    let len = stop - start in
    String.sub str start len

  let is_prefix ~prefix str =
    let pl = String.length prefix in
    if String.length str < pl then
      false
    else
      String.sub str 0 (String.length prefix) = prefix

  let is_suffix ~suffix str =
    let sl = String.length suffix in
    if String.length str < sl then
      false
    else
      String.sub str (String.length str - sl) sl = suffix

  let lowercase_char = function
    | 'A' .. 'Z' as c -> char_of_int (int_of_char c + 0x20)
    | c -> c

  let to_lower s =
    let last = pred (String.length s)
    and bs = Bytes.of_string s
    in
    for k = 0 to last do
      Bytes.set bs k (lowercase_char (Bytes.get bs k))
    done ;
    Bytes.to_string bs

  let ascii_char ?(p = fun _ -> false) = function
    | '0' .. '9'
    | 'A' .. 'Z'
    | 'a' .. 'z' -> true
    | x -> p x

  let is_ascii ?p s =
    let last = pred (String.length s) in
    let res = ref true in
    for k = 0 to last do
      res := !res && ascii_char ?p (String.get s k)
    done;
    !res

  let trim = String.trim

  let get = String.get

  let concat = String.concat

  let compare = String.compare

  let length = String.length

  let compare_insensitive a b =
    compare (to_lower a) (to_lower b) = 0
end

module Uint = struct
  type t = int64

  let zero = 0L

  let max = -1L (* this is 0xFFFFFFFFFFFFFFFF *)

  let compare a b =
    if a = b then
      0
    else if (a >= 0L && b >= 0L) || (a < 0L && b < 0L) then
      Int64.compare a b
    else if a < 0L then 1 else -1

  let succ x =
    if x = max then
      (true, 0L)
    else
      (false, Int64.succ x)

  let to_string s = Printf.sprintf "%LX" s

  let decimal s = Printf.sprintf "%Lu" s

  let of_string s =
    try Some (Int64.of_string ("0x" ^ s)) with Failure _ -> None

  let of_float f =
    if f < 0. then
      None
    else
      try Some (Int64.of_float f) with Failure _ -> None

  let of_int_exn i =
    if i < 0 then
      invalid_arg "cannot convert integers smaller than 0"
    else
      Int64.of_int i

  let of_int i = try Some (of_int_exn i) with Failure _ -> None
end

module S = Set.Make(String)

let s_of_list es = List.fold_left (fun s v -> S.add v s) S.empty es

module M = Map.Make(String)

type 'a fmt = Format.formatter -> 'a -> unit

(*BISECT-IGNORE-BEGIN*)
let pp_list pe ppf xs =
  match xs with
  | [] -> Format.pp_print_string ppf "empty"
  | xs ->
    Format.pp_print_string ppf "[" ;
    let rec p1 = function
      | [] -> Format.pp_print_string ppf "]" ;
      | [x] -> Format.fprintf ppf "%a]" pe x
      | x::xs -> Format.fprintf ppf "%a;@ " pe x ; p1 xs
    in
    p1 xs
(*BISECT-IGNORE-END*)
