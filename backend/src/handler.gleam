import domain.{type Command, type Event, type Room, type User}
import gleam/list
import gleam/otp/actor
import lib/message/json

pub fn join_lobby(room: Room, user: User) {
  actor.send(room, domain.JoinLobby(user))
}

pub fn leave_lobby(room: Room, user: User) {
  actor.send(room, domain.LeaveLobby(user))
}

pub fn handle_command(user: User, command: json.Command) -> Command {
  case command {
    json.LobbyCommand(json.LobbyStartGame) -> domain.StartGame(user)
  }
}

pub fn handle_event(_user: User, event: Event) -> json.Event {
  case event {
    domain.Error(msg) -> json.Error(msg)

    domain.LobbyInit(id, user_id, host_id, users) -> {
      users
      |> list.map(fn(u) { json.User(id: u.id, name: u.name) })
      |> json.Lobby(id:, user_id:, host_id:, users: _)
      |> json.LobbyInit
      |> json.LobbyEvent
    }

    domain.LobbyUpdatedUsers(host_id, users) -> {
      users
      |> list.map(fn(u) { json.User(id: u.id, name: u.name) })
      |> json.LobbyUpdatedUsers(host_id:, users: _)
      |> json.LobbyEvent
    }

    domain.GameInit(id, player_id, players) -> {
      players
      |> list.map(fn(u) { json.Player(id: u.id, name: u.name) })
      |> json.Game(id:, player_id:, players: _)
      |> json.GameInit
      |> json.GameEvent
    }
  }
}
