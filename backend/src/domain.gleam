import gleam/erlang/process.{type Subject}
import lib/ids

pub type Command {
  JoinLobby(User)
  LeaveLobby(User)
  StartGame(User)
}

pub type Event {
  Error(String)
  LobbyInit(id: String, user_id: String, host_id: String, users: List(User))
  LobbyUpdatedUsers(host_id: String, users: List(User))
  GameInit(id: String, player_id: String, players: List(Player))
}

pub type Room =
  Subject(Command)

pub type User {
  User(subject: Subject(Event), id: String, name: String)
}

pub fn new_user(name: String) -> User {
  let id = ids.generate(8)
  let name = case name {
    "" -> "player-" <> ids.generate(5)
    _ -> name
  }
  User(subject: process.new_subject(), id:, name:)
}

pub type Player {
  Player(subject: Subject(Event), id: String, name: String)
}
