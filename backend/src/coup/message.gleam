import glanoid
import gleam/erlang/process.{type Subject}
import json/message

pub type Event =
  message.Event

pub type Command {
  JoinLobby(Player)
  LeaveLobby(Player)
  Command(message.Command)
}

pub type Player {
  Player(subject: Subject(Event), name: String, host: Bool)
}

fn generator(n: Int) -> String {
  let assert Ok(generator) =
    glanoid.make_generator("0123456789abcdefghijklmnopqrstuvwxyz")
  generator(n)
}

pub fn new_player(name: String, host: Bool) -> Player {
  let name = case name {
    "" -> "player-" <> generator(5)
    _ -> name
  }
  Player(subject: process.new_subject(), name:, host:)
}
