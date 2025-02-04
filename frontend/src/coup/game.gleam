import gleam/list
import gleam/option.{type Option}
import json/game_message as msg
import lustre_websocket as ws

pub type Model {
  Model(
    id: String,
    player: Player,
    players: List(Player),
    socket: Option(ws.WebSocket),
  )
}

pub type Message

pub type Player {
  Player(name: String)
}

pub fn init(
  msg_game: msg.Game,
  msg_player: msg.Player,
  msg_players: List(msg.Player),
  socket: Option(ws.WebSocket),
) -> Model {
  let player = Player(name: msg_player.name)
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Model(id: msg_game.id, player:, players:, socket:)
}

pub fn update_players(model: Model, msg_players: List(msg.Player)) -> Model {
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Model(..model, players:)
}
