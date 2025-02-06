import coup/game.{type Game}
import coup/lobby.{type Lobby}
import coup/message.{type Command} as msg
import gleam/bool
import gleam/deque
import gleam/erlang/process.{type Subject}
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
    msg.JoinLobby(player) -> {
      let new_players = state.lobby.players |> deque.push_back(player)
      let new_player_list = new_players |> deque.to_list

      let lobby_init =
        json.LobbyInit(
          lobby: json.Lobby(id: state.lobby.id),
          player: json.LobbyPlayer(name: player.name, host: player.host),
          players: new_player_list
            |> list.map(fn(p) { json.LobbyPlayer(name: p.name, host: p.host) }),
        )
        |> json.LobbyEvent
      actor.send(player.subject, lobby_init)

      let lobby_updated =
        json.LobbyPlayersUpdated(
          players: new_player_list
          |> list.map(fn(p) { json.LobbyPlayer(name: p.name, host: p.host) }),
        )
        |> json.LobbyEvent
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
            json.LobbyPlayersUpdated(
              players: player_list
              |> list.map(fn(p) { json.LobbyPlayer(name: p.name, host: p.host) }),
            )
            |> json.LobbyEvent
          player_list
          |> list.each(fn(p) { actor.send(p.subject, lobby_updated) })

          actor.continue(RoomState(..state, lobby:))
        }
      }
    }

    msg.Command(json.LobbyCommand(lobby_command)) -> {
      case lobby_command {
        json.LobbyStartGame -> {
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
