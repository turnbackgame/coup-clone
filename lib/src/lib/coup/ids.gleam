pub opaque type ID(id_type) {
  ID(String)
}

pub fn from_string(id: String) -> ID(a) {
  ID(id)
}

pub fn to_string(id: ID(a)) -> String {
  let ID(s) = id
  s
}

pub fn map(id: ID(a)) -> ID(b) {
  let ID(a) = id
  ID(a)
}

pub type User

pub type Player

pub type Lobby

pub type Game
