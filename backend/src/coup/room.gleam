import coup/game.{type Game}
import coup/lobby.{type Lobby}
import domain
import gleam/bool
import gleam/deque
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

pub type RoomState {
  RoomState(lobby: Lobby, game: Option(Game))
}

pub fn new_room(id: String) -> domain.Room {
  let assert Ok(subject) =
    actor.start(RoomState(lobby: lobby.new(id), game: None), room_loop)
  subject
}

fn room_loop(
  command: domain.Command,
  state: RoomState,
) -> actor.Next(domain.Command, RoomState) {
  case command {
    domain.JoinLobby(new_user) -> {
      case lobby.add_user(state.lobby, new_user) {
        Error(_) -> {
          domain.Error("require minimum 2 player to start the game")
          |> actor.send(new_user.subject, _)
          actor.continue(state)
        }
        Ok(lobby) -> {
          let updated_users = lobby.users |> deque.to_list

          updated_users
          |> list.each(fn(user) {
            case user == new_user {
              True -> {
                domain.LobbyInit(
                  id: lobby.id,
                  user_id: user.id,
                  host_id: lobby.host_id,
                  users: updated_users,
                )
              }
              False -> {
                domain.LobbyUpdatedUsers(
                  host_id: lobby.host_id,
                  users: updated_users,
                )
              }
            }
            |> actor.send(user.subject, _)
          })

          let lobby =
            lobby.Lobby(..lobby, users: deque.from_list(updated_users))
          actor.continue(RoomState(..state, lobby:))
        }
      }
    }

    domain.LeaveLobby(the_user) -> {
      case lobby.remove_user(state.lobby, the_user) {
        Error(_) -> actor.Stop(process.Normal)
        Ok(lobby) -> {
          let updated_users = lobby.users |> deque.to_list

          updated_users
          |> list.each(fn(user) {
            domain.LobbyUpdatedUsers(
              host_id: lobby.host_id,
              users: updated_users,
            )
            |> actor.send(user.subject, _)
          })

          actor.continue(RoomState(..state, lobby:))
        }
      }
    }

    domain.StartGame(the_user) -> {
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
            domain.Error("require minimum 2 player to start the game")
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
              domain.Player(subject: user.subject, id: user.id, name: user.name)
            })

          let game =
            game.Game(id: state.lobby.id, players: deque.from_list(players))

          players
          |> list.each(fn(player) {
            domain.GameInit(id: game.id, player_id: player.id, players: players)
            |> actor.send(player.subject, _)
          })

          actor.continue(RoomState(..state, game: Some(game)))
        }
      }
    }
  }
}
