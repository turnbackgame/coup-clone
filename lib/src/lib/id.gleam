pub opaque type Id(id_type) {
  Id(String)
}

pub fn new_empty() -> Id(a) {
  Id("")
}

pub fn is_empty(id: Id(a)) -> Bool {
  let Id(s) = id
  s == ""
}

pub fn from_string(id: String) -> Id(a) {
  Id(id)
}

pub fn to_string(id: Id(a)) -> String {
  let Id(s) = id
  s
}

pub fn map(id: Id(a)) -> Id(b) {
  let Id(a) = id
  Id(a)
}
