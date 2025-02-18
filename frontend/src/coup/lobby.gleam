import gleam/bool
import gleam/list
import lib/coup/ids.{type ID}
import lib/coup/json
import lib/coup/message
import lustre/effect.{type Effect}
import lustre/event
import lustre_websocket as ws
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

pub type Lobby {
  Lobby(
    socket: ws.WebSocket,
    id: ID(ids.Lobby),
    users: List(message.User),
    user_id: String,
    host_id: String,
  )
}

pub type Command {
  UserLeavedLobby
  UserStartedGame
}

pub fn new(socket: ws.WebSocket) -> Lobby {
  Lobby(socket:, id: ids.from_string(""), users: [], user_id: "", host_id: "")
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

pub fn init(
  lobby: Lobby,
  id: ID(ids.Lobby),
  users: List(message.User),
  user_id: String,
  host_id: String,
) -> Lobby {
  Lobby(..lobby, id: id, users:, user_id: user_id, host_id: host_id)
}

pub fn update_users(
  lobby: Lobby,
  users: List(message.User),
  host_id: String,
) -> Lobby {
  Lobby(..lobby, users:, host_id:)
}
