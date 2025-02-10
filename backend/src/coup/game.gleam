import coup/coup
import gleam/deque.{type Deque}

pub type Game {
  Game(id: String, players: Deque(coup.Player))
}
