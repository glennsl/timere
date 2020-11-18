open MParser
open Parser_components

type guess =
  | Dot
  | Comma
  | Hyphen
  | Colon
  | Star
  | Not
  | Outside
  | Of
  | In
  | To
  | From
  | Am
  | Pm
  | St
  | Nd
  | Rd
  | Th
  | Nat of int
  | Nats of int Time.Range.range list
  | Weekday of Time.weekday
  | Weekdays of Time.weekday Time.Range.range list
  | Month of Time.month
  | Months of Time.month Time.Range.range list

type token = (int * int * int) * guess

type binary_op =
  | Union
  | Inter

type ast =
  | Tokens of token list
  | Binary_op of binary_op * ast * ast
  | Round_robin_pick of ast list

let weekdays : (string * Time.weekday) list =
  [
    ("sunday", `Sun);
    ("monday", `Mon);
    ("tuesday", `Tue);
    ("wednesday", `Wed);
    ("thursday", `Thu);
    ("friday", `Fri);
    ("saturday", `Sat);
  ]

let months : (string * Time.month) list =
  [
    ("january", `Jan);
    ("february", `Feb);
    ("march", `Mar);
    ("april", `Apr);
    ("may", `May);
    ("june", `Jun);
    ("july", `Jul);
    ("august", `Aug);
    ("september", `Sep);
    ("october", `Oct);
    ("november", `Nov);
    ("december", `Dec);
  ]

let parse_weekday (s : string) : (Time.weekday, unit) Result.t =
  match Misc_utils.prefix_string_match weekdays s with
  | [ (_, x) ] -> Ok x
  | _ -> Error ()

let parse_month (s : string) : (Time.month, unit) Result.t =
  match Misc_utils.prefix_string_match months s with
  | [ (_, x) ] -> Ok x
  | _ -> Error ()

let weekday_p : (Time.weekday, unit) t =
  alpha_string
  >>= fun x ->
  match parse_weekday x with
  | Ok x -> return x
  | Error _ -> fail (Printf.sprintf "Failed to interpret weekday string")

let month_p : (Time.month, unit) t =
  alpha_string
  >>= fun x ->
  match parse_month x with
  | Ok x -> return x
  | Error _ -> fail (Printf.sprintf "Failed to interpret month string: %s" x)

let symbols = "()[]&|>"

let token_p : (token, unit) MParser.t =
  get_pos
  >>= fun pos ->
  choice
    [
      attempt (char '.') >>$ Dot;
      attempt (char ',') >>$ Comma;
      attempt (char '-') >>$ Hyphen;
      attempt (char ':') >>$ Colon;
      attempt (char '*') >>$ Star;
      attempt (string "not") >>$ Not;
      attempt (string "outside") >>$ Outside;
      attempt (string "of") >>$ Of;
      attempt (string "in") >>$ In;
      attempt (string "to") >>$ To;
      attempt (string "from") >>$ From;
      attempt (string "am") >>$ Am;
      attempt (string "AM") >>$ Am;
      attempt (string "pm") >>$ Pm;
      attempt (string "PM") >>$ Pm;
      attempt (string "st") >>$ St;
      attempt (string "nd") >>$ Nd;
      attempt (string "rd") >>$ Rd;
      attempt (string "th") >>$ Th;
      (attempt nat_zero |>> fun x -> Nat x);
      (attempt weekday_p |>> fun x -> Weekday x);
      (attempt month_p |>> fun x -> Month x);
      ( attempt (many1_satisfy (fun c -> not (String.contains symbols c)))
        >>= fun s ->
        fail (Printf.sprintf "%s: Unrecognized token: %s" (string_of_pos pos) s)
      );
    ]
  >>= fun guess -> spaces >> return (pos, guess)

let tokens_p = spaces >> many1 token_p << spaces

let inter : (ast -> ast -> ast, unit) t =
  string "&&" >> return (fun a b -> Binary_op (Inter, a, b))

let union : (ast -> ast -> ast, unit) t =
  string "||" >> return (fun a b -> Binary_op (Union, a, b))

let round_robin_pick : (ast -> ast -> ast, unit) t =
  string ">>" >> return (fun a b -> Round_robin_pick [ a; b ])

let expr =
  let rec expr mparser_state =
    let inter_part =
      attempt (char '(')
      >> (spaces >> expr << spaces << char ')')
         <|> (tokens_p |>> fun l -> Tokens l)
    in
    let ordered_select_part = chain_left1 inter_part round_robin_pick in
    let union_part = chain_left1 ordered_select_part inter in
    chain_left1 union_part union mparser_state
  in
  expr

module Ast_normalize = struct
  let group (type a) ~(extract_single : guess -> a option)
      ~(extract_grouped : guess -> a Time.Range.range list option)
      ~(constr_grouped : a Time.Range.range list -> guess) (l : token list) :
    token list =
    let rec recognize_single_interval tokens : token list =
      match tokens with
      | (pos_x, x) :: (pos_comma, Comma) :: rest -> (
          match extract_single x with
          | Some x ->
            (pos_x, constr_grouped [ `Range_inc (x, x) ])
            :: (pos_comma, Comma)
            :: recognize_single_interval rest
          | _ -> recognize_fallback tokens )
      | (pos_x, x) :: (_, To) :: (_, y) :: (pos_comma, Comma) :: rest -> (
          match (extract_single x, extract_single y) with
          | Some x, Some y ->
            (pos_x, constr_grouped [ `Range_inc (x, y) ])
            :: (pos_comma, Comma)
            :: recognize_single_interval rest
          | _, _ -> recognize_fallback tokens )
      | (pos_x, x) :: (_, To) :: (_, y) :: rest -> (
          match (extract_single x, extract_single y) with
          | Some x, Some y ->
            (pos_x, constr_grouped [ `Range_inc (x, y) ])
            :: recognize_single_interval rest
          | _, _ -> recognize_fallback tokens )
      | _ -> recognize_fallback tokens
    and recognize_fallback l =
      match l with
      | [] -> []
      | token :: rest -> token :: recognize_single_interval rest
    in
    let rec merge_intervals tokens : token list =
      match tokens with
      | (pos_x, x) :: (_, Comma) :: (_, y) :: rest -> (
          match (extract_grouped x, extract_grouped y) with
          | Some l1, Some l2 ->
            merge_intervals ((pos_x, constr_grouped (l1 @ l2)) :: rest)
          | _, _ -> merge_fallback tokens )
      | _ -> merge_fallback tokens
    and merge_fallback l =
      match l with [] -> [] | token :: rest -> token :: merge_intervals rest
    in
    l |> recognize_single_interval |> merge_intervals

  let group_nats (l : token list) : token list =
    group
      ~extract_single:(function Nat x -> Some x | _ -> None)
      ~extract_grouped:(function Nats l -> Some l | _ -> None)
      ~constr_grouped:(fun l -> Nats l)
      l

  let group_months (l : token list) : token list =
    group
      ~extract_single:(function Month x -> Some x | _ -> None)
      ~extract_grouped:(function Months l -> Some l | _ -> None)
      ~constr_grouped:(fun x -> Months x)
      l

  let group_weekdays (l : token list) : token list =
    group
      ~extract_single:(function Weekday x -> Some x | _ -> None)
      ~extract_grouped:(function Weekdays l -> Some l | _ -> None)
      ~constr_grouped:(fun x -> Weekdays x)
      l

  let group_tokens (e : ast) : ast =
    let rec aux e =
      match e with
      | Tokens l ->
        l |> group_nats |> group_weekdays |> group_months |> fun l -> Tokens l
      | Binary_op (op, e1, e2) -> Binary_op (op, aux e1, aux e2)
      | Round_robin_pick l -> Round_robin_pick (List.map aux l)
    in
    aux e

  let flatten_round_robin_select (e : ast) : ast =
    let rec aux e =
      match e with
      | Tokens _ -> e
      | Binary_op (op, e1, e2) -> Binary_op (op, aux e1, aux e2)
      | Round_robin_pick l ->
        l
        |> List.to_seq
        |> Seq.map aux
        |> Seq.flat_map (fun e ->
            match e with
            | Round_robin_pick l -> List.to_seq l
            | _ -> Seq.return e)
        |> List.of_seq
        |> fun l -> Round_robin_pick l
    in
    aux e

  let normalize (e : ast) : ast =
    e |> flatten_round_robin_select |> group_tokens
end

let parse_into_ast (s : string) : (ast, string) Result.t =
  parse_string
    ( expr
      << spaces
      >>= fun e ->
      get_pos
      >>= fun pos ->
      attempt eof
      >> return e
         <|> fail (Printf.sprintf "Expected EOI, pos: %s" (string_of_pos pos)) )
    s ()
  |> result_of_mparser_result

let rules : (token list -> (Time.t, string option) Result.t) list =
  let open Time in
  [
    (function [ (_, Star) ] -> Ok Time.any | _ -> Error None);
    (function
      | [ (_, Months l) ] ->
        Ok (Time.months (Time.Month_ranges.Flatten.flatten_list l))
      | _ -> Error None);
    (function
      | [ (_, Nat year); (_, Month month); (_, Nat day) ] when year > 31 ->
        Ok (pattern ~years:[ year ] ~months:[ month ] ~month_days:[ day ] ())
      | [ (_, Nat day); (_, Month month); (_, Nat year) ] when year > 31 ->
        Ok (pattern ~years:[ year ] ~months:[ month ] ~month_days:[ day ] ())
      | _ -> Error None);
    (function
      | [ (_, Nat year); (_, Month month); (_, Nat day); (pos_hour, Nat hour); (_, Pm) ] ->
        if 1 <= hour && hour <= 12 then
          let hour =
            (hour mod 12) + 12
          in
          Ok (pattern ~years:[ year ] ~months:[ month ] ~month_days:[ day ] ~hours:[ hour ] ())
        else
          Error (Some (Printf.sprintf "%s: Hour out of range: %d" (string_of_pos pos_hour) hour))
      | _ -> Error None);
  ]

let time_t_of_tokens (tokens : token list) : (Time.t, string) Result.t =
  let rec aux tokens rules =
    match rules with
    | [] ->
      let (pos, _) = List.hd tokens in
      Error (Printf.sprintf "%s: Unrecognized token pattern" (string_of_pos pos))
    | rule :: rest -> (
        match rule tokens with
        | Ok time -> Ok time
        | Error None -> aux tokens rest
        | Error (Some msg) -> Error msg
      )
  in
  aux tokens rules

let time_t_of_ast (ast : ast) : (Time.t, string) Result.t =
  let rec aux ast =
    match ast with
    | Tokens tokens -> time_t_of_tokens tokens
    | Binary_op (op, ast1, ast2) -> (
        match aux ast1 with
        | Error msg -> Error msg
        | Ok time1 -> (
            match aux ast2 with
            | Error msg -> Error msg
            | Ok time2 -> (
                match op with
                | Union -> Ok (Time.union time1 time2)
                | Inter -> Ok (Time.inter time1 time2) ) ) )
    | Round_robin_pick l -> (
        match l |> List.map aux |> Misc_utils.get_ok_error_list with
        | Error msg -> Error msg
        | Ok l -> Ok (Time.round_robin_pick l) )
  in
  aux ast

let parse s =
  match parse_into_ast s with
  | Error msg -> Error msg
  | Ok ast -> ast |> Ast_normalize.normalize |> time_t_of_ast
