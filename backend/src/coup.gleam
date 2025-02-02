import glanoid
import gleam/bool
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import json/game_message
import json/lobby_message
import json/message
import mist

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
  Player(subject: Subject(PlayerMessage), name: String)
}

pub fn new_player(name: String) -> Player {
  let name = case name {
    "" -> "player-" <> generator(5)
    _ -> name
  }
  Player(subject: process.new_subject(), name:)
}

pub type PlayerMessage {
  Send(String)
}

pub fn handle_player_message(conn: mist.WebsocketConnection, msg: PlayerMessage) {
  let Send(buf) = msg
  mist.send_text_frame(conn, buf)
}

pub type Room {
  Room(subject: Subject(RoomMessage))
}

pub type RoomState {
  RoomState(id: ID, lobby: Lobby, game: Option(Game))
}

pub type RoomMessage {
  LobbyMessage(LobbyMessage)
  StartGame
  GameMessage(GameMessage)
}

pub type Lobby {
  Lobby(id: ID, players: List(Player))
}

pub type LobbyMessage {
  JoinLobby(player: Player)
  LeaveLobby(player: Player)
}

pub type Game {
  Game(id: ID, players: List(Player))
}

pub type GameMessage {
  TODO
}

pub fn join_lobby(room: Room, player: Player) {
  actor.send(room.subject, LobbyMessage(JoinLobby(player)))
}

pub fn leave_lobby(room: Room, player: Player) {
  actor.send(room.subject, LobbyMessage(LeaveLobby(player)))
}

pub fn start_game(room: Room) {
  actor.send(room.subject, StartGame)
}

fn room_loop(
  message: RoomMessage,
  state: RoomState,
) -> actor.Next(RoomMessage, RoomState) {
  case message {
    LobbyMessage(lobby_message) -> {
      let lobby = handle_lobby_message(lobby_message, state.lobby)
      use <- bool.guard(
        list.is_empty(lobby.players),
        actor.Stop(process.Normal),
      )
      actor.continue(RoomState(..state, lobby:))
    }

    StartGame -> {
      case state.game {
        Some(_) -> todo as "handle starting an already started game"
        None -> {
          case list.length(state.lobby.players) {
            player_count if player_count < 2 ->
              todo as "handle starting the game with not enough players"
            _ -> {
              let game = Game(id: state.id, players: state.lobby.players)

              game.players
              |> list.each(fn(player) {
                let game_init =
                  game_message.Init(
                    game: game_message.Game(id: game.id.string),
                    player: game_message.Player(name: player.name),
                    players: game.players
                      |> list.prepend(player)
                      |> list.reverse
                      |> list.map(fn(player) {
                        game_message.Player(name: player.name)
                      }),
                  )
                  |> message.GameEvent
                  |> message.encode_event
                  |> Send
                actor.send(player.subject, game_init)
              })

              actor.continue(RoomState(..state, game: Some(game)))
            }
          }
        }
      }
    }

    GameMessage(game_message) -> {
      case state.game {
        None -> {
          todo as "handle game message when no game is started"
        }
        Some(game) -> {
          let game = handle_game_message(game_message, game)
          actor.continue(RoomState(..state, game: Some(game)))
        }
      }
    }
  }
}

fn handle_lobby_message(message: LobbyMessage, lobby: Lobby) -> Lobby {
  case message {
    JoinLobby(player) -> {
      let lobby_init =
        lobby_message.Init(
          lobby: lobby_message.Lobby(id: lobby.id.string),
          player: lobby_message.Player(name: player.name),
          players: lobby.players
            |> list.prepend(player)
            |> list.reverse
            |> list.map(fn(player) { lobby_message.Player(name: player.name) }),
        )
        |> message.LobbyEvent
        |> message.encode_event
        |> Send
      actor.send(player.subject, lobby_init)

      let lobby_updated =
        lobby_message.PlayersUpdated(
          players: lobby.players
          |> list.prepend(player)
          |> list.reverse
          |> list.map(fn(player) { lobby_message.Player(name: player.name) }),
        )
        |> message.LobbyEvent
        |> message.encode_event
        |> Send
      lobby.players
      |> list.each(fn(player) { actor.send(player.subject, lobby_updated) })

      let players =
        lobby.players
        |> list.prepend(player)
      Lobby(..lobby, players:)
    }

    LeaveLobby(player) -> {
      let players = list.filter(lobby.players, fn(p) { p != player })

      use <- bool.guard(list.is_empty(lobby.players), lobby)

      let lobby_updated =
        lobby_message.PlayersUpdated(
          players: players
          |> list.reverse
          |> list.map(fn(player) { lobby_message.Player(name: player.name) }),
        )
        |> message.LobbyEvent
        |> message.encode_event
        |> Send
      players
      |> list.each(fn(player) { actor.send(player.subject, lobby_updated) })

      Lobby(..lobby, players:)
    }
  }
}

fn handle_game_message(message: GameMessage, game: Game) -> Game {
  case message {
    TODO -> {
      todo as "handle other game message"
    }
  }
}

pub type Pool {
  Pool(subject: Subject(PoolMessage))
}

pub type PoolState {
  PoolState(rooms: Dict(ID, Room), selector: process.Selector(PoolMessage))
}

pub type PoolMessage {
  DeleteRoom(process.ProcessDown, id: ID)
  CreateRoom(reply_with: Subject(Room))
  GetRoom(reply_with: Subject(Result(Room, Nil)), id: ID)
}

pub fn new_pool() -> Pool {
  let assert Ok(subject) = actor.start_spec(pool_spec())
  Pool(subject: subject)
}

pub fn create_room(pool: Pool) -> Room {
  actor.call(pool.subject, CreateRoom(_), timeout)
}

pub fn get_room(pool: Pool, id: ID) -> Result(Room, Nil) {
  actor.call(pool.subject, GetRoom(_, id), timeout)
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
    DeleteRoom(_, id) -> {
      let state = PoolState(..state, rooms: dict.delete(state.rooms, id))
      actor.continue(state)
    }

    CreateRoom(reply_with) -> {
      let id = ID(generator(id_length))
      let assert Ok(subject) =
        actor.start(
          RoomState(id:, lobby: Lobby(id:, players: []), game: None),
          room_loop,
        )
      let room = Room(subject:)

      actor.send(reply_with, room)

      let monitor =
        room.subject
        |> process.subject_owner
        |> process.monitor_process

      let selector =
        state.selector
        |> process.selecting_process_down(monitor, DeleteRoom(_, id))

      let state =
        PoolState(rooms: dict.insert(state.rooms, id, room), selector:)

      actor.Continue(state, Some(selector))
    }

    GetRoom(reply_with, id) -> {
      dict.get(state.rooms, id)
      |> actor.send(reply_with, _)
      actor.continue(state)
    }
  }
}
