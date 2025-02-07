import domain
import gleam/deque.{type Deque}

pub type Game {
  Game(id: String, players: Deque(domain.Player))
}
