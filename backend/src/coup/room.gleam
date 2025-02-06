import coup/game.{type Game}
import coup/lobby.{type Lobby}
import coup/message.{type Command} as msg
import gleam/bool
import gleam/deque
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import lib/message/json

pub type RoomState {
  RoomState(id: String, lobby: Lobby, game: Option(Game))
}

pub fn new_room(id: String) -> Subject(Command) {
  let assert Ok(subject) =
    actor.start(RoomState(id:, lobby: lobby.new(id), game: None), room_loop)
  subject
}

fn room_loop(
  message: Command,
  state: RoomState,
) -> actor.Next(Command, RoomState) {
  case message {
    msg.JoinLobby(new_player) -> {
      let new_players = state.lobby.players |> deque.push_back(new_player)
      let new_player_list = new_players |> deque.to_list

      new_players
      |> deque.to_list
      |> list.each(fn(player) {
        case player == new_player {
          True -> {
            new_player_list
            |> list.map(fn(p) {
              json.LobbyPlayer(name: p.name, you: p == new_player, host: p.host)
            })
            |> json.Lobby(id: state.lobby.id, players: _)
            |> json.LobbyInit
            |> json.LobbyEvent
          }
          False -> {
            new_player_list
            |> list.map(fn(p) {
              json.LobbyPlayer(name: p.name, you: p == player, host: p.host)
            })
            |> json.LobbyPlayersUpdated
            |> json.LobbyEvent
          }
        }
        |> actor.send(player.subject, _)
      })

      let lobby = lobby.Lobby(..state.lobby, players: new_players)
      actor.continue(RoomState(..state, lobby:))
    }

    msg.LeaveLobby(the_player) -> {
      case lobby.remove_player(state.lobby, the_player) {
        Error(_) -> actor.Stop(process.Normal)
        Ok(lobby) -> {
          let player_list = lobby.players |> deque.to_list

          player_list
          |> list.each(fn(player) {
            player_list
            |> list.map(fn(p) {
              json.LobbyPlayer(name: p.name, you: p == player, host: p.host)
            })
            |> json.LobbyPlayersUpdated
            |> json.LobbyEvent
            |> actor.send(player.subject, _)
          })

          actor.continue(RoomState(..state, lobby:))
        }
      }
    }

    msg.Command(json.LobbyCommand(lobby_command)) -> {
      case lobby_command {
        json.LobbyStartGame -> {
          case state.game {
            Some(game) -> {
              io.println(game.id <> ": player starting an already started game")
              actor.continue(state)
            }
            None -> {
              use <- bool.guard(
                deque.length(state.lobby.players) < 2,
                actor.continue(state),
              )

              let game = game.Game(id: state.id, players: state.lobby.players)
              let player_list = game.players |> deque.to_list

              player_list
              |> list.each(fn(player) {
                let game_init =
                  json.GameInit(
                    game: json.Game(id: game.id),
                    player: json.GamePlayer(name: player.name),
                    players: player_list
                      |> list.map(fn(p) { json.GamePlayer(name: p.name) }),
                  )
                  |> json.GameEvent
                actor.send(player.subject, game_init)
              })

              actor.continue(RoomState(..state, game: Some(game)))
            }
          }
        }
      }
    }
  }
}
