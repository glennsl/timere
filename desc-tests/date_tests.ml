open Test_utils

module Qc = struct
  let view_is_same_as_original_iso_ord_date =
    QCheck.Test.make ~count:100_000 ~name:"view_is_same_as_original_iso_ord_date" iso_ord_date
      (fun (year', day_of_year') ->
         let d =
           Timedesc.Date.ISO_ord_date.make_exn ~year:year' ~day_of_year:day_of_year' in
         let { Timedesc.Date.ISO_ord_date.year; day_of_year } =
           Timedesc.Date.ISO_ord_date.view d
         in
         year = year' && day_of_year = day_of_year'
         )

  let view_is_same_as_original_iso_week_date =
    QCheck.Test.make ~count:100_000 ~name:"view_is_same_as_original_iso_week_date" iso_week_date
      (fun (iso_week_year', week', weekday') ->
         let d =
           Timedesc.Date.ISO_week_date.make_exn ~iso_week_year:iso_week_year'
             ~week:week' ~weekday:weekday'
         in
         let { Timedesc.Date.ISO_week_date.iso_week_year; week; weekday } =
           Timedesc.Date.ISO_week_date.view d
         in
         iso_week_year = iso_week_year' && week = week' && weekday = weekday'
         )

  let view_is_same_as_original_ymd_date =
    QCheck.Test.make ~count:100_000 ~name:"view_is_same_as_original_ymd_date" ymd_date (fun (year', month', day') ->
        let d =
          Timedesc.Date.Ymd_date.make_exn ~year:year' ~month:month' ~day:day' in
        let { Timedesc.Date.Ymd_date.year; month; day } =
          Timedesc.Date.Ymd_date.view d
        in
        year = year' && month = month' && day = day'
        )

  let suite =
    [ view_is_same_as_original_iso_ord_date; view_is_same_as_original_iso_week_date; view_is_same_as_original_ymd_date ]
end
