import gleam/list
import json/game_message as msg
import lustre_websocket as ws

pub type Model {
  Model(id: String, player: Player, players: List(Player), socket: ws.WebSocket)
}

pub type Player {
  Player(name: String)
}

pub fn new(socket: ws.WebSocket) -> Model {
  Model(id: "", player: Player(name: ""), players: [], socket:)
}

pub fn init(
  model: Model,
  msg_game: msg.Game,
  msg_player: msg.Player,
  msg_players: List(msg.Player),
) -> Model {
  let player = Player(name: msg_player.name)
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Model(..model, id: msg_game.id, player:, players:)
}

pub fn update_players(model: Model, msg_players: List(msg.Player)) -> Model {
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Model(..model, players:)
}
