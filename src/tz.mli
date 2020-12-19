type t

type entry = private {
  is_dst : bool;
  offset : int;
}

val is_utc : t -> bool

val make : string -> t

val available_time_zones : string list

val lookup_timestamp : t -> int64 -> entry option
