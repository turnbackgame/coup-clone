import gleam/list
import lib/message/json
import lustre_websocket as ws

pub type Game {
  Game(
    socket: ws.WebSocket,
    id: String,
    player: Player,
    other_players: List(Player),
    deck_count: Int,
  )
}

pub type Player {
  Player(id: String, name: String, cards: List(json.Card))
}

pub fn new(socket: ws.WebSocket) -> Game {
  Game(
    socket:,
    id: "",
    player: Player(id: "", name: "", cards: []),
    other_players: [],
    deck_count: 0,
  )
}

pub fn init(game: Game, msg_game: json.Game) -> Game {
  let player =
    Player(
      id: msg_game.player.id,
      name: msg_game.player.name,
      cards: msg_game.player.cards,
    )
  let other_players =
    msg_game.other_players
    |> list.map(fn(p) { Player(id: p.id, name: p.name, cards: p.cards) })
  Game(
    ..game,
    id: msg_game.id,
    player:,
    other_players:,
    deck_count: msg_game.deck_count,
  )
}
