import glanoid

const default_alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

pub fn generate(n: Int) -> String {
  let assert Ok(generator) = glanoid.make_generator(default_alphabet)
  generator(n)
}

pub opaque type ID(id_type) {
  ID(string: String)
}

pub fn from_string(id: String) -> ID(a) {
  ID(id)
}

pub fn to_string(id: ID(a)) -> String {
  id.string
}

pub fn map(id: ID(a)) -> ID(b) {
  ID(id.string)
}

pub type User

pub type Player

pub type Lobby

pub type Game
