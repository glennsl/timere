open Date_time_components

let pp_date_time ?(frac_s = 0) () formatter (dt : Time.Date_time'.t) =
  if frac_s < 0 then invalid_arg "pp_date_time: frac_s cannot be < 0"
  else if frac_s > 9 then invalid_arg "pp_date_time: frac_s cannot be > 9"
  else
    match tz_offset_s_of_tz_info dt.tz_info with
    | None -> raise (Printers.Date_time_cannot_deduce_tz_offset_s dt)
    | Some x ->
      let tz_off =
        if x = 0 then "Z"
        else
          let sign = if x < 0 then '-' else '+' in
          let offset = Duration.make ~seconds:(abs x) () in
          Printf.sprintf "%c%02d:%02d" sign offset.hours offset.minutes
      in
      if frac_s = 0 then
        Fmt.pf formatter "%04d-%02d-%02dT%02d:%02d:%02d%s" dt.year
          (human_int_of_month dt.month)
          dt.day dt.hour dt.minute dt.second tz_off
      else if frac_s = 9 then
        Fmt.pf formatter "%04d-%02d-%02dT%02d:%02d:%02d.%09d%s" dt.year
          (human_int_of_month dt.month)
          dt.day dt.hour dt.minute dt.second dt.ns tz_off
      else
        let second =
          Span.(to_float @@ make ~s:(Int64.of_int dt.second) ~ns:dt.ns ())
        in
        Fmt.pf formatter "%04d-%02d-%02dT%02d:%02d:%0*.*f%s" dt.year
          (human_int_of_month dt.month)
          dt.day dt.hour dt.minute (frac_s + 3) frac_s second tz_off

let of_date_time ?(frac_s = 0) (dt : Time.Date_time'.t) : string option =
  try Some (Fmt.str "%a" (pp_date_time ~frac_s ()) dt)
  with Printers.Date_time_cannot_deduce_tz_offset_s _ -> None

let pp_timestamp ?(frac_s = 0) () formatter (x : Span.t) =
  match Time.Date_time'.of_timestamp ~tz_of_date_time:Time_zone.utc x with
  | None -> invalid_arg "Invalid timestamp"
  | Some dt -> Fmt.pf formatter "%a" (pp_date_time ~frac_s ()) dt

let of_timestamp ?(frac_s = 0) (x : Span.t) : string =
  Fmt.str "%a" (pp_timestamp ~frac_s ()) x
