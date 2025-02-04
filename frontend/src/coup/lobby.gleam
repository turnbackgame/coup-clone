import gleam/list
import json/lobby_message as msg
import json/message
import lustre/effect.{type Effect}
import lustre_websocket as ws

pub type Lobby {
  Lobby(id: String, player: Player, players: List(Player), socket: ws.WebSocket)
}

pub type Player {
  Player(name: String)
}

pub fn new(socket: ws.WebSocket) -> Lobby {
  Lobby(id: "", player: Player(name: ""), players: [], socket:)
}

pub fn init(
  lobby: Lobby,
  msg_lobby: msg.Lobby,
  msg_player: msg.Player,
  msg_players: List(msg.Player),
) -> Lobby {
  let player = Player(name: msg_player.name)
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Lobby(..lobby, id: msg_lobby.id, player:, players:)
}

pub fn update_players(lobby: Lobby, msg_players: List(msg.Player)) -> Lobby {
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name) })
  Lobby(..lobby, players:)
}

pub fn start_game(lobby: Lobby) -> Effect(a) {
  let buf = message.encode_command(message.LobbyCommand(msg.StartGame))
  ws.send(lobby.socket, buf)
}
