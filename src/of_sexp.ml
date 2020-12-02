exception Invalid_data

let month_of_sexp (x : CCSexp.t) =
  match x with
  | `Atom s -> (
      match Time.month_of_abbr_string s with
      | Ok x -> x
      | Error () -> raise Invalid_data )
  | `List _ -> raise Invalid_data

let weekday_of_sexp (x : CCSexp.t) =
  match x with
  | `Atom s -> (
      match Time.weekday_of_abbr_string s with
      | Ok x -> x
      | Error () -> raise Invalid_data )
  | `List _ -> raise Invalid_data

let int_of_sexp (x : CCSexp.t) =
  match x with
  | `Atom s -> ( try int_of_string s with Failure _ -> raise Invalid_data )
  | `List _ -> raise Invalid_data

let ints_of_sexp_list (x : CCSexp.t) =
  match x with
  | `Atom _ -> raise Invalid_data
  | `List l -> List.map int_of_sexp l

let date_time_of_sexp (x : CCSexp.t) =
  match x with
  | `List
      [
        year;
        month;
        day;
        hour;
        minute;
        second;
        `List [ `Atom "tz_offset_s"; tz_offset_s ];
      ] -> (
      let year = int_of_sexp year in
      let month = month_of_sexp month in
      let day = int_of_sexp day in
      let hour = int_of_sexp hour in
      let minute = int_of_sexp minute in
      let second = int_of_sexp second in
      let tz_offset_s = int_of_sexp tz_offset_s in
      match
        Time.Date_time.make ~year ~month ~day ~hour ~minute ~second ~tz_offset_s
      with
      | Ok x -> x
      | Error _ -> raise Invalid_data )
  | _ -> raise Invalid_data

let timestamp_of_sexp x = x |> date_time_of_sexp |> Time.Date_time.to_timestamp

let range_of_sexp ~(f : CCSexp.t -> 'a) (x : CCSexp.t) =
  match x with
  | `List [ `Atom "range_inc"; x; y ] -> `Range_inc (f x, f y)
  | `List [ `Atom "range_exc"; x; y ] -> `Range_exc (f x, f y)
  | _ -> raise Invalid_data

let pattern_of_sexp (x : CCSexp.t) =
  match x with
  | `Atom _ -> raise Invalid_data
  | `List l -> (
      match l with
      | `Atom "pattern" :: l -> (
          let years, l =
            match l with
            | `List (`Atom "years" :: years) :: l ->
              (List.map int_of_sexp years, l)
            | _ -> ([], l)
          in
          let months, l =
            match l with
            | `List (`Atom "months" :: months) :: l ->
              (List.map month_of_sexp months, l)
            | _ -> ([], l)
          in
          let month_days, l =
            match l with
            | `List (`Atom "month_days" :: month_days) :: l ->
              (List.map int_of_sexp month_days, l)
            | _ -> ([], l)
          in
          let weekdays, l =
            match l with
            | `List (`Atom "weekdays" :: weekdays) :: l ->
              (List.map weekday_of_sexp weekdays, l)
            | _ -> ([], l)
          in
          let hours, l =
            match l with
            | `List (`Atom "hours" :: hours) :: l ->
              (List.map int_of_sexp hours, l)
            | _ -> ([], l)
          in
          let minutes, l =
            match l with
            | `List (`Atom "minutes" :: minutes) :: l ->
              (List.map int_of_sexp minutes, l)
            | _ -> ([], l)
          in
          let seconds, l =
            match l with
            | `List (`Atom "seconds" :: seconds) :: l ->
              (List.map int_of_sexp seconds, l)
            | _ -> ([], l)
          in
          match l with
          | [] ->
            Time.pattern ~years ~months ~month_days ~weekdays ~hours ~minutes
              ~seconds ()
          | _ -> raise Invalid_data )
      | _ -> raise Invalid_data )

let branching_of_sexp (x : CCSexp.t) =
  match x with
  | `Atom _ -> raise Invalid_data
  | `List l -> (
      match l with
      | `Atom "branching" :: l -> (
          let years, l =
            match l with
            | `List (`Atom "years" :: years) :: l ->
              (List.map (range_of_sexp ~f:int_of_sexp) years, l)
            | _ -> ([], l)
          in
          let months, l =
            match l with
            | `List (`Atom "months" :: months) :: l ->
              (List.map (range_of_sexp ~f:month_of_sexp) months, l)
            | _ -> ([], l)
          in
          let days, l =
            match l with
            | `List (`Atom "month_days" :: days) :: l ->
              ( Time.Month_days (List.map (range_of_sexp ~f:int_of_sexp) days),
                l )
            | `List (`Atom "weekdays" :: days) :: l ->
              ( Time.Weekdays
                  (List.map (range_of_sexp ~f:weekday_of_sexp) days),
                l )
            | _ -> (Time.Month_days [], l)
          in
          let hmss, l =
            match l with
            | `List (`Atom "hmss" :: hmss) :: l ->
              ( List.map
                  (range_of_sexp ~f:(fun x ->
                       match x with
                       | `List [ hour; minute; second ] ->
                         let open Time in
                         {
                           hour = int_of_sexp hour;
                           minute = int_of_sexp minute;
                           second = int_of_sexp second;
                         }
                       | _ -> raise Invalid_data))
                  hmss,
                l )
            | _ -> ([], l)
          in
          match l with
          | [] -> Time.branching ~years ~months ~days ~hmss ()
          | _ -> raise Invalid_data )
      | _ -> raise Invalid_data )

let of_sexp (x : CCSexp.t) =
  let open Time in
  let rec aux x =
    match x with
    | `List l -> (
        match l with
        | `Atom "intervals" :: l ->
          l
          |> List.map (fun x ->
              match x with
              | `List [ x; y ] -> (timestamp_of_sexp x, timestamp_of_sexp y)
              | _ -> raise Invalid_data)
          |> of_sorted_intervals ~skip_invalid:false
        | `Atom "pattern" :: _ -> pattern_of_sexp x
        | `Atom "branching" :: _ -> branching_of_sexp x
        | [ `Atom "not"; x ] -> not (aux x)
        | [ `Atom "every"; x ] -> aux x
        | [ `Atom "skip_n_points"; n; x ] ->
          skip_n_points (int_of_sexp n) (aux x)
        | [ `Atom "skip_n"; n; x ] -> skip_n (int_of_sexp n) (aux x)
        | [ `Atom "next_n_points"; n; x ] ->
          take_n_points (int_of_sexp n) (aux x)
        | [ `Atom "next_n"; n; x ] -> take_n (int_of_sexp n) (aux x)
        | _ -> raise Invalid_data )
    | _ -> raise Invalid_data
  in
  aux x
