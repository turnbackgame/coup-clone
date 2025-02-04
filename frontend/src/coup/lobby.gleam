import gleam/list
import json/lobby_message as msg
import json/message
import lustre/effect.{type Effect}
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
  msg_lobby: msg.Lobby,
  msg_player: msg.Player,
  msg_players: List(msg.Player),
) -> Model {
  let player = Player(name: msg_player.name)
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Model(..model, id: msg_lobby.id, player:, players:)
}

pub fn update_players(model: Model, msg_players: List(msg.Player)) -> Model {
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Model(..model, players:)
}

pub fn start_game(model: Model) -> Effect(a) {
  let buf = message.encode_command(message.LobbyCommand(msg.StartGame))
  ws.send(model.socket, buf)
}
