import coup/coup
import coup/game.{type Game}
import coup/lobby.{type Lobby}
import gleam/bool
import gleam/deque
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

pub type Room =
  Subject(coup.Command)

pub type RoomState {
  RoomState(lobby: Lobby, game: Option(Game))
}

pub fn new_room(id: String) -> Room {
  let assert Ok(subject) =
    actor.start(RoomState(lobby: lobby.new(id), game: None), room_loop)
  subject
}

fn room_loop(
  command: coup.Command,
  state: RoomState,
) -> actor.Next(coup.Command, RoomState) {
  case command {
    coup.JoinLobby(user) -> {
      case lobby.add_user(state.lobby, user) {
        Ok(lobby) -> actor.continue(RoomState(..state, lobby:))
        Error(_) -> actor.continue(state)
      }
    }

    coup.LeaveLobby(the_user) -> {
      case lobby.remove_user(state.lobby, the_user) {
        Ok(lobby) -> actor.continue(RoomState(..state, lobby:))
        Error(_) -> actor.Stop(process.Normal)
      }
    }

    coup.StartGame(the_user) -> {
      case state.game {
        Some(game) -> {
          io.println(game.id <> ": player starting an already started game")
          actor.continue(state)
        }
        None -> {
          let not_enough_player = fn() {
            use <- bool.guard(
              the_user.id == state.lobby.host_id,
              actor.continue(state),
            )
            coup.Error("require minimum 2 player to start the game")
            |> actor.send(the_user.subject, _)
            actor.continue(state)
          }

          use <- bool.lazy_guard(
            deque.length(state.lobby.users) < 2,
            not_enough_player,
          )

          let players =
            state.lobby.users
            |> deque.to_list
            |> list.map(fn(user) {
              coup.Player(subject: user.subject, id: user.id, name: user.name)
            })

          let game =
            game.Game(id: state.lobby.id, players: deque.from_list(players))

          players
          |> list.each(fn(player) {
            coup.GameInit(id: game.id, player_id: player.id, players: players)
            |> actor.send(player.subject, _)
          })

          actor.continue(RoomState(..state, game: Some(game)))
        }
      }
    }
  }
}
