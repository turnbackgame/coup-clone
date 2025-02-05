import coup/game.{type Game}
import coup/lobby.{type Lobby}
import coup/message.{type Command} as msg
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
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
      let lobby = state.lobby

      lobby_message.Init(
        lobby: lobby_message.Lobby(id: lobby.id),
        player: lobby_message.Player(name: player.name, host: player.host),
        players: lobby.players
          |> list.prepend(player)
          |> list.reverse
          |> list.map(fn(p) { lobby_message.Player(name: p.name, host: p.host) }),
      )
      |> message.LobbyEvent
      |> actor.send(player.subject, _)

      let lobby_updated =
        lobby_message.PlayersUpdated(
          players: lobby.players
          |> list.prepend(player)
          |> list.reverse
          |> list.map(fn(p) { lobby_message.Player(name: p.name, host: p.host) }),
        )
        |> message.LobbyEvent
      lobby.players
      |> list.each(fn(p) { actor.send(p.subject, lobby_updated) })

      let players =
        lobby.players
        |> list.prepend(player)
      let lobby = lobby.Lobby(..lobby, players:)
      actor.continue(RoomState(..state, lobby:))
    }

    msg.LeaveLobby(player) -> {
      let lobby = state.lobby
      let players = list.filter(lobby.players, fn(p) { p != player })

      use <- bool.guard(
        list.is_empty(lobby.players),
        actor.Stop(process.Normal),
      )

      let lobby_updated =
        lobby_message.PlayersUpdated(
          players: players
          |> list.reverse
          |> list.map(fn(p) { lobby_message.Player(name: p.name, host: p.host) }),
        )
        |> message.LobbyEvent
      players
      |> list.each(fn(p) { actor.send(p.subject, lobby_updated) })

      let lobby = lobby.Lobby(..lobby, players:)
      actor.continue(RoomState(..state, lobby:))
    }

    msg.Command(message.LobbyCommand(lobby_command)) -> {
      case lobby_command {
        lobby_message.UnknownCommand -> todo
        lobby_message.StartGame -> {
          case state.game {
            Some(_) -> todo as "handle starting an already started game"
            None -> {
              case list.length(state.lobby.players) {
                player_count if player_count < 2 ->
                  todo as "handle starting the game with not enough players"
                _ -> {
                  let game =
                    game.Game(id: state.id, players: state.lobby.players)

                  game.players
                  |> list.each(fn(player) {
                    game_message.Init(
                      game: game_message.Game(id: game.id),
                      player: game_message.Player(name: player.name),
                      players: game.players
                        |> list.reverse
                        |> list.map(fn(p) { game_message.Player(name: p.name) }),
                    )
                    |> message.GameEvent
                    |> actor.send(player.subject, _)
                  })

                  actor.continue(RoomState(..state, game: Some(game)))
                }
              }
            }
          }
        }
      }
    }

    _ -> todo
  }
}
