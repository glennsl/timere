open Time_ast
open Timestamp_utils

type timestamp = Timedesc.Span.t

type space = Time.Interval'.t list

let default_search_space_start = Timedesc.Timestamp.min_val

let default_search_space_end_exc = Timedesc.Timestamp.max_val

let default_space : space =
  [ (default_search_space_start, default_search_space_end_exc) ]

module Search_space : sig
  type t

  val default : t

  val empty : t

  val of_space : space -> t

  val to_space : t -> space
end = struct
  type t = space

  let default = default_space

  let empty = []

  let of_space x = x

  let to_space x = x
end

module Result_space : sig
  type t

  val default : t

  val of_space : space -> t

  val to_space : t -> space
end = struct
  type t = space

  let default = default_space

  let of_space x = x

  let to_space x = x
end

type t =
  | Empty
  | All
  | Intervals of Search_space.t * Time.Interval'.t Seq.t
  | Pattern of Search_space.t * Pattern.t
  | Bounded_intervals of {
      search_space : Search_space.t;
      pick : [ `Whole | `Snd ];
      bound : Timedesc.Span.t;
      start : Points.t;
      end_exc : Points.t;
    }
  | Unary_op of Result_space.t * unary_op * t
  | Inter_seq of Result_space.t * t Seq.t
  | Union_seq of Result_space.t * t Seq.t
  | Unchunk of Result_space.t * chunked

and chunked =
  | Unary_op_on_t of chunked_unary_op_on_t * t
  | Unary_op_on_chunked of chunked_unary_op_on_chunked * chunked

let rec t_of_ast (ast : Time_ast.t) : t =
  match ast with
  | Empty -> Empty
  | All -> All
  | Intervals s -> Intervals (Search_space.default, s)
  | Pattern p -> Pattern (Search_space.default, p)
  | Unary_op (op, t) -> Unary_op (Result_space.default, op, t_of_ast t)
  | Inter_seq s -> Inter_seq (Result_space.default, Seq.map t_of_ast s)
  | Union_seq s -> Union_seq (Result_space.default, Seq.map t_of_ast s)
  | Bounded_intervals { pick; bound; start; end_exc } ->
    Bounded_intervals
      { search_space = Search_space.default; pick; bound; start; end_exc }
  | Unchunk chunked ->
    Unchunk (Result_space.default, chunked_of_ast_chunked chunked)

and chunked_of_ast_chunked (c : Time_ast.chunked) : chunked =
  match c with
  | Unary_op_on_t (op, t) -> Unary_op_on_t (op, t_of_ast t)
  | Unary_op_on_chunked (op, chunked) ->
    Unary_op_on_chunked (op, chunked_of_ast_chunked chunked)

let search_space_of_result_space x =
  Search_space.of_space @@ Result_space.to_space x

let result_space_of_search_space x =
  Result_space.of_space @@ Search_space.to_space x

let get_result_space (time : t) : Result_space.t =
  match time with
  | All -> result_space_of_search_space Search_space.default
  | Empty -> result_space_of_search_space Search_space.empty
  | Intervals (s, _) -> result_space_of_search_space s
  | Pattern (s, _) -> result_space_of_search_space s
  | Bounded_intervals { search_space; _ } -> result_space_of_search_space search_space
  | Unary_op (r, _, _) -> r
  | Inter_seq (r, _) -> r
  | Union_seq (r, _) -> r
  | Unchunk (r, _) -> r

let get_search_space (time : t) : Search_space.t =

let search_space_of_result_space (time : t) (space : Result_space.t) : Search_space.t =
  let open Timedesc.Span in
  match time with
  | All | Empty | Intervals _ | Pattern _ -> space
  | Unary_op (_, op, _) -> (
      match op with
      | Shift n ->
        List.map
          (fun (x, y) ->
             if n >= zero then
               ( timestamp_safe_sub x n,
                 if y >= Timedesc.Timestamp.max_val then y
                 else timestamp_safe_sub y n )
             else
               ( (if x <= Timedesc.Timestamp.min_val then x
                  else timestamp_safe_sub x n),
                 timestamp_safe_sub y n ))
          space
      | Lengthen n ->
        space
        |> CCList.to_seq
        |> Seq.map (fun (x, y) ->
            let y =
              if y >= Timedesc.Timestamp.max_val then y
              else timestamp_safe_sub y n
            in
            (x, max x y))
        |> Time.Intervals.normalize
        |> CCList.of_seq
      | _ -> space)
  | Inter_seq _ | Union_seq _ -> space
  | Bounded_intervals { bound; _ } -> (
      match space with
      | [] -> []
      | (x, y) :: rest -> (timestamp_safe_sub x bound, y) :: rest)
  | Unchunk _ -> space

let set_search_space space (time : t) : t =
  match time with
  | All -> All
  | Empty -> Empty
  | Intervals (_, x) -> Intervals (space, x)
  | Pattern (_, x) -> Pattern (space, x)
  | Unary_op (_, op, x) -> Unary_op (space, op, x)
  | Inter_seq (_, x) -> Inter_seq (space, x)
  | Union_seq (_, x) -> Union_seq (space, x)
  | Bounded_intervals { search_space = _; pick; bound; start; end_exc } ->
    Bounded_intervals { search_space = space; pick; bound; start; end_exc }
  | Unchunk (_, c) -> Unchunk (space, c)

(* let get_result_space (time : t) : search_space =
 *   let search_space =
 *     get_search_space time
 *   in
 *   match time with
 *   | All
 *   | Empty
 *   | Intervals _
 *   | Pattern _
 *     ->
 *     search_space
 *   | Unary_op (_, op, _) -> (
 *       match op with
 *       | Not
 *       | With_tz _ ->
 *         search_space
 *       | Shift n ->
 *         List.map (fun (x, y) ->
 *             (timestamp_safe_add x n, timestamp_safe_add y n))
 *           search_space
 *       | Lengthen n ->
 *         search_space
 *         |> CCList.to_seq
 *         |> Seq.map (fun (x, y) -> (x, timestamp_safe_add y n))
 *         |> Time.Intervals.normalize
 *         |> CCList.of_seq
 *     )
 *   | Inter_seq (_, s) ->
 *   | _ -> failwith "Unimplemented" *)

let search_space_of_year_range tz year_range =
  let aux_start start =
    if start = Timedesc.(year min_val) then Timedesc.Timestamp.min_val
    else
      Timedesc.make_exn ~tz ~year:start ~month:1 ~day:1 ~hour:0 ~minute:0
        ~second:0 ()
      |> Timedesc.to_timestamp
      |> Timedesc.min_of_local_result
  in
  let aux_end_inc end_exc =
    if end_exc = Timedesc.(year max_val) then Timedesc.Timestamp.max_val
    else
      Timedesc.make_exn ~tz ~year:end_exc ~month:12 ~day:31 ~hour:23 ~minute:59
        ~second:59
        ~ns:(Timedesc.Span.ns_count_in_s - 1)
        ()
      |> Timedesc.to_timestamp
      |> Timedesc.max_of_local_result
      |> Timedesc.Span.succ
  in
  let aux_end_exc end_exc =
    Timedesc.make_exn ~tz ~year:end_exc ~month:1 ~day:1 ~hour:0 ~minute:0
      ~second:0 ()
    |> Timedesc.to_timestamp
    |> Timedesc.min_of_local_result
  in
  match year_range with
  | `Range_inc (start, end_inc) -> (aux_start start, aux_end_inc end_inc)
  | `Range_exc (start, end_exc) -> (aux_start start, aux_end_exc end_exc)

let search_space_of_year tz year =
  search_space_of_year_range tz (`Range_inc (year, year))

let empty_search_space = []

let overapproximate_search_space_bottom_up default_tz (time : t) : t =
  let open Time in
  let rec aux (tz : Timedesc.Time_zone.t) (time : t) : t =
    match time with
    | All -> All
    | Empty -> Empty
    | Intervals (_, s) -> (
        match s () with
        | Seq.Nil -> time
        | Seq.Cons ((start, _), _) ->
          Intervals ([ (start, default_search_space_end_exc) ], s))
    | Pattern (_, pat) ->
      if Int_set.is_empty pat.years then Pattern (default_search_space, pat)
      else
        let space =
          pat.years
          |> Int_set.to_seq
          |> Seq.map (search_space_of_year tz)
          |> CCList.of_seq
        in
        Pattern (space, pat)
    | Unary_op (_, op, t) -> (
        match op with
        | Not -> Unary_op (default_search_space, op, aux tz t)
        | With_tz tz ->
          let t = aux tz t in
          Unary_op (get_search_space t, op, t)
        | Shift n ->
          let space =
            get_search_space t
            |> List.map (fun (x, y) ->
                (timestamp_safe_add x n, timestamp_safe_add y n))
          in
          Unary_op (space, op, t)
        | Lengthen n ->
          let space =
            get_search_space t
            |> CCList.to_seq
            |> Seq.map (fun (x, y) -> (x, timestamp_safe_add y n))
            |> Time.Intervals.normalize
            |> CCList.of_seq
          in
          Unary_op (space, op, t))
    | Inter_seq (_, s) ->
      let s = Seq.map (aux tz) s in
      let space =
        s
        |> Seq.map get_search_space
        |> Seq.map CCList.to_seq
        |> Seq.map (Intervals.normalize ~skip_sort:true)
        |> Intervals.Inter.inter_multi_seq ~skip_check:true
        |> CCList.of_seq
      in
      Inter_seq (space, s)
    | Union_seq (_, s) ->
      let space, s = aux_seq tz s in
      Union_seq (space, s)
    | Bounded_intervals { search_space = _; pick; bound; start; end_exc } ->
      let search_space =
        match
          Points.to_date_time
            ~default_tz_info:
              (CCResult.get_exn @@ Timedesc.Time_zone_info.make ~tz ())
            start
        with
        | None -> default_search_space
        | Some dt ->
          let space_start =
            dt |> Timedesc.to_timestamp |> Timedesc.min_of_local_result
          in
          let space_end_exc =
            dt
            |> Timedesc.to_timestamp
            |> Timedesc.max_of_local_result
            |> Timedesc.Span.add bound
          in
          [ (space_start, space_end_exc) ]
      in
      Bounded_intervals { search_space; pick; bound; start; end_exc }
    | Unchunk (_, c) -> Unchunk (aux_chunked tz c, c)
  and aux_chunked tz chunked : search_space =
    match chunked with
    | Unary_op_on_t (_op, time) ->
      let t = aux tz time in
      get_search_space t
    | Unary_op_on_chunked (_op, chunked) -> aux_chunked tz chunked
  and aux_seq tz s =
    let s = Seq.map (aux tz) s in
    let space =
      Seq.map get_search_space s
      |> Seq.map CCList.to_seq
      |> Intervals.Union.union_multi_seq
      |> CCList.of_seq
    in
    (space, s)
  in
  aux default_tz time

let restrict_search_space_top_down (time : t) : t =
  let open Time in
  let restrict_search_space time (parent : search_space) (cur : search_space) =
    parent
    |> search_space_of_result_space time
    |> CCList.to_seq
    |> Intervals.Inter.inter ~skip_check:true (CCList.to_seq cur)
    |> CCList.of_seq
  in
  let rec aux parent_search_space (time : t) : t =
    let stop_propagation = time in
    match time with
    | All -> All
    | Empty -> Empty
    | Intervals (cur, _) ->
      set_search_space
        (restrict_search_space time parent_search_space cur)
        time
    | Pattern (cur, _) ->
      set_search_space
        (restrict_search_space time parent_search_space cur)
        time
    | Unary_op (cur, op, t) -> (
        match op with
        | _ ->
          let space = restrict_search_space time parent_search_space cur in
          set_search_space space (Unary_op (cur, op, aux space t)))
    | Inter_seq (cur, s) ->
      let space = restrict_search_space time parent_search_space cur in
      set_search_space space (Inter_seq (cur, aux_seq space s))
    | Union_seq (cur, s) ->
      let space = restrict_search_space time parent_search_space cur in
      set_search_space space (Union_seq (cur, aux_seq space s))
    | Bounded_intervals { search_space = cur; pick; bound; start; end_exc } ->
      let space = restrict_search_space time parent_search_space cur in
      set_search_space space
        (Bounded_intervals { search_space = cur; pick; bound; start; end_exc })
    | Unchunk (_, _) -> stop_propagation
  and aux_seq parent_search_space l = Seq.map (aux parent_search_space) l in
  aux default_search_space time

let optimize_search_space default_tz t =
  t
  |> overapproximate_search_space_bottom_up default_tz
  |> restrict_search_space_top_down

type inc_or_exc =
  | Inc
  | Exc

let do_chunk_at_year_boundary tz (s : Time.Interval'.t Seq.t) =
  let rec aux s =
    match s () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((t1, t2), rest) ->
      let dt1 =
        CCOpt.get_exn_or "Expected successful date time construction"
        @@ Timedesc.of_timestamp ~tz_of_date_time:tz t1
      in
      let dt2 =
        t2
        |> Timedesc.Span.pred
        |> Timedesc.of_timestamp ~tz_of_date_time:tz
        |> CCOpt.get_exn_or "Expected successful date time construction"
      in
      let dt1_year = Timedesc.year dt1 in
      if dt1_year = Timedesc.year dt2 then fun () ->
        Seq.Cons ((t1, t2), aux rest)
      else
        let t' =
          Timedesc.make_exn ~tz ~year:dt1_year ~month:12 ~day:31 ~hour:23
            ~minute:59 ~second:59
            ~ns:(Timedesc.Span.ns_count_in_s - 1)
            ()
          |> Timedesc.to_timestamp
          |> Timedesc.max_of_local_result
          |> Timedesc.Span.succ
        in
        fun () ->
          Seq.Cons ((t1, t'), aux (fun () -> Seq.Cons ((t', t2), rest)))
  in
  aux s

let do_chunk_at_month_boundary tz (s : Time.Interval'.t Seq.t) =
  let rec aux s =
    match s () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((t1, t2), rest) ->
      let dt1 =
        CCOpt.get_exn_or "Expected successful date time construction"
        @@ Timedesc.of_timestamp ~tz_of_date_time:tz t1
      in
      let dt1_year = Timedesc.year dt1 in
      let dt2 =
        t2
        |> Timedesc.Span.pred
        |> Timedesc.of_timestamp ~tz_of_date_time:tz
        |> CCOpt.get_exn_or "Expected successful date time construction"
      in
      if
        dt1_year = Timedesc.year dt2
        && Timedesc.month dt1 = Timedesc.month dt2
      then fun () -> Seq.Cons ((t1, t2), aux rest)
      else
        let t' =
          Timedesc.make_exn ~year:dt1_year ~month:12 ~day:31 ~hour:23
            ~minute:59 ~second:59
            ~ns:(Timedesc.Span.ns_count_in_s - 1)
            ()
          |> Timedesc.to_timestamp
          |> Timedesc.max_of_local_result
          |> Timedesc.Span.succ
        in
        fun () ->
          Seq.Cons ((t1, t'), aux (fun () -> Seq.Cons ((t', t2), rest)))
  in
  aux s

let dynamic_search_space_adjustment_trigger_size =
  Timedesc.Span.For_human.(make_exn ~days:30 ())

let inter_slice_size = Timedesc.Span.For_human.(make_exn ~days:10 ())

let slice_search_space ~start (t : t) : t =
  let current = get_search_space t |> CCList.to_seq in
  let restriction =
    Time.Intervals.Slice.slice ~skip_check:true ~start
      (CCList.to_seq default_search_space)
    |> CCList.of_seq
    |> search_space_of_result_space t
    |> CCList.to_seq
  in
  let space = Time.Intervals.Inter.inter current restriction |> CCList.of_seq in
  set_search_space space t |> restrict_search_space_top_down

let slice_search_space_multi ~start (l : t list) : t list =
  List.map (slice_search_space ~start) l

let slice_search_space_multi_seq ~start (s : t Seq.t) : t Seq.t =
  Seq.map (slice_search_space ~start) s

let normalize s =
  s
  |> Time.Intervals.normalize ~skip_filter_empty:false ~skip_filter_invalid:true
    ~skip_sort:true
  |> Time.slice_valid_interval

let aux_pattern search_using_tz space pat =
  let open Time in
  let space = CCList.to_seq space in
  Timedesc.Time_zone.Raw.to_transition_seq search_using_tz
  |> Seq.flat_map (fun ((x, y), entry) ->
      let x = Timedesc.Span.make ~s:x () in
      let y = Timedesc.Span.make ~s:y () in
      let space = Intervals.Inter.inter (Seq.return (x, y)) space in
      let params =
        Seq.map
          (Pattern_resolver.Search_param.make
             ~search_using_offset_from_utc_s:
               Timedesc.Time_zone.(entry.offset))
          space
      in
      Intervals.Union.union_multi_seq ~skip_check:true
        (Seq.map (fun param -> Pattern_resolver.resolve param pat) params))

let one_s = Timedesc.Span.make ~s:1L ()

let aux_points search_using_tz space (p : Points.t) : timestamp Seq.t =
  let search_using_tz =
    match p.tz_info with
    | None -> search_using_tz
    | Some { Timedesc.Time_zone_info.tz; _ } -> tz
  in
  aux_pattern search_using_tz space (Points.to_pattern p)
  |> Seq.filter_map (fun (x, y) ->
      assert (Timedesc.Span.(y - x <= one_s));
      if x.ns = 0 then Some x else None)

let rec aux search_using_tz time =
  let open Time in
  (match get_search_space time with
   | [] -> Seq.empty
   | _ -> (
       match time with
       | Empty -> Seq.empty
       | All -> CCList.to_seq default_search_space
       | Intervals (_, s) -> s
       | Pattern (space, pat) -> aux_pattern search_using_tz space pat
       | Unary_op (space, op, t) -> (
           let search_using_tz =
             match op with With_tz x -> x | _ -> search_using_tz
           in
           let s = aux search_using_tz t in
           match op with
           | Not ->
             Intervals.relative_complement ~skip_check:false ~not_mem_of:s
               (CCList.to_seq space)
           | Shift n ->
             Seq.map
               (fun (start, end_exc) -> Timedesc.Span.(start + n, end_exc + n))
               s
           | Lengthen n ->
             s
             |> Seq.map (fun (start, end_exc) ->
                 Timedesc.Span.(start, end_exc + n))
           | With_tz _ -> s)
       | Inter_seq (_, s) -> aux_inter search_using_tz s
       | Union_seq (_, s) -> aux_union search_using_tz s
       | Bounded_intervals { search_space; pick; bound; start; end_exc } ->
         aux_bounded_intervals search_using_tz search_space pick bound start
           end_exc
       | Unchunk (_, c) -> aux_chunked search_using_tz c))
  |> normalize

and get_points_after_start1 ~start1 ~(s2 : timestamp Seq.t) ~(p2 : Points.t)
    search_using_tz space : timestamp Seq.t * search_space =
  match s2 () with
  | Seq.Nil -> (Seq.empty, space)
  | Seq.Cons (start2, _) ->
    let open Timedesc.Span in
    if
      start2 < start1
      && start1 - start2 >= dynamic_search_space_adjustment_trigger_size
    then
      let space =
        space
        |> CCList.to_seq
        |> Time.Intervals.Slice.slice ~start:(succ start1)
        |> CCList.of_seq
      in
      (aux_points search_using_tz space p2, space)
    else (OSeq.drop_while (fun start2 -> start2 <= start1) s2, space)

and skip_points_in_p1 ~last_start2 ~(rest1 : timestamp Seq.t) ~(p1 : Points.t)
    search_using_tz bound space : timestamp Seq.t * search_space =
  let open Timedesc.Span in
  match rest1 () with
  | Seq.Nil -> (Seq.empty, space)
  | Seq.Cons (start1, _) ->
    let distance = last_start2 - start1 in
    if
      start1 <= last_start2
      && distance >= bound
      && distance >= dynamic_search_space_adjustment_trigger_size
    then
      let search_start = last_start2 - bound in
      let space =
        space
        |> CCList.to_seq
        |> Time.Intervals.Slice.slice ~start:search_start
        |> CCList.of_seq
      in
      (aux_points search_using_tz space p1, space)
    else (rest1, space)

and aux_bounded_intervals search_using_tz space pick bound p1 p2 =
  let _, search_space_end_exc =
    CCOpt.get_exn_or "Expected successful retrieval of last element in list"
    @@ Misc_utils.last_element_of_list space
  in
  let rec aux_bounded_intervals' s1 s2 space1 space2 p1 p2 =
    match s1 () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons (start1, rest1) -> (
        let open Timedesc.Span in
        if search_space_end_exc <= start1 then Seq.empty
        else
          let s2, space2 =
            get_points_after_start1 ~start1 ~s2 ~p2 search_using_tz space2
          in
          match s2 () with
          | Seq.Nil -> Seq.empty
          | Seq.Cons (start2, _rest2) ->
            if search_space_end_exc <= start2 then Seq.empty
            else if start2 - start1 <= bound then
              let interval =
                match pick with
                | `Whole -> (start1, start2)
                | `Snd -> (start2, succ start2)
              in
              fun () ->
                Seq.Cons
                  ( interval,
                    aux_bounded_intervals' rest1 s2 space1 space2 p1 p2 )
            else
              let s1, space1 =
                skip_points_in_p1 ~last_start2:start2 ~rest1 ~p1
                  search_using_tz bound space1
              in
              aux_bounded_intervals' s1 s2 space1 space2 p1 p2)
  in
  aux_bounded_intervals'
    (aux_points search_using_tz space p1)
    (aux_points search_using_tz space p2)
    space space p1 p2

and aux_union search_using_tz timeres =
  let open Time in
  let resolve_and_merge (s : t Seq.t) : Interval'.t Seq.t =
    Seq.map (aux search_using_tz) s
    |> Time.Intervals.Merge.merge_multi_seq ~skip_check:true
  in
  let rec aux_union' (timeres : t Seq.t) (intervals : Interval'.t Seq.t) =
    match intervals () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((start, end_exc), rest) ->
      let open Timedesc.Span in
      let size = end_exc - start in
      if size >= dynamic_search_space_adjustment_trigger_size then
        let timeres = slice_search_space_multi_seq ~start:end_exc timeres in
        let next_intervals =
          resolve_and_merge timeres
          |> OSeq.drop_while (fun x -> Time.Interval'.le x (start, end_exc))
        in
        fun () ->
          Seq.Cons ((start, end_exc), aux_union' timeres next_intervals)
      else fun () -> Seq.Cons ((start, end_exc), aux_union' timeres rest)
  in
  aux_union' timeres (resolve_and_merge timeres)

and aux_inter search_using_tz timeres =
  let open Time in
  let slice_batches ~start batches =
    List.map (Intervals.Slice.slice ~skip_check:true ~start) batches
  in
  let resolve ~start search_using_tz timeres =
    timeres |> List.map (aux search_using_tz) |> slice_batches ~start
  in
  let collect_batch (l : Interval'.t Seq.t list) : Interval'.t option list =
    List.map
      (fun s -> match s () with Seq.Nil -> None | Seq.Cons (x, _) -> Some x)
      l
  in
  let rec aux_inter' ~start (timeres : t list) =
    let interval_batches = resolve ~start search_using_tz timeres in
    let batch_for_sampling = collect_batch interval_batches in
    if List.exists CCOpt.is_none batch_for_sampling then Seq.empty
    else
      let batch_for_sampling =
        CCList.map
          (CCOpt.get_exn_or "Unexpected None in batch_for_sampling")
          batch_for_sampling
      in
      match batch_for_sampling with
      | [] -> Seq.empty
      | _ ->
        let open Timedesc.Span in
        let rightmost_interval =
          batch_for_sampling
          |> List.sort_uniq (fun x y -> Time.Interval'.compare y x)
          |> List.hd
        in
        let rightmost_start = fst rightmost_interval in
        let end_exc = rightmost_start + inter_slice_size in
        (* we shift the start of our scope to rightmost_start *)
        let timeres =
          slice_search_space_multi ~start:rightmost_start timeres
        in
        (* refresh the interval batches if the gap is too large *)
        let interval_batches =
          if
            rightmost_start - start
            >= dynamic_search_space_adjustment_trigger_size
          then resolve ~start:rightmost_start search_using_tz timeres
          else slice_batches ~start:rightmost_start interval_batches
        in
        let intervals_up_to_end_exc =
          interval_batches
          |> CCList.to_seq
          |> Seq.map (Intervals.Slice.slice ~skip_check:true ~end_exc)
          |> Intervals.Inter.inter_multi_seq ~skip_check:true
        in
        fun () ->
          Seq.Cons (intervals_up_to_end_exc, aux_inter' ~start:end_exc timeres)
  in
  aux_inter' ~start:default_search_space_start (CCList.of_seq timeres)
  |> Seq.flat_map CCFun.id

and aux_chunked search_using_tz (chunked : chunked) =
  let open Time in
  let chunk_based_on_op_on_t op s =
    match op with
    | Chunk_disjoint_interval -> normalize s
    | Chunk_by_duration { chunk_size; drop_partial } ->
      Intervals.chunk ~skip_check:true ~drop_partial ~chunk_size s
    | Chunk_at_year_boundary -> do_chunk_at_year_boundary search_using_tz s
    | Chunk_at_month_boundary -> do_chunk_at_month_boundary search_using_tz s
  in
  match chunked with
  | Unary_op_on_t (op, t) -> aux search_using_tz t |> chunk_based_on_op_on_t op
  | Unary_op_on_chunked (op, c) -> (
      let s = aux_chunked search_using_tz c in
      match op with
      | Nth n -> s |> OSeq.drop n |> OSeq.take 1
      | Drop n -> OSeq.drop n s
      | Take n -> OSeq.take n s
      | Take_nth n -> OSeq.take_nth n s
      | Chunk_again op -> chunk_based_on_op_on_t op s)

let resolve' ~search_using_tz (time : t) :
  (Time.Interval'.t Seq.t, string) result =
  let open Time in
  try
    Ok (time |> optimize_search_space search_using_tz |> aux search_using_tz)
  with
  | Interval_is_invalid -> Error "Invalid interval"
  | Intervals_are_not_sorted -> Error "Intervals are not sorted"

let resolve ?(search_using_tz = Timedesc.Time_zone.utc) (time : Time_ast.t) :
  (Time.Interval'.t Seq.t, string) result =
  resolve' ~search_using_tz (t_of_ast time)
