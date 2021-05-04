(** {1 Introduction}

    It is advised to read through this to understand why certain API seem needlessly complicated
    compared to alternatives (possibly in another programming language).

    {2 Misconceptions}

    - Time zone offsets are always in hours
    - What we typically consider a time zone, e.g. "Europe/Paris", always has a constant offset
    - With a time zone and a specific date time, we can obtain a unique "unix timestamp" (time since unix epoch)
    - We can calculate time zone offset at some date time, and apply it universally for any other date time in the same time zone, and this always works
    - Many more on various online resources...

    {2 Time zone, time zone offset, and date time}

    It is tempting to think that a time zone maps cleanly to a constant offset, and
    indeed we may define time zone as such, e.g. UTC+1, UTC-10, but this is far from what we mean
    in everyday context.

    Very often, what we consider to be time zone actually represents a table which records what offset to use
    in which period, which we index/refer to by geographical names like "Europe/Paris", "Australia/Sydney".
    These tables are defined by governmental bodies, and attributes of the table, such as offset of
    any particular period, start and end of any particular period, may not show any observable pattern.

    Thus it is not uncommon to see date time errors arising from attempts of applying some formulas universally,
    which might work well for a lot of cases in contemporary time periods, but fail for some combinations.

    We make explicit of above explanation by considering "Europe/Paris" as an example, which observes
    a common form of transition called Daylight Saving Time (DST).

    When DST starts (usually in March), the clocks "jump forward" by 1 hour,
    usually jumping from 2am to 3am, leading 2am to 3am (exclusive) to
    become non-existent.

    Indeed we can observe the lack of continuity of Europe/Paris timeline below (UTC timeline is always continuous):

    {v
                         Mar
UTC          -------------|-------------
                         1am

Europe/Paris -------------|-------------
                       2am 3am
                      (+1) (+2)
v}

    Paris time zone offset also changes from UTC+1 to UTC+2.

    When DST ends (usually in Oct), clocks "jump backward" by 1 hour, usually jumping from 3am to 2am, leading to
    2am to 3am (exclusive) becoming duplicated:

    {v
                         Oct
UTC          -------------|-------------
                         1am

Europe/Paris -------------|-------------
                       3am 2am
                      (+2) (+1)
v}

    Paris time zone offset also changes from UTC+2 to UTC+1.

    Another way of looking at above is when DST is in effect, Paris observes UTC+2, and UTC+1 otherwise:

    {v
                          |-------------DST on------------|
             |---DST off--|                               |---DST off--|

                         Mar                             Oct
UTC          -------------|------------- ... -------------|-------------
                         1am                             1am

Europe/Paris -------------|------------- ... -------------|-------------
                       2am 3am                         3am 2am
                      (+1) (+2)                       (+2) (+1)
v}

    This start and end of the DST on and off periods, along with the corresponding offsets,
    form the basis of the table we mentioned above.

    {2 Timere date time API basics}

    We highlight some critical cases in practice, and how Timere behaves and how it may differ from other libraries.

    Take year 2021 for example, DST starts on 2021 Mar 28 for Paris, causing clocks to jump from 2am to 3am. Pick any
    intermediate point, say 2:30am, we yield an undefined date time. In this case, Timere refuses the construction
    of such {!Date_time.t} in {!Date_time.make} etc, while some libraries coerce the result into 3:30am.

    And DST ends on 2021 Oct 31,
    causing clocks to jump from 3am to 2am. Say we pick 2:30am again, we are actually pointing at {e two} time points (there are two 2:30am)
    unless we make an explicit selection between the first or second occurance.
    Whenever ambiguity of this form is a possiblity for the result of a function, say {!Date_time.to_timestamp},
    Timere uses {!Date_time.local_result} variant type, of which [`Single _] indicates lack of ambiguity for the particular result,
    and [`Ambiguous _] indicates the result is ambiguous.

    Some other libraries coerce the ambiguous result
    into one of the two possible choices (which exact one may not be guaranteed). If user wishes to do similar coercions,
    they may use {!Date_time.min_of_local_result} or {!Date_time.max_of_local_result}.

    For constructions, {!Date_time.make} yields a possibly ambiguous construction,
    while {!Date_time.make_unambiguous} yields an unambiguous construction.
    In general, if you are provided with the exact offset to UTC,
    then [make_unambiguous] is the better choice.
*)
(** {1 Span} *)

module Span : sig
  type t = private {
    s : int64;
    ns : int;
  }
  (** Signed/directional span of time expressed as a tuple of [(s, ns)]
      - [s] is the signed second of the span
      - [ns] is the unsigned nanosecond offset

      The actual span represented is defined as [s * 10^9 + ns] in nanosecond, regardless of the sign of [s]

      Order is defined using lexicographic order, i.e.
      [lt x y iff. x.s < y.s || (x.s = y.s && x.ns < y.ns)]
  *)

  module For_human : sig
    type sign =
      [ `Pos
      | `Neg
      ]

    type view = private {
      sign : sign;
      days : int;
      hours : int;
      minutes : int;
      seconds : int;
      ns : int;
    }

    type error =
      [ `Invalid_days of int
      | `Invalid_hours of int
      | `Invalid_minutes of int
      | `Invalid_seconds of int
      | `Invalid_ns of int
      ]

    type error_f =
      [ `Invalid_days_f of float
      | `Invalid_hours_f of float
      | `Invalid_minutes_f of float
      | `Invalid_seconds_f of float
      | `Invalid_ns of int
      ]

    exception Error_exn of error

    exception Error_f_exn of error_f

    val make :
      ?sign:sign ->
      ?days:int ->
      ?hours:int ->
      ?minutes:int ->
      ?seconds:int ->
      ?ns:int ->
      unit ->
      (t, error) result
    (**
       [sign] defaults to [`Pos].

       Returns [Error] if any of the arguments are negative.
    *)

    val make_exn :
      ?sign:sign ->
      ?days:int ->
      ?hours:int ->
      ?minutes:int ->
      ?seconds:int ->
      ?ns:int ->
      unit ->
      t
    (** @raise Error_exn if [make] fails *)

    val make_frac :
      ?sign:sign ->
      ?days:float ->
      ?hours:float ->
      ?minutes:float ->
      ?seconds:float ->
      ?ns:int ->
      unit ->
      (t, error_f) result
    (**
       [sign] defaults to [`Pos].

       Returns [Error] if any of the arguments are negative
    *)

    val make_frac_exn :
      ?sign:sign ->
      ?days:float ->
      ?hours:float ->
      ?minutes:float ->
      ?seconds:float ->
      ?ns:int ->
      unit ->
      t
    (** @raise Error_exn if [make] fails *)

    val view : t -> view

    val pp : Format.formatter -> t -> unit

    val to_string : t -> string
  end

  val ns_count_in_s : int

  val ns_count_in_s_float : float

  val zero : t

  val make : ?s:int64 -> ?ns:int -> unit -> t
  (** [s] defaults to [0L], [ns] defaults to [0]

      [ns] may be negative, and is normalized during construction

      Interpretation of provided input is still [s + ns], i.e. if you wish to
      represent "negative (1 second and 500 nanosecond)", then the call could look like
      [make ~s:(-1L) ~ns:(-500)]
  *)

  val make_small : ?s:int -> ?ns:int -> unit -> t
  (** Wrapper around [make] *)

  val add : t -> t -> t

  val sub : t -> t -> t

  val succ : t -> t

  val pred : t -> t

  val neg : t -> t

  val abs : t -> t

  val equal : t -> t -> bool

  val lt : t -> t -> bool

  val le : t -> t -> bool

  val gt : t -> t -> bool

  val ge : t -> t -> bool

  val compare : t -> t -> int

  val to_float : t -> float

  val of_float : float -> t

  val max : t -> t -> t

  val min : t -> t -> t

  val ( < ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( >= ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( <> ) : t -> t -> bool

  val ( - ) : t -> t -> t

  val ( + ) : t -> t -> t

  val to_string : t -> string

  val pp : Format.formatter -> t -> unit

  val to_sexp : t -> CCSexp.t

  val to_sexp_string : t -> string

  val of_sexp : CCSexp.t -> (t, string) result

  val of_sexp_string : string -> (t, string) result

  val pp_sexp : Format.formatter -> t -> unit
end

(** {1 Date time handling} *)

type weekday =
  [ `Sun
  | `Mon
  | `Tue
  | `Wed
  | `Thu
  | `Fri
  | `Sat
  ]

exception Invalid_format_string of string
(** Printing exception *)

type timestamp = Span.t

module Time_zone : sig
  type t

  val make : string -> t option
  (** Makes a time zone from name.

      Naming follows the convention used in [/usr/share/zoneinfo/posix/] distributed on Linux, e.g. "Australia/Sydney".

      See {!val:available_time_zones} or checking usable time zone names at runtime.

      Alternatively, if you are using [timere.tz.full] (the default implementation for [timere.tz.data]), then you can also see
      {{:https://github.com/daypack-dev/timere/tree/main/gen_artifacts/available-time-zones.txt} [available-time-zones.txt]} for available time zones.

      [make] handles names with "UTC" prefix specially, following holds regardless of DB backend chosen
      - "UTC" is alway interpreted as [utc]
      - "UTC+/-offset" is always interpreted as call to [make_offset_only] with the provided signed offset
  *)

  val make_exn : string -> t
  (** @raise Invalid_argument if [make] fails *)

  val name : t -> string

  val utc : t

  val local : unit -> t option

  val local_exn : unit -> t
  (** @raise Invalid_argument when [local] returns [None] *)

  val equal : t -> t -> bool

  val available_time_zones : string list

  val make_offset_only : Span.t -> t option
  (** This is mainly used for when you only have an offset to work with,
      and you don't need to do any accurate search over time zones.

      One use of this is to create a time zone for [to_string] functions.

      Returns [None] when offset exceeds 24 hours
  *)

  val make_offset_only_exn : Span.t -> t

  val to_fixed_offset : t -> Span.t option

  (** {2 Importing and exporting}*)

  type entry = {
    is_dst : bool;
    offset : int;
  }

  module Raw : sig
    val of_transitions : name:string -> (int64 * entry) list -> t option

    val to_transitions : t -> ((int64 * int64) * entry) list

    val to_transition_seq : t -> ((int64 * int64) * entry) Seq.t
  end

  module Sexp : sig
    val to_sexp : t -> CCSexp.t

    val of_sexp : CCSexp.t -> t option

    val of_string : string -> t option
  end

  module JSON : sig
    val to_json : t -> Yojson.Basic.t

    val of_json : Yojson.Basic.t -> t option

    val of_string : string -> t option
  end

  module Db : sig
    type db

    val empty : db

    val add : t -> db -> db

    val find_opt : string -> db -> t option

    val remove : string -> db -> db

    val of_seq : t Seq.t -> db

    val add_seq : db -> t Seq.t -> db

    val names : db -> string list

    module Raw : sig
      val dump : db -> string

      val load : string -> db
    end

    module Sexp : sig
      val of_sexp : CCSexp.t -> db option

      val to_sexp : db -> CCSexp.t

      val of_string : string -> db option
    end
  end
end

module Date_time : sig
  (** This module uses ptime underneath, and carries similar limitation of expressible range of date times.
      The actual range is slightly more limited in Timere due to time zones.
  *)

  type t = private {
    year : int;
    month : int;
    day : int;
    hour : int;
    minute : int;
    second : int;
    ns : int;
    tz_info : tz_info;
  }
  (** This is the main date time type, and represents a point in the local time line
      with respect to the residing time zone. Conceptually a pair of "date" and "time of day".

      A [t] always maps to at least one point on the UTC time line, and [make] fails if this is not the case.
      [t] may also map to two points on the UTC time line in the case of DST and without
      an unambiguous offset, however.

      In the ambiguous case, functions which return [_ local_result] will yield an [`Ambiguous _]
      value, and [`Single _] otherwise.

      [ns] may be [>= 10^9] to represent leap second, but always remains [< 2 * 10^9].

      [s] is always [>= 0] and [< 60], even when second 60 is used during construction.
      In other words, second 60 is represented via [ns] field.
  *)

  and tz_info = {
    tz : Time_zone.t;
    offset : Span.t option;
  }
  (** Time zone information of date time

      [tz] is the time zone tied. This is always defined even if only an offset provided during construction -
      if say only offset of 10 hours is provided, [tz] becomes "UTC+10".

      [offset] provides an unambiguous specification
      of which timestamp/point the date time maps to on the UTC time line.
      [offset] is defined if an offset is provided during construction via {!make_unambiguous}
      or if an unambiguous offset can be deduced during construction via {!make}.

      In other words, [offset] is [None] exactly when it is not possible to assign an offset,
      and [Some _] otherwise.
  *)

  type error =
    [ `Does_not_exist
    | `Invalid_year of int
    | `Invalid_month of int
    | `Invalid_day of int
    | `Invalid_hour of int
    | `Invalid_minute of int
    | `Invalid_second of int
    | `Invalid_frac of float
    | `Invalid_ns of int
    | `Invalid_tz_info of string option * Span.t
    ]

  exception Error_exn of error

  val string_of_error : error -> string

  val make :
    ?tz:Time_zone.t ->
    ?ns:int ->
    ?frac:float ->
    year:int ->
    month:int ->
    day:int ->
    hour:int ->
    minute:int ->
    second:int ->
    unit ->
    (t, error) result
  (** Constructs a date time providing only a time zone (defaults to local time zone).

      Nanosecond used is the addition of [ns] and [frac * 10^9].

      A precise offset is inferred if possible.

      Note that this may yield a ambiguous date time if the time zone has varying offsets,
      causing a local date time to appear twice, e.g. countries with DST.

      See {!val:make_unambiguous} for the more precise construction.

      Leap second can be specified by providing 60 for [second].
      Note that leap second informtation is lost upon translation to timestamp(s),
      specifically second 60 is treated as second 59.

      Returns [Error `Invalid_year] if [year < 0 || 9999 < year].

      Returns [Error `Invalid_month] if [month < 1 || 12 < month].

      Returns [Error `Invalid_day] if [day < 1 || 31 < day].

      Returns [Error `Invalid_hour] if [hour > 23].

      Returns [Error `Invalid_minute] if [minute > 59].

      Returns [Error `Invalid_second] if [second > 60].

      Returns [Error `Invalid_ns] if [frac < 0.0].

      Returns [Error `Invalid_ns] if [ns < 0].

      Returns [Error `Invalid_ns] if [total ns >= 10^9].

      Returns [Error `Invalid_tz_info] if offset is out of range.
  *)

  val make_exn :
    ?tz:Time_zone.t ->
    ?ns:int ->
    ?frac:float ->
    year:int ->
    month:int ->
    day:int ->
    hour:int ->
    minute:int ->
    second:int ->
    unit ->
    t
  (** @raise Error_exn if [make] fails *)

  val make_unambiguous :
    ?tz:Time_zone.t ->
    ?ns:int ->
    ?frac:float ->
    year:int ->
    month:int ->
    day:int ->
    hour:int ->
    minute:int ->
    second:int ->
    tz_offset:Span.t ->
    unit ->
    (t, error) result
  (** Constructs a date time providing time zone offset in seconds, and optionally a time zone.

      Nanosecond used is the addition of [ns] and [frac * 10^9].

      If a time zone is provided, then [tz_offset] is checked against the time zone record,
      and returns [Error `Invalid_tz_info] if [tz_offset] is not a possible
      offset for the particular date time in said time zone.

      As an example, for "UTC+1", you would give a duration of positive 1 hour for `tz_offset`.

      Otherwise same leap second handling and error handling as [make].
  *)

  val make_unambiguous_exn :
    ?tz:Time_zone.t ->
    ?ns:int ->
    ?frac:float ->
    year:int ->
    month:int ->
    day:int ->
    hour:int ->
    minute:int ->
    second:int ->
    tz_offset:Span.t ->
    unit ->
    t
  (** @raise Error_exn if [make_umabiguous] fails *)

  val is_leap_second : t -> bool

  type 'a local_result =
    [ `Single of 'a
    | `Ambiguous of 'a * 'a
    ]
  (** Result for when a local date time may be involved, e.g. using a date time with no precise time zone offset attached.

      - [`Single] is yielded when the date time maps to exactly one ['a].
        This happens when date time carries an accurate offset,
        or when the date time is not affected by any offset shifts (thus an accurate offset can be inferred).
      - [`Ambiguous] is yielded when date time maps to more than one (exactly two) ['a].
        This happens when DST ends and "goes back an hour" for instance.
  *)

  val to_timestamp : t -> timestamp local_result
  (** [to_timestamp] loses information about leap second
  *)

  val to_timestamp_single : t -> timestamp
  (** @raise Invalid_argument if [to_timestamp] does not yield a [`Single] result *)

  val to_timestamp_float : t -> float local_result

  val to_timestamp_float_single : t -> float
  (** @raise Invalid_argument if [to_timestamp_single] does not yield a [`Single] result *)

  val min_of_local_result : 'a local_result -> 'a

  val max_of_local_result : 'a local_result -> 'a

  val of_timestamp : ?tz_of_date_time:Time_zone.t -> timestamp -> t option

  val of_timestamp_exn : ?tz_of_date_time:Time_zone.t -> timestamp -> t

  val of_timestamp_float : ?tz_of_date_time:Time_zone.t -> float -> t option

  val of_timestamp_float_exn : ?tz_of_date_time:Time_zone.t -> float -> t

  val equal : t -> t -> bool

  val min_val : t

  val max_val : t

  val now : ?tz_of_date_time:Time_zone.t -> unit -> t

  val to_weekday : t -> weekday

  exception Date_time_cannot_deduce_tz_offset_s of t

  val pp : ?format:string -> unit -> Format.formatter -> t -> unit
  (**
     Pretty printing for date time.

     Default format string:
     {v
{year} {mon:Xxx} {day:0X} {hour:0X}:{min:0X}:{sec:0X} \
{tzoff-sign}{tzoff-hour:0X}:{tzoff-min:0X}:{tzoff-sec:0X}
     v}

     Format string specification:
     {v
{{               literal {
{year}           year
{mon:Xxx}        abbreviated month name (e.g. Jan), casing of 'x' controls the casing
{mon:Xx*}        full month name (e.g. January), casing of first 'x' controls casing of first letter,
                 casing of second 'x' controls casing of following letters
{mon:cX}         month in number form (e.g. 01) character 'c' before 'X' is used for padding
                 (leave out character for no padding)
{day:cX}        month day (e.g.  1) character 'c' before 'X' is used for padding
                 (leave out character for no padding)
{wday:Xxx}       abbreviated weekday name (e.g. Sun), the casing of 'x' controls the casing
{wday:Xx*}       full weekday name (e.g. Sunday), casing of first 'x' controls casing of first letter,
                 casing of second 'x' controls casing of following letters
{hour:cX}        hour in 24-hour format, character 'c' before 'X' determines padding
                 (leave out character for no padding)
{12hour:cX}      hour in 12-hour format, character 'c' before 'X' determines padding
                 (leave out character for no padding)
{min:cX}         minute, character 'c' before 'X' determines padding
                 (leave out character for no padding)
{sec:cX}         second, character 'c' before 'X' determines padding
                 (leave out character for no padding)
{ns}             nanosecond
{sec-frac:N}     fraction of second (only digits)
                 N determines the number of digits to take after decimal point
                 result is rounded to closest fraction of said precision
{tzoff-sign}     time zone offset sign ('+' or '-')
                 raises Date_time_cannot_deduce_tz_offset_s if time zone offset cannot be calculated
{tzoff-hour:cX}  time zone offset hour, follows same padding rule as "{hour:cX}"
                 raises Date_time_cannot_deduce_tz_offset_s if time zone offset cannot be calculated
{tzoff-min:cX}   time zone offset minute, follows same padding rule as "{min:cX}"
                 raises Date_time_cannot_deduce_tz_offset_s if time zone offset cannot be calculated
{tzoff-sec:cX}   time zone offset second, follows same padding rule as "{sec:cX}"
                 raises Date_time_cannot_deduce_tz_offset_s if time zone offset cannot be calculated
     v}
  *)

  val to_string : ?format:string -> t -> string option
  (**
     String conversion using [pp].

     Returns [None] instead of raising exception when time zone offset cannot be deduced but required by the format string
  *)

  val pp_rfc3339 : ?frac_s:int -> unit -> Format.formatter -> t -> unit
  (**
     Pretty prints according to RFC3339, e.g. [2020-01-20T13:00:00.0001+10].

     [frac_s] defaults to as many digits as required for a lossless representation.

     @raise Invalid_argument if [frac_s < 0 || frac_s > 9]

     @raise Date_time_cannot_deduce_tz_offset_s if time zone offset cannot be calculated
  *)

  val pp_rfc3339_milli : Format.formatter -> t -> unit

  val pp_rfc3339_micro : Format.formatter -> t -> unit

  val pp_rfc3339_nano : Format.formatter -> t -> unit

  val to_rfc3339 : ?frac_s:int -> t -> string option
  (** String conversion using [pp_rfc3339].

      Returns [None] if time zone offset cannot be deduced instead of raising exception.
  *)

  val to_rfc3339_milli : t -> string option

  val to_rfc3339_micro : t -> string option

  val to_rfc3339_nano : t -> string option

  val of_iso8601 : string -> (t, string) result
  (**
     Parses a subset of ISO8601, up to 9 fractional digits for second (nanosecond precision).

     If more than 9 fractional digits are provided, then only the first 9 digits are used, i.e. no rounding.
  *)

  val to_sexp : t -> CCSexp.t

  val to_sexp_string : t -> string

  val of_sexp : CCSexp.t -> (t, string) result

  val of_sexp_string : string -> (t, string) result

  val pp_sexp : Format.formatter -> t -> unit
end

module Timestamp : sig
  val min_val : timestamp

  val max_val : timestamp

  val now : unit -> timestamp

  val pp :
    ?display_using_tz:Time_zone.t ->
    ?format:string ->
    unit ->
    Format.formatter ->
    timestamp ->
    unit
  (** Pretty printing for timestamp.

      Follows same format string rules and default format string as {!val:Date_time.to_string}.
  *)

  val to_string :
    ?display_using_tz:Time_zone.t -> ?format:string -> timestamp -> string

  val pp_rfc3339 : ?frac_s:int -> unit -> Format.formatter -> timestamp -> unit
  (**
     Pretty prints according to RFC3339, e.g. [2020-01-20T13:00:00.0001+10].

     [frac_s] determines the number of fractional digits to include.

     @raise Invalid_argument if [frac_s < 0 || frac_s > 9]
  *)

  val pp_rfc3339_milli : Format.formatter -> timestamp -> unit

  val pp_rfc3339_micro : Format.formatter -> timestamp -> unit

  val pp_rfc3339_nano : Format.formatter -> timestamp -> unit

  val to_rfc3339 : ?frac_s:int -> timestamp -> string

  val to_rfc3339_milli : timestamp -> string

  val to_rfc3339_micro : timestamp -> string

  val to_rfc3339_nano : timestamp -> string

  val of_iso8601 : string -> (timestamp, string) result
  (**
     Parses a subset of ISO8601, up to 9 fractional digits for second (nanosecond precision).

     If more than 9 fractional digits are provided, then only the first 9 digits are used, i.e. no rounding.
  *)
end

module Week_date_time : sig
  type t = private {
    year : int;
    week : int;
    weekday : weekday;
    hour : int;
    minute : int;
    second : int;
    ns : int;
    tz_info : Date_time.tz_info;
  }

  type error =
    [ `Does_not_exist
    | `Invalid_year of int
    | `Invalid_week of int
    | `Invalid_hour of int
    | `Invalid_minute of int
    | `Invalid_second of int
    | `Invalid_frac of float
    | `Invalid_ns of int
    | `Invalid_tz_info of string option * Span.t
    ]

  exception Error_exn of error

  val make :
    ?tz:Time_zone.t ->
    ?ns:int ->
    ?frac:float ->
    year:int ->
    week:int ->
    weekday:weekday ->
    hour:int ->
    minute:int ->
    second:int ->
    unit ->
    (t, error) result

  val make_exn :
    ?tz:Time_zone.t ->
    ?ns:int ->
    ?frac:float ->
    year:int ->
    week:int ->
    weekday:weekday ->
    hour:int ->
    minute:int ->
    second:int ->
    unit ->
    t
end

(** {1 Reasoning/scheduling} *)

type t
(** This is the core type of Timere that represents sets of points in time, more precisely,
    unions of time intervals. For example, "all Mondays of year 2000 at the UTC timezone".

    We call [Timere.t] values "timere object"; internally they are rich
    expressions representing the time computations (union, intersection,
    etc.), lazily forced into more low-level descriptions (lazy sequences
    of intervals).
*)

type 'a range =
  [ `Range_inc of 'a * 'a
  | `Range_exc of 'a * 'a
  ]

(** {2 Basic constructors} *)

val now : unit -> t
(** Time right now *)

val always : t
(** Entire interval that Timere can handle, i.e. [\[0000 Jan 01 14:00:00 +00:00:00, 9999 Dec 31 09:59:58 +00:00:00)] *)

val empty : t
(** Empty interval *)

val pattern :
  ?years:int list ->
  ?year_ranges:int range list ->
  ?months:int list ->
  ?month_ranges:int range list ->
  ?days:int list ->
  ?day_ranges:int range list ->
  ?weekdays:weekday list ->
  ?weekday_ranges:weekday range list ->
  ?hours:int list ->
  ?hour_ranges:int range list ->
  ?minutes:int list ->
  ?minute_ranges:int range list ->
  ?seconds:int list ->
  ?second_ranges:int range list ->
  unit ->
  t
(** Pattern matches over date times.

    A pattern [p] matches date time [dt] if
    {v
(dt.year is in p.years or p.year_ranges)
&& (dt.month is in p.months or p.month_ranges)
&& (dt.month_day is in p.month_days or p.month_day_ranges)
&& (dt.weekday is in p.weekdays or p.weekday_ranges)
&& (dt.hour is in p.hours or p.hour_ranges)
&& (dt.minute is in p.minutes or p.minute_ranges)
&& (dt.second is in p.seconds or p.second_ranges)
    v}

    Empty pattern levels are treated as wildcard, e.g. if [p.years] and [p.year_ranges] are both empty,
    then [(dt.year is in p.years or p.year_ranges)] is [true].
*)

val years : int list -> t
(** [years l] is a shorthand for [pattern ~years:l ()] *)

val year_ranges : int range list -> t
(** [year_ranges l] is a shorthand for [pattern ~year_ranges:l ()] *)

val months : int list -> t
(** [months l] is a shorthand for [pattern ~months:l ()] *)

val month_ranges : int range list -> t
(** [month_ranges l] is a shorthand for [pattern ~month_ranges:l ()] *)

val days : int list -> t
(** [days l] is a shorthand for [pattern ~month_days:l ()] *)

val day_ranges : int range list -> t
(** [day_ranges l] is a shorthand for [pattern ~month_day_ranges:l ()] *)

val weekdays : weekday list -> t
(** [weekdays l] is a shorthand for [pattern ~weekdays:l ()] *)

val weekday_ranges : weekday range list -> t
(** [weekday_ranges l] is a shorthand for [pattern ~weekday_ranges:l ()] *)

val hours : int list -> t
(** [hours l] is a shorthand for [pattern ~hours:l ()] *)

val hour_ranges : int range list -> t
(** [hour_ranges l] is a shorthand for [pattern ~hour_ranges:l ()] *)

val minutes : int list -> t
(** [minutes l] is a shorthand for [pattern ~minutes:l ()] *)

val minute_ranges : int range list -> t
(** [minute_ranges l] is a shorthand for [pattern ~minute_ranges:l ()] *)

val seconds : int list -> t
(** [seconds l] is a shorthand for [pattern ~seconds:l ()] *)

val second_ranges : int range list -> t
(** [second_ranges l] is a shorthand for [pattern ~second_ranges:l ()] *)

val nth_weekday_of_month : int -> weekday -> t
(** [nth_weekday_of_month n wday] picks the nth weekday of all months, where [1 <= n && n <= 5]

    @raise Invalid_argument if [n] is out of range
*)

(** {2 Algebraic operations} *)

val inter : t list -> t
(** Intersection of list of timeres.

    [inter []] is equivalent to [always].
*)

val union : t list -> t
(** Union of list of timeres.

    [union []] is equivalent to [empty].
*)

val not : t -> t
(** Negation of timere.

    [not t] is equivalent to all the intervals not included in [t].
*)

val shift : Span.t -> t -> t

val lengthen : Span.t -> t -> t
(** @raise Invalid_argument if duration is negative *)

val with_tz : Time_zone.t -> t -> t
(** [with_tz tz t] changes the time zone to evaluate [t] in to [tz] *)

val date_time : Date_time.t -> t

val before : Date_time.t -> t

val since : Date_time.t -> t

val after : Date_time.t -> t

val date_times : Date_time.t list -> t

val date_time_seq : Date_time.t Seq.t -> t

val sorted_date_times : Date_time.t list -> t

val sorted_date_time_seq : Date_time.t Seq.t -> t

exception Invalid_timestamp

val timestamp : timestamp -> t

val before_timestamp : timestamp -> t

val since_timestamp : timestamp -> t

val after_timestamp : timestamp -> t

val timestamps : ?skip_invalid:bool -> timestamp list -> t
(** [timestamps l]

    [skip_invalid] defaults to [false]

    @raise Invalid_timestamp if [not skip_invalid] and [l] contains an invalid timestamp
*)

val timestamp_seq : ?skip_invalid:bool -> timestamp Seq.t -> t
(** [timestamps s]

    [skip_invalid] defaults to [false]

    @raise Invalid_timestamp if [not skip_invalid] and [s] contains an invalid timestamp
*)

val sorted_timestamps : ?skip_invalid:bool -> timestamp list -> t

val sorted_timestamp_seq : ?skip_invalid:bool -> timestamp Seq.t -> t

(** {2 Intervals} *)

(** {3 Explicit} *)

exception Interval_is_invalid

exception Intervals_are_not_sorted

module Interval : sig
  type t = timestamp * timestamp

  val equal : t -> t -> bool

  val lt : t -> t -> bool

  val le : t -> t -> bool

  val gt : t -> t -> bool

  val ge : t -> t -> bool

  val compare : t -> t -> int

  val pp :
    ?display_using_tz:Time_zone.t ->
    ?format:string ->
    unit ->
    Format.formatter ->
    t ->
    unit
  (** Pretty printing for interval.

        Default format string:
      {v
[{syear} {smon:Xxx} {sday:0X} {shour:0X}:{smin:0X}:{ssec:0X} \
{stzoff-sign}{stzoff-hour:0X}:{stzoff-min:0X}:{stzoff-sec:0X}, {eyear} \
{emon:Xxx} {eday:0X} {ehour:0X}:{emin:0X}:{esec:0X} \
{etzoff-sign}{etzoff-hour:0X}:{etzoff-min:0X}:{etzoff-sec:0X})
    v}

        Follows same format string rules as {!val:Date_time.to_string}, but tags are prefixed with 's' for "start time", and 'e' for "end exc time",
        e.g. for interval [(x, y)]

      - [{syear}] gives year of the [x]
      - [{ehour:cX}] gives hour of the [y]
  *)

  val to_string : ?display_using_tz:Time_zone.t -> ?format:string -> t -> string
end

val intervals : ?skip_invalid:bool -> Interval.t list -> t
(** [intervals l]

    [skip_invalid] defaults to [false]

    @raise Interval_is_invalid if [not skip_invalid] and [l] contains an invalid interval
*)

val interval_seq : ?skip_invalid:bool -> Interval.t Seq.t -> t
(** [interval_seq s]

    [skip_invalid] defaults to [false]

    @raise Interval_is_invalid if [not skip_invalid] and [s] contains an invalid interval
*)

val sorted_intervals : ?skip_invalid:bool -> Interval.t list -> t
(** [sorted_intervals l]

    [skip_invalid] defaults to [false]

    @raise Interval_is_invalid if [not skip_invalid] and [l] contains an invalid interval
    @raise Intervals_are_not_sorted if [l] is not sorted
*)

val sorted_interval_seq : ?skip_invalid:bool -> Interval.t Seq.t -> t
(** [sorted_interval_seq s]

    [skip_invalid] defaults to [false]

    @raise Interval_is_invalid if [not skip_invalid] and [s] contains an invalid interval
    @raise Intervals_are_not_sorted if [s] is not sorted
*)

(** {2 Pattern matching} *)

(** Pattern matching intervals are designed to handle intervals where start and end points follow some pattern, but cannot be captured by [pattern] efficiently,
    e.g. you cannot represent "5:30pm to 6:11pm" via a single [pattern]
*)

module Points : sig
  type t

  type error =
    [ `Invalid_year of int
    | `Invalid_day of int
    | `Invalid_hour of int
    | `Invalid_minute of int
    | `Invalid_second of int
    | `Invalid_pattern_combination
    | `Invalid_tz_info of string option * Span.t
    ]

  exception Error_exn of error

  val make :
    ?tz:Time_zone.t ->
    ?tz_offset:Span.t ->
    ?year:int ->
    ?month:int ->
    ?day:int ->
    ?weekday:weekday ->
    ?hour:int ->
    ?minute:int ->
    second:int ->
    unit ->
    (t, error) result
  (** [make_points] call must be exactly one of the following forms (ignoring [tz] and [tz_offset_s] which are optional in all cases)
      {v
make_points ~year:_ ~month:_ ~day:_     ~hour:_ ~minute:_ ~second:_ ()
make_points         ~month:_ ~day:_     ~hour:_ ~minute:_ ~second:_ ()
make_points                  ~day:_     ~hour:_ ~minute:_ ~second:_ ()
make_points                  ~weekday:_ ~hour:_ ~minute:_ ~second:_ ()
make_points                             ~hour:_ ~minute:_ ~second:_ ()
make_points                                     ~minute:_ ~second:_ ()
make_points                                               ~second:_ ()
    v}

      returns [Error] otherwise
  *)

  val make_exn :
    ?tz:Time_zone.t ->
    ?tz_offset:Span.t ->
    ?year:int ->
    ?month:int ->
    ?day:int ->
    ?weekday:weekday ->
    ?hour:int ->
    ?minute:int ->
    second:int ->
    unit ->
    t
    (** @raise Error_exn if [make] fails *)
end

type points = Points.t

val bounded_intervals : [ `Whole | `Snd ] -> Span.t -> points -> points -> t
(** [bounded_intervals mode bound p1 p2] for each point [x] matched by [p1],
    then for the earliest point [y] matched by [p2] such that [x < y && y - x <= bound]
    - if [mode = `Whole], yields (x, y)
    - if [mode = `Snd], yields (y, y + 1)

    Examples:

    {[
      bounded_intervals `Whole (Span.For_human.make ~days:1 ())
        (make_points ~hour:13 ~minute:0 ~second:0 ()) (* p1 *)
        (make_points ~hour:14 ~minute:0 ~second:0 ()) (* p2 *)
    ]}
    yields all the "1pm to 2pm" intervals, since at each "1pm" mark represented by [p1],
    searching forward up to 24 hour period, we can find a "2pm" mark in [p2]

    {[
      bounded_intervals `Whole (Span.For_human.make ~days:1 ())
        (make_points ~month:2 ~day:10 ~hour:13 ~minute:0 ~second:0 ()) (* p1 *)
        (make_points                  ~hour:14 ~minute:0 ~second:0 ()) (* p2 *)
    ]}
    yields all the "Feb 10th 1pm to 2pm" intervals (or specifically "Feb 10th 1pm to Feb 10th 2pm")

    {[
      bounded_intervals `Whole (Span.For_human.make ~days:1 ())
        (make_points ~month:`Feb ~day:10 ~hour:23 ~minute:0 ~second:0 ()) (* p1 *)
        (make_points                     ~hour:3  ~minute:0 ~second:0 ()) (* p2 *)
    ]}
    yields all the "Feb 10th 11pm to 3am" intervals (or specifically "Feb 10th 11pm to Feb 11th 3am")

    @raise Invalid_argument if bound is negative

    @raise Invalid_argument if precision (number of date time arguments passed to [make_points] during construction)
    of [p1] < precision of [p2]

    For example, [make_points_exn ~hour:3 ~minute:0 ~second:0 ()]
    has a lower precision than [make_points_exn ~day:10 ~hour:12 ~minute:30 ~second:0 ()]
*)

(** {2 Hour minute second intervals} *)

(** Convenience wrappers around [points] and [bounded_intervals] *)

module Hms : sig
  type t = private {
    hour : int;
    minute : int;
    second : int;
  }

  type error =
    [ `Invalid_hour of int
    | `Invalid_minute of int
    | `Invalid_second of int
    ]

  exception Error_exn of error

  val make : hour:int -> minute:int -> second:int -> (t, error) result

  val make_exn : hour:int -> minute:int -> second:int -> t
  (** @raise Error_exn if [make] fails *)

  val pp : Format.formatter -> t -> unit

  val to_string : t -> string

  val to_second_of_day : t -> int

  val of_second_of_day : int -> t option
end

val hms_intervals_inc : Hms.t -> Hms.t -> t
(** Same as [hms_intervals_exc ...] with end point increased by one second
*)

val hms_intervals_exc : Hms.t -> Hms.t -> t
(** Same as [bounded_intervals ...] with bound fixed to [Span.For_human.make ~days:1 ()]
*)

(** {2 Chunking} *)

type chunked

type chunking =
  [ `Disjoint_intervals
  | `By_duration of Span.t
  | `By_duration_drop_partial of Span.t
  | `At_year_boundary
  | `At_month_boundary
  ]
(** Ways to chunk/slice time intervals for the selector.

    - [`Disjoint_intervals] gives a sequence of disjoint intervals to the selector,
      specifically they are in ascending order, non-overlapping, non-connecting, and unique
    - [`By_duration] slices in the fixed size specified by the duration.
      Partial chunks (chunks less than the fixed size) are preserved.
    - [`By_duration_drop_partial] slices in the fixed size specified by the duration.
      Partial chunks (chunks less than the fixed size) are discarded.
    - [`At_year_boundary] slices at the year boundary (e.g. [2021 Jan 1st 00:00:00])
    - [`At_month_boundary] slices at the month boundary (e.g. [Aug 1st 00:00:00])
*)

val chunk : chunking -> (chunked -> chunked) -> t -> t
(** [chunk chunking f t] applies [chunked] selector [f] on [t].

    @raise Invalid_argument if duration is negative in [`By_duration]
    or [`By_duration_drop_partial]
*)

(** {3 Chunked selectors} *)

(** You may find {!val:(%>)} useful for chaining selectors together, e.g. [drop 5 %> take 2]
*)

val chunk_again : chunking -> chunked -> chunked
(** [chunk_again chunking f] applies [chunked] selector [f] as a selector*)

val first : chunked -> chunked
(** Takes only first chunk *)

val take : int -> chunked -> chunked
(** Takes n chunks *)

val take_nth : int -> chunked -> chunked
(** Take every nth chunk, specifically [0]th, [n]th, [2n]th, [3n]th, ... *)

val drop : int -> chunked -> chunked
(** Discard n chunks *)

(** {2 Infix operators} *)

val ( & ) : t -> t -> t
(** {!val:inter} *)

val ( ||| ) : t -> t -> t
(** {!val:union} *)

val ( %> ) : ('a -> 'b) -> ('b -> 'c) -> 'a -> 'c
(** Composition, mainly for chunked selectors

    [f1 %> f2] is equivalent to [fun x -> x |> f1 |> f2].
*)

(** {2 Resolution} *)

val resolve :
  ?search_using_tz:Time_zone.t -> t -> (Interval.t Seq.t, string) result
(** Resolves a Timere object into a concrete interval sequence *)

(** {2 Pretty printers} *)

val pp_intervals :
  ?display_using_tz:Time_zone.t ->
  ?format:string ->
  ?sep:unit Fmt.t ->
  unit ->
  Format.formatter ->
  Interval.t Seq.t ->
  unit

(** {2 S-expressions} *)

(** These functions are suitable for debugging, serializing and deserializing timeres.

    The sexp is a precise description of the steps used to construct a timere.
    As such deserialization is accurate and goes through the exact same construction steps (including validation)
    as one would using the construction API directly.
*)

val to_sexp : t -> CCSexp.t

val to_sexp_string : t -> string

val of_sexp : CCSexp.t -> (t, string) result

val of_sexp_string : string -> (t, string) result

val pp_sexp : Format.formatter -> t -> unit

(** {1 Misc} *)

module Utils : sig
  (** {1 Month utils} *)

  type month =
    [ `Jan
    | `Feb
    | `Mar
    | `Apr
    | `May
    | `Jun
    | `Jul
    | `Aug
    | `Sep
    | `Oct
    | `Nov
    | `Dec
    ]

  val human_int_of_month : month -> int
  (** This yields the usual human readable numbering of 1 to 12 inclusive *)

  val index_of_month : month -> int
  (** This yields the index based numbering of 0 to 11 inclusive *)

  val month_of_human_int : int -> month option

  val month_of_index : int -> month option

  (** {1 Range flattening} *)

  val flatten_month_ranges : int range Seq.t -> int Seq.t option

  val flatten_month_day_ranges : int range Seq.t -> int Seq.t option

  val flatten_weekday_ranges : weekday range Seq.t -> weekday Seq.t option

  val flatten_month_range_list : int range list -> int list option

  val flatten_month_day_range_list : int range list -> int list option

  val flatten_weekday_range_list : weekday range list -> weekday list option

  val weekday_of_tm_int : int -> weekday option

  val tm_int_of_weekday : weekday -> int

  val get_local_tz_for_arg : unit -> Time_zone.t
end
