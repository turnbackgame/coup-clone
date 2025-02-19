import gleam/bool
import gleam/list
import lib/coup.{type Actor, type Room}
import lib/coup/json
import lib/coup/message
import lib/id.{type Id}
import lustre/effect.{type Effect}
import lustre/event
import lustre_websocket as ws
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

pub type Lobby {
  Lobby(
    socket: ws.WebSocket,
    id: Id(Room),
    users: List(message.User),
    user_id: Id(Actor),
    host_id: Id(Actor),
  )
}

pub fn new(socket: ws.WebSocket) -> Lobby {
  Lobby(
    socket:,
    id: id.new_empty(),
    users: [],
    user_id: id.new_empty(),
    host_id: id.new_empty(),
  )
}

pub type Command {
  UserLeavedLobby
  UserStartedGame
}

pub fn update(lobby: Lobby, command: Command) -> #(Lobby, Effect(Command)) {
  case command {
    UserLeavedLobby -> {
      let effect =
        message.UserLeaveLobby
        |> message.LobbyCommand
        |> json.encode_command
        |> ws.send(lobby.socket, _)
      #(lobby, effect)
    }

    UserStartedGame -> {
      let effect =
        message.UserStartGame
        |> message.LobbyCommand
        |> json.encode_command
        |> ws.send(lobby.socket, _)
      #(lobby, effect)
    }
  }
}

pub fn init(
  lobby: Lobby,
  id: Id(Room),
  users: List(message.User),
  user_id: Id(Actor),
  host_id: Id(Actor),
) -> Lobby {
  Lobby(..lobby, id: id, users:, user_id:, host_id:)
}

pub fn update_users(
  lobby: Lobby,
  users: List(message.User),
  host_id: Id(Actor),
) -> Lobby {
  Lobby(..lobby, users:, host_id:)
}

pub fn view(lobby: Lobby) -> Element(Command) {
  let users =
    html.ul_(
      [],
      lobby.users |> list.map(fn(p) { html.li_([], [html.text(p.name)]) }),
    )

  let start_button = {
    use <- bool.guard(lobby.user_id != lobby.host_id, element.none())
    html.button_([event.on_click(UserStartedGame)], [html.text("start")])
  }

  html.div_([], [users, start_button])
}
