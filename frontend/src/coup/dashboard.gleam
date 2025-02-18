import gleam/bool
import lib/coup/ids.{type ID}
import lib/coup/json
import lib/coup/message
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/event
import lustre_websocket as ws
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

pub type Dashboard {
  Dashboard(socket: ws.WebSocket, name: String)
}

pub type Command {
  UserUpdatedName(name: String)
  UserCreatedLobby(key_pressed: String)
  UserJoinedLobby(key_pressed: String, id: ID(ids.Lobby))
}

pub fn new(socket: ws.WebSocket) -> Dashboard {
  Dashboard(socket:, name: "")
}

pub fn update(
  dashboard: Dashboard,
  command: Command,
) -> #(Dashboard, Effect(Command)) {
  case command {
    UserUpdatedName(name) -> {
      let dashboard = Dashboard(..dashboard, name: name)
      #(dashboard, effect.none())
    }

    UserCreatedLobby(key_pressed) -> {
      let enter = bool.and(key_pressed == "Enter", dashboard.name != "")
      use <- bool.guard(!enter, #(dashboard, effect.none()))
      let effect =
        message.UserCreateLobby(name: dashboard.name)
        |> message.DashboardCommand
        |> json.encode_command
        |> ws.send(dashboard.socket, _)
      #(dashboard, effect)
    }

    UserJoinedLobby(key_pressed, id) -> {
      let enter = bool.and(key_pressed == "Enter", dashboard.name != "")
      use <- bool.guard(!enter, #(dashboard, effect.none()))

      let effect =
        message.UserJoinLobby(id:, name: dashboard.name)
        |> message.DashboardCommand
        |> json.encode_command
        |> ws.send(dashboard.socket, _)
      #(dashboard, effect)
    }
  }
}

pub fn view(_dashboard: Dashboard) -> Element(Command) {
  html.div_([], [
    html.h1_([], [html.text("Dashboard")]),
    html.input_([
      attribute.placeholder("Type your name ..."),
      event.on_input(UserUpdatedName),
      event.on_keydown(UserCreatedLobby),
    ]),
  ])
}

pub fn view_invitation(
  _dashboard: Dashboard,
  id: ID(ids.Lobby),
) -> Element(Command) {
  html.div_([], [
    html.h1_([], [html.text("Invitation")]),
    html.input_([
      attribute.placeholder("Type your name ..."),
      event.on_input(UserUpdatedName),
      event.on_keydown(UserJoinedLobby(_, id)),
    ]),
  ])
}
