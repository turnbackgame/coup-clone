import gleam/erlang/process.{type Subject}

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

pub type User {
  User(subject: Subject(Event), id: String, name: String)
}

pub type Player {
  Player(subject: Subject(Event), id: String, name: String)
}
