import gleam/erlang/process.{type Subject}
import lib/ids
import lib/message/json

pub type Event =
  json.Event

pub type Command {
  JoinLobby(Player)
  LeaveLobby(Player)
  Command(json.Command)
}

pub type Player {
  Player(subject: Subject(Event), name: String, host: Bool)
}

pub fn new_player(name: String, host: Bool) -> Player {
  let name = case name {
    "" -> "player-" <> ids.generate(5)
    _ -> name
  }
  Player(subject: process.new_subject(), name:, host:)
}
