import coup/message.{type Command, type Player}
import gleam/bool
import gleam/deque.{type Deque}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import lib/message/json

pub type Lobby {
  Lobby(id: String, players: Deque(Player))
}

pub fn new(id: String) -> Lobby {
  Lobby(id:, players: deque.new())
}

/// Remove player from the lobby.
/// If no players left in the lobby, returns Error(Nil).
/// If the player is the host, transfer host status to other player.
pub fn remove_player(lobby: Lobby, player: Player) -> Result(Lobby, Nil) {
  let players =
    lobby.players
    |> deque.to_list
    |> list.filter(fn(p) { p != player })
  use <- bool.guard(list.is_empty(players), Error(Nil))
  use <- bool.guard(
    !player.host,
    Ok(Lobby(..lobby, players: deque.from_list(players))),
  )
  let assert [first, ..players] = players
  let new_host = message.Player(..first, host: True)
  let players = deque.from_list([new_host, ..players])
  Ok(Lobby(..lobby, players:))
}

pub fn join_lobby(room: Subject(Command), player: Player) {
  actor.send(room, message.JoinLobby(player))
}

pub fn leave_lobby(room: Subject(Command), player: Player) {
  actor.send(room, message.LeaveLobby(player))
}

pub fn start_game(room: Subject(Command)) {
  actor.send(
    room,
    json.LobbyStartGame
      |> json.LobbyCommand
      |> message.Command,
  )
}
