import coup/message.{type Player}

pub type Game {
  Game(id: String, players: List(Player))
}
