import glanoid
import gleam/bool
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import mist
import shared/json

const timeout = 100

const id_length = 8

pub type ID {
  ID(string: String)
}

pub fn generator(n: Int) -> String {
  let assert Ok(generator) =
    glanoid.make_generator("0123456789abcdefghijklmnopqrstuvwxyz")
  generator(n)
}

pub type Player {
  Player(name: String, subject: Subject(PlayerMessage))
}

pub fn new_player(name: String) -> Player {
  let name = case name {
    "" -> "player-" <> generator(5)
    _ -> name
  }
  Player(name: name, subject: process.new_subject())
}

pub type PlayerMessage {
  Send(String)
}

pub fn handle_player_message(conn: mist.WebsocketConnection, msg: PlayerMessage) {
  let Send(buf) = msg
  mist.send_text_frame(conn, buf)
}

pub type Lobby {
  Lobby(id: ID, subject: Subject(LobbyMessage))
}

fn new_lobby() -> Lobby {
  let assert Ok(subject) = actor.start([], lobby_loop)
  Lobby(id: ID(generator(id_length)), subject: subject)
}

pub type LobbyMessage {
  Join(lobby: Lobby, player: Player)
  Leave(lobby: Lobby, player: Player)
}

fn lobby_loop(message: LobbyMessage, players: List(Player)) {
  case message {
    Join(lobby, player) -> {
      let players = [player, ..players]

      players
      |> function.tap(
        list.each(_, fn(player) {
          let lobby = json.Lobby(id: lobby.id.string)
          let players =
            players
            |> list.reverse
            |> list.map(fn(player) { json.Player(name: player.name) })

          actor.send(
            player.subject,
            json.PlayerJoinedLobby(lobby:, players:)
              |> json.encode_player_message
              |> json.to_string
              |> Send,
          )
        }),
      )
      |> actor.continue
    }
    Leave(lobby, player) -> {
      let players = list.filter(players, fn(p) { p != player })

      use <- bool.guard(list.is_empty(players), actor.Stop(process.Normal))
      players
      |> function.tap(
        list.each(_, fn(player) {
          let lobby = json.Lobby(id: lobby.id.string)
          let players =
            players
            |> list.reverse
            |> list.map(fn(player) { json.Player(name: player.name) })

          actor.send(
            player.subject,
            json.PlayerJoinedLobby(lobby:, players:)
              |> json.encode_player_message
              |> json.to_string
              |> Send,
          )
        }),
      )
      |> actor.continue
    }
  }
}

pub fn join_lobby(lobby: Lobby, player: Player) {
  actor.send(lobby.subject, Join(lobby, player))
}

pub fn leave_lobby(lobby: Lobby, player: Player) {
  actor.send(lobby.subject, Leave(lobby, player))
}

pub type Room {
  LobbyRoom(room: Lobby)
}

pub type Pool {
  Pool(subject: Subject(PoolMessage))
}

pub type PoolState {
  PoolState(rooms: Dict(ID, Room), selector: process.Selector(PoolMessage))
}

pub type PoolMessage {
  CreateLobby(reply_with: Subject(Lobby))
  GetLobby(reply_with: Subject(Result(Lobby, Nil)), id: ID)
  RoomDown(process.ProcessDown, id: ID)
}

pub fn new_pool() -> Pool {
  let assert Ok(subject) = actor.start_spec(pool_spec())
  Pool(subject: subject)
}

fn pool_spec() -> actor.Spec(PoolState, PoolMessage) {
  actor.Spec(init_timeout: timeout, loop: pool_loop, init: fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    let state = PoolState(rooms: dict.new(), selector: selector)
    actor.Ready(state, selector)
  })
}

fn pool_loop(
  message: PoolMessage,
  state: PoolState,
) -> actor.Next(PoolMessage, PoolState) {
  case message {
    CreateLobby(reply_with) -> {
      let lobby = new_lobby()
      actor.send(reply_with, lobby)

      let monitor =
        lobby.subject
        |> process.subject_owner
        |> process.monitor_process

      let selector =
        state.selector
        |> process.selecting_process_down(monitor, RoomDown(_, lobby.id))

      let state =
        PoolState(
          rooms: dict.insert(state.rooms, lobby.id, LobbyRoom(lobby)),
          selector:,
        )
      actor.Continue(state, Some(selector))
    }

    GetLobby(reply_with, id) -> {
      dict.get(state.rooms, id)
      |> result.map(fn(a) { a.room })
      |> actor.send(reply_with, _)
      actor.continue(state)
    }

    RoomDown(_, id) -> {
      let state = PoolState(..state, rooms: dict.delete(state.rooms, id))
      actor.continue(state)
    }
  }
}

pub fn create_lobby(pool: Pool) -> Lobby {
  actor.call(pool.subject, CreateLobby(_), timeout)
}

pub fn get_lobby(pool: Pool, id: ID) -> Result(Lobby, Nil) {
  actor.call(pool.subject, GetLobby(_, id), timeout)
}
