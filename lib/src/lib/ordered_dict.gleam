import gleam/dict
import gleam/function
import gleam/list
import gleam/result

pub opaque type OrderedDict(k, v) {
  OrderedDict(map: dict.Dict(k, v), order: List(k))
}

pub fn new() -> OrderedDict(k, v) {
  OrderedDict(dict.new(), [])
}

pub fn to_list(dict: OrderedDict(k, v)) -> List(v) {
  use key <- list.filter_map(dict.order)
  dict.map
  |> dict.get(key)
  |> result.map(function.identity)
}

fn to_list_keyed(dict: OrderedDict(k, v)) -> List(#(k, v)) {
  use key <- list.filter_map(dict.order)
  dict.map
  |> dict.get(key)
  |> result.map(fn(value) { #(key, value) })
}

pub fn from_list(list: List(v), fn_key: fn(v) -> k) -> OrderedDict(k, v) {
  let #(map, rev_order) = {
    use #(map, rev_order), val <- list.fold(list, #(dict.new(), []))
    let key = fn_key(val)
    #(dict.insert(map, key, val), [
      key,
      ..list.filter(rev_order, fn(k) { k != key })
    ])
  }
  OrderedDict(map, list.reverse(rev_order))
}

fn from_list_keyed(list: List(#(k, v))) -> OrderedDict(k, v) {
  let #(map, rev_order) = {
    use #(map, rev_order), #(key, val) <- list.fold(list, #(dict.new(), []))
    #(dict.insert(map, key, val), [
      key,
      ..list.filter(rev_order, fn(k) { k != key })
    ])
  }
  OrderedDict(map, list.reverse(rev_order))
}

pub fn size(dict: OrderedDict(k, v)) -> Int {
  dict.size(dict.map)
}

pub fn is_empty(dict: OrderedDict(k, v)) -> Bool {
  dict.is_empty(dict.map)
}

pub fn insert_back(
  dict: OrderedDict(k, v),
  key: k,
  value: v,
) -> OrderedDict(k, v) {
  OrderedDict(
    dict.insert(dict.map, key, value),
    list.append(list.filter(dict.order, fn(k) { k != key }), [key]),
  )
}

pub fn update(dict: OrderedDict(k, v), key: k, value: v) -> OrderedDict(k, v) {
  case dict |> get(key) {
    Ok(_) -> OrderedDict(..dict, map: dict.map |> dict.insert(key, value))
    Error(_) -> dict
  }
}

pub fn delete(dict: OrderedDict(k, v), key: k) -> OrderedDict(k, v) {
  OrderedDict(
    dict.delete(dict.map, key),
    list.filter(dict.order, fn(k) { k != key }),
  )
}

pub fn get(dict: OrderedDict(k, v), key: k) -> Result(v, Nil) {
  dict.get(dict.map, key)
}

pub fn first(dict: OrderedDict(k, v)) -> Result(v, Nil) {
  use key <- result.try(list.first(dict.order))
  get(dict, key)
}

pub fn map(dict: OrderedDict(k, v), fn_map: fn(v) -> a) -> OrderedDict(k, a) {
  dict
  |> to_list_keyed
  |> list.map(fn(pair) { #(pair.0, fn_map(pair.1)) })
  |> from_list_keyed
}

pub fn each(dict: OrderedDict(k, v), subject: s, do fn_each: fn(v) -> Nil) -> s {
  fold(dict, Nil, fn(nil, _, v) {
    fn_each(v)
    nil
  })
  subject
}

pub fn fold(
  dict: OrderedDict(k, v),
  initial: acc,
  fn_map: fn(acc, k, v) -> acc,
) -> acc {
  use acc, #(key, val) <- list.fold(to_list_keyed(dict), initial)
  fn_map(acc, key, val)
}
