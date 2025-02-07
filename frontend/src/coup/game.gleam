import gleam/list
import lib/message/json
import lustre_websocket as ws

pub type Game {
  Game(
    socket: ws.WebSocket,
    id: String,
    player_id: String,
    players: List(Player),
  )
}

pub type Player {
  Player(id: String, name: String)
}

pub fn new(socket: ws.WebSocket) -> Game {
  Game(socket:, id: "", player_id: "", players: [])
}

pub fn init(game: Game, msg_game: json.Game) -> Game {
  let players =
    msg_game.players
    |> list.map(fn(p) { Player(id: p.id, name: p.name) })
  Game(..game, id: msg_game.id, player_id: msg_game.player_id, players:)
}
