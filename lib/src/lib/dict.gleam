import gleam/dict
import gleam/function
import gleam/list
import gleam/result

pub opaque type Dict(k, v) {
  Dict(map: dict.Dict(k, v), order: List(k))
}

pub fn new() -> Dict(k, v) {
  Dict(dict.new(), [])
}

pub fn to_list(dict: Dict(k, v)) -> List(v) {
  use key <- list.filter_map(dict.order)
  dict.map
  |> dict.get(key)
  |> result.map(function.identity)
}

fn to_list_keyed(dict: Dict(k, v)) -> List(#(k, v)) {
  use key <- list.filter_map(dict.order)
  dict.map
  |> dict.get(key)
  |> result.map(fn(value) { #(key, value) })
}

pub fn from_list(list: List(v), fn_key: fn(v) -> k) -> Dict(k, v) {
  let #(map, rev_order) = {
    use #(map, rev_order), val <- list.fold(list, #(dict.new(), []))
    let key = fn_key(val)
    #(dict.insert(map, key, val), [
      key,
      ..list.filter(rev_order, fn(k) { k != key })
    ])
  }
  Dict(map, list.reverse(rev_order))
}

fn from_list_keyed(list: List(#(k, v))) -> Dict(k, v) {
  let #(map, rev_order) = {
    use #(map, rev_order), #(key, val) <- list.fold(list, #(dict.new(), []))
    #(dict.insert(map, key, val), [
      key,
      ..list.filter(rev_order, fn(k) { k != key })
    ])
  }
  Dict(map, list.reverse(rev_order))
}

pub fn size(dict: Dict(k, v)) -> Int {
  dict.size(dict.map)
}

pub fn is_empty(dict: Dict(k, v)) -> Bool {
  dict.is_empty(dict.map)
}

pub fn insert_back(dict: Dict(k, v), key: k, value: v) -> Dict(k, v) {
  Dict(
    dict.insert(dict.map, key, value),
    list.append(list.filter(dict.order, fn(k) { k != key }), [key]),
  )
}

pub fn update(dict: Dict(k, v), key: k, value: v) -> Dict(k, v) {
  case dict |> get(key) {
    Ok(_) -> Dict(..dict, map: dict.map |> dict.insert(key, value))
    Error(_) -> dict
  }
}

pub fn delete(dict: Dict(k, v), key: k) -> Dict(k, v) {
  Dict(dict.delete(dict.map, key), list.filter(dict.order, fn(k) { k != key }))
}

pub fn get(dict: Dict(k, v), key: k) -> Result(v, Nil) {
  dict.get(dict.map, key)
}

pub fn first(dict: Dict(k, v)) -> Result(v, Nil) {
  use key <- result.try(list.first(dict.order))
  get(dict, key)
}

pub fn map(dict: Dict(k, v), fn_map: fn(k, v) -> #(a, b)) -> Dict(a, b) {
  dict
  |> to_list_keyed
  |> list.map(fn(pair) { fn_map(pair.0, pair.1) })
  |> from_list_keyed
}

pub fn map_values(dict: Dict(k, v), fn_map: fn(v) -> a) -> Dict(k, a) {
  dict
  |> to_list_keyed
  |> list.map(fn(pair) { #(pair.0, fn_map(pair.1)) })
  |> from_list_keyed
}

pub fn each(dict: Dict(k, v), subject: s, do fn_each: fn(v) -> Nil) -> s {
  fold(dict, Nil, fn(nil, _, v) {
    fn_each(v)
    nil
  })
  subject
}

pub fn fold(dict: Dict(k, v), initial: acc, fn_map: fn(acc, k, v) -> acc) -> acc {
  use acc, #(key, val) <- list.fold(to_list_keyed(dict), initial)
  fn_map(acc, key, val)
}
