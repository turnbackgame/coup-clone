import coup/message.{type Player}
import gleam/deque.{type Deque}

pub type Game {
  Game(id: String, players: Deque(Player))
}
