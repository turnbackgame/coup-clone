import gleam/list
import lib/message/json
import lustre/effect.{type Effect}
import lustre_websocket as ws

pub type Lobby {
  Lobby(id: String, players: List(Player), socket: ws.WebSocket)
}

pub type Player {
  Player(name: String, you: Bool, host: Bool)
}

pub fn new(socket: ws.WebSocket) -> Lobby {
  Lobby(id: "", players: [], socket:)
}

pub fn init(lobby: Lobby, msg_lobby: json.Lobby) -> Lobby {
  let players =
    msg_lobby.players
    |> list.map(fn(p) { Player(name: p.name, you: p.you, host: p.host) })
  Lobby(..lobby, id: msg_lobby.id, players:)
}

pub fn update_players(
  lobby: Lobby,
  msg_players: List(json.LobbyPlayer),
) -> Lobby {
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name, you: p.you, host: p.host) })
  Lobby(..lobby, players:)
}

pub fn start_game(lobby: Lobby) -> Effect(a) {
  json.LobbyStartGame
  |> json.LobbyCommand
  |> json.encode_command
  |> ws.send(lobby.socket, _)
}
