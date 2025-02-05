import coup/message.{type Command, type Player} as msg
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import json/lobby_message
import json/message

pub type Lobby {
  Lobby(id: String, players: List(Player))
}

pub fn new(id: String) -> Lobby {
  Lobby(id:, players: [])
}

pub fn join_lobby(room: Subject(Command), player: Player) {
  actor.send(room, msg.JoinLobby(player))
}

pub fn leave_lobby(room: Subject(Command), player: Player) {
  actor.send(room, msg.LeaveLobby(player))
}

pub fn start_game(room: Subject(Command)) {
  actor.send(
    room,
    lobby_message.StartGame
      |> message.LobbyCommand
      |> msg.Command,
  )
}
