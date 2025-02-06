import gleam/list
import lustre/effect.{type Effect}
import lustre_websocket as ws
import message/json

pub type Lobby {
  Lobby(id: String, player: Player, players: List(Player), socket: ws.WebSocket)
}

pub type Player {
  Player(name: String, host: Bool)
}

pub fn new(socket: ws.WebSocket) -> Lobby {
  Lobby(id: "", player: Player(name: "", host: False), players: [], socket:)
}

pub fn init(
  lobby: Lobby,
  msg_lobby: json.Lobby,
  msg_player: json.LobbyPlayer,
  msg_players: List(json.LobbyPlayer),
) -> Lobby {
  let player = Player(name: msg_player.name, host: msg_player.host)
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name, host: p.host) })
  Lobby(..lobby, id: msg_lobby.id, player:, players:)
}

pub fn update_players(
  lobby: Lobby,
  msg_players: List(json.LobbyPlayer),
) -> Lobby {
  let players =
    msg_players
    |> list.map(fn(p) { Player(name: p.name, host: p.host) })
  Lobby(..lobby, players:)
}

pub fn start_game(lobby: Lobby) -> Effect(a) {
  json.LobbyStartGame
  |> json.LobbyCommand
  |> json.encode_command
  |> ws.send(lobby.socket, _)
}
