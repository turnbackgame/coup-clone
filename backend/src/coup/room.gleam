import coup/coup
import coup/game.{type Game}
import coup/lobby.{type Lobby}
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

pub type Room =
  Subject(coup.Command)

pub type RoomState {
  RoomState(lobby: Lobby, game: Option(Game))
}

pub fn new(id: String) -> Room {
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

    coup.LeaveLobby(user) -> {
      case lobby.remove_user(state.lobby, user) {
        Ok(lobby) -> actor.continue(RoomState(..state, lobby:))
        Error(_) -> actor.Stop(process.Normal)
      }
    }

    coup.StartGame(user) -> {
      case state.game {
        Some(game) -> {
          io.println(game.id <> ": player starting an already started game")
          actor.continue(state)
        }
        None -> {
          use <- bool.lazy_guard(!lobby.is_user_host(state.lobby, user), fn() {
            actor.send(
              user.subject,
              coup.SendError("only host can start the game"),
            )
            actor.continue(state)
          })

          let players = coup.to_players(state.lobby.users)
          use <- bool.lazy_guard(!game.is_enough_player(players), fn() {
            actor.send(
              user.subject,
              coup.SendError("require minimum 2 player to start the game"),
            )
            actor.continue(state)
          })

          let game =
            game.new(state.lobby.id)
            |> game.add_players(players)
            |> game.assign_cards
            |> game.start_game
          actor.continue(RoomState(..state, game: Some(game)))
        }
      }
    }
  }
}
