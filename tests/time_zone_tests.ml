open Test_utils

module Qc = struct
  let to_of_json_string =
    QCheck.Test.make ~count:100_000 ~name:"to_of_json_string" time_zone
      (fun tz ->
         let tz' =
           tz
           |> Time_zone.to_json_string
           |> Time_zone.of_json_string
           |> CCResult.get_exn
         in
         Time_zone.equal tz tz')

  let suite = [ to_of_json_string ]
end
