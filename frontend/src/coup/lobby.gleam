import gleam/list
import lib/message/json
import lustre/effect.{type Effect}
import lustre_websocket as ws

pub type Lobby {
  Lobby(
    socket: ws.WebSocket,
    id: String,
    user_id: String,
    host_id: String,
    users: List(User),
  )
}

pub type User {
  User(id: String, name: String)
}

pub fn new(socket: ws.WebSocket) -> Lobby {
  Lobby(socket:, id: "", user_id: "", host_id: "", users: [])
}

pub fn init(lobby: Lobby, msg_lobby: json.Lobby) -> Lobby {
  let users =
    msg_lobby.users
    |> list.map(fn(p) { User(id: p.id, name: p.name) })
  Lobby(
    ..lobby,
    id: msg_lobby.id,
    user_id: msg_lobby.user_id,
    host_id: msg_lobby.host_id,
    users:,
  )
}

pub fn update_users(
  lobby: Lobby,
  host_id: String,
  msg_users: List(json.User),
) -> Lobby {
  let users =
    msg_users
    |> list.map(fn(p) { User(id: p.id, name: p.name) })
  Lobby(..lobby, host_id:, users:)
}

pub fn start_game(lobby: Lobby) -> Effect(a) {
  json.LobbyStartGame
  |> json.LobbyCommand
  |> json.encode_command
  |> ws.send(lobby.socket, _)
}
