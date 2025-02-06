import coup/game.{type Game}
import coup/lobby.{type Lobby}
import coup/message.{type Command} as msg
import gleam/bool
import gleam/deque
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import json/game_message
import json/lobby_message
import json/message

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
    msg.JoinLobby(player) -> {
      let new_players = state.lobby.players |> deque.push_back(player)
      let new_player_list = new_players |> deque.to_list

      let lobby_init =
        lobby_message.Init(
          lobby: lobby_message.Lobby(id: state.lobby.id),
          player: lobby_message.Player(name: player.name, host: player.host),
          players: new_player_list
            |> list.map(fn(p) {
              lobby_message.Player(name: p.name, host: p.host)
            }),
        )
        |> message.LobbyEvent
      actor.send(player.subject, lobby_init)

      let lobby_updated =
        lobby_message.PlayersUpdated(
          players: new_player_list
          |> list.map(fn(p) { lobby_message.Player(name: p.name, host: p.host) }),
        )
        |> message.LobbyEvent
      state.lobby.players
      |> deque.to_list
      |> list.each(fn(p) { actor.send(p.subject, lobby_updated) })

      let lobby = lobby.Lobby(..state.lobby, players: new_players)
      actor.continue(RoomState(..state, lobby:))
    }

    msg.LeaveLobby(player) -> {
      case lobby.remove_player(state.lobby, player) {
        Error(_) -> actor.Stop(process.Normal)
        Ok(lobby) -> {
          let player_list = lobby.players |> deque.to_list
          let lobby_updated =
            lobby_message.PlayersUpdated(
              players: player_list
              |> list.map(fn(p) {
                lobby_message.Player(name: p.name, host: p.host)
              }),
            )
            |> message.LobbyEvent
          player_list
          |> list.each(fn(p) { actor.send(p.subject, lobby_updated) })

          actor.continue(RoomState(..state, lobby:))
        }
      }
    }

    msg.Command(message.LobbyCommand(lobby_command)) -> {
      case lobby_command {
        lobby_message.UnknownCommand -> todo
        lobby_message.StartGame -> {
          case state.game {
            Some(_) -> todo as "handle starting an already started game"
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
                  game_message.Init(
                    game: game_message.Game(id: game.id),
                    player: game_message.Player(name: player.name),
                    players: player_list
                      |> list.map(fn(p) { game_message.Player(name: p.name) }),
                  )
                  |> message.GameEvent
                actor.send(player.subject, game_init)
              })

              actor.continue(RoomState(..state, game: Some(game)))
            }
          }
        }
      }
    }

    _ -> todo
  }
}
