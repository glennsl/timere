open Js_of_ocaml

let js_date_of_timestamp x =
  let open Timere.Date_time in
  let dt = CCResult.get_exn @@ of_timestamp x in
  let date = new%js Js.date_now in
  (* let date = new%js Js.date_sec dt.year (Timere.Utils.tm_int_of_month dt.month) dt.day dt.hour dt.minute dt.second in *)
  let _ = date##setUTCFullYear dt.year in
  let _ = date##setUTCMonth (Timere.Utils.tm_int_of_month dt.month) in
  let _ = date##setUTCDate dt.day in
  let _ = date##setUTCHours dt.hour in
  let _ = date##setUTCMinutes dt.minute in
  let _ = date##setUTCSeconds dt.second in
  let _ = date##setUTCMilliseconds 0 in
  date

let list_of_js_array arr = arr |> Js.to_array |> Array.to_list

let js_array_of_list l = l |> Array.of_list |> Js.array

let raise_with_msg msg =
  Js.raise_js_error
    (
      new%js Js.error_constr (Js.string msg)
    )

let wrap f =
  try
    f ()
  with
  | Invalid_argument msg -> raise_with_msg msg

let _ =
  Js.export_all
    (object%js
      val always = Timere.always

      val empty = Timere.empty

      method years l = wrap (fun () -> Timere.years (list_of_js_array l))

      method months l =
        wrap (fun () ->
            list_of_js_array l |> List.map (fun x -> match Timere.Utils.month_of_human_int x with
                | Ok x -> x
                | Error () ->
                  raise_with_msg "Invalid month int"
              ) |> Timere.months
          )

      method monthDays l =
        wrap (fun () ->
            Timere.month_days (list_of_js_array l)
          )

      method weekdays l =
        wrap (fun () ->
            list_of_js_array l
            |> List.map (fun x ->
                match Timere.Utils.weekday_of_tm_int x with
                | Ok x -> x
                | Error () ->
                  raise_with_msg "Invalid weekday int"
              )
            |> Timere.weekdays
          )

      method hours l =
        wrap (fun () ->
            Timere.hours (list_of_js_array l)
          )

      method minutes l =
        wrap (fun () ->
            Timere.minutes (list_of_js_array l)
          )

      method seconds l =
        wrap (fun () ->
            Timere.seconds (list_of_js_array l)
          )

      method inter l =
        wrap (fun () ->
            Timere.inter (list_of_js_array l)
          )

      method union l =
        wrap (fun () ->
            Timere.union (list_of_js_array l)
          )

      method not x =
        wrap (fun () ->
            Timere.not x
          )

      val duration = object%js
        method d days =
          wrap (fun () ->
              Timere.Duration.make_frac ~days ()
            )

        method dh days hours =
          wrap (fun () ->
              Timere.Duration.make_frac ~days ~hours ()
            )

        method dhm days hours minutes =
          wrap (fun () ->
              Timere.Duration.make_frac ~days ~hours ~minutes ()
            )

        method dhms days hours minutes seconds =
          wrap (fun () ->
              Timere.Duration.make_frac ~days ~hours ~minutes ~seconds ()
            )

        method days x = Timere.Duration.(x.days)

        method hours x = Timere.Duration.(x.hours)

        method minutes x = Timere.Duration.(x.minutes)

        method seconds x = Timere.Duration.(x.seconds)
      end

      method shift dur x =
        wrap (fun () ->
            Timere.shift dur x
          )

      method lengthen dur x =
        wrap (fun () ->
            Timere.lengthen dur x
          )

      val timeZone =
        object%js
          method make name =
            wrap (fun () ->
                Timere.Time_zone.make_exn name
              )

          method name t =
            Timere.Time_zone.name t

          val utc = Timere.Time_zone.utc

          method equal t1 t2 =
            Js.bool
              @@
              Timere.Time_zone.equal t1 t2

          val available_time_zones =
            js_array_of_list
            Timere.Time_zone.available_time_zones

          method makeOffsetOnly offset =
            Timere.Time_zone.make_offset_only offset

          method toJSONString t =
            Timere.Time_zone.to_json_string t

          method ofJSONString s =
            match Timere.Time_zone.of_json_string (Js.to_string s) with
            | Error () -> raise_with_msg "Invalid JSON string"
            | Ok x -> x
        end

      method withTZ tz t =
        wrap (fun () ->
            Timere.with_tz tz t
          )

      method resolve t =
        match Timere.resolve ~search_using_tz:Timere.Time_zone.utc t with
        | Error msg -> raise_with_msg msg
        | Ok s ->
        let s =
          ref s
        in
        fun () ->
          wrap (fun () ->
              match !s () with
              | Seq.Nil -> Js.null
              | Seq.Cons ((x, y), rest) ->
                s := rest;
                Js.some
                  (Js.array [| js_date_of_timestamp x; js_date_of_timestamp y |])
            )
    end)
