import coup/dashboard
import coup/game
import coup/lobby
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/uri
import lib/coup.{type Room}
import lib/coup/json
import lib/coup/message
import lib/id.{type Id}
import lib/just
import lustre/effect.{type Effect}
import lustre_websocket as ws
import modem
import sketch/css
import sketch/css/length
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

pub type Model {
  Model(page: Option(Page))
}

pub fn init(_flags) -> #(Model, Effect(Message)) {
  #(Model(page: None), ws.init("ws://127.0.0.1:8080/ws", WebSocket))
}

pub type Message {
  WebSocket(ws_event: ws.WebSocketEvent)
  Event(event: message.Event)
  DashboardCommand(dashboard.Command)
  LobbyCommand(lobby.Command)
  GameCommand(game.Command)
}

pub fn update(model: Model, msg: Message) -> #(Model, Effect(Message)) {
  use page <- just.try_some(model.page, fn() {
    case msg {
      WebSocket(ws.OnOpen(socket)) -> {
        let dashboard = dashboard.new(socket)
        let page = case modem.initial_uri() {
          Error(_) -> DashboardPage(dashboard)
          Ok(uri) ->
            case uri.path_segments(uri.path) {
              [id] -> InvitationPage(dashboard, id |> id.from_string)
              _ -> DashboardPage(dashboard)
            }
        }
        #(Model(page: Some(page)), effect.none())
      }
      _ -> #(model, effect.none())
    }
  })

  case page, msg {
    _, WebSocket(ws.OnClose(_)) -> #(Model(page: None), effect.none())

    _, WebSocket(ws.OnTextMessage(buf)) -> {
      case json.decode_event(buf) {
        Error(reason) -> {
          io.debug(reason)
          #(model, effect.none())
        }
        Ok(event) -> update(model, Event(event))
      }
    }

    _, Event(event) -> handle_event(model, event)

    DashboardPage(dashboard), DashboardCommand(command) -> {
      let #(dashboard, effect) = dashboard |> dashboard.update(command)
      let model = Model(page: Some(DashboardPage(dashboard)))
      let effect = effect |> effect.map(DashboardCommand)
      #(model, effect)
    }

    InvitationPage(dashboard, id), DashboardCommand(command) -> {
      let #(dashboard, effect) = dashboard |> dashboard.update(command)
      let model = Model(page: Some(InvitationPage(dashboard, id)))
      let effect = effect |> effect.map(DashboardCommand)
      #(model, effect)
    }

    LobbyPage(lobby), LobbyCommand(command) -> {
      let #(lobby, effect) = lobby |> lobby.update(command)
      let model = Model(page: Some(LobbyPage(lobby)))
      let effect = effect |> effect.map(LobbyCommand)
      #(model, effect)
    }

    GamePage(game), GameCommand(command) -> {
      let #(game, effect) = game |> game.update(command)
      let model = Model(page: Some(GamePage(game)))
      let effect = effect |> effect.map(GameCommand)
      #(model, effect)
    }

    _, _ -> #(model, effect.none())
  }
}

pub type Page {
  DashboardPage(dashboard.Dashboard)
  InvitationPage(dashboard.Dashboard, id: Id(Room))
  LobbyPage(lobby.Lobby)
  GamePage(game.Game)
}

fn handle_event(model: Model, event: message.Event) -> #(Model, Effect(Message)) {
  case event {
    message.ErrorEvent(err) -> {
      io.debug(err)
      #(model, effect.none())
    }

    message.LobbyEvent(lobby_event) -> {
      use page <- just.try_some(model.page, fn() { #(model, effect.none()) })
      case page {
        DashboardPage(dashboard) | InvitationPage(dashboard, _) -> {
          case lobby_event {
            message.LobbyInit(..) -> {
              let lobby = lobby.new(dashboard.socket)
              let model = Model(page: Some(LobbyPage(lobby)))
              handle_event(model, event)
            }
            _ -> #(model, effect.none())
          }
        }
        LobbyPage(lobby) -> handle_lobby_event(model, lobby, lobby_event)
        _ -> #(model, effect.none())
      }
    }

    message.GameEvent(game_event) -> {
      use page <- just.try_some(model.page, fn() { #(model, effect.none()) })
      case page {
        LobbyPage(lobby) -> {
          case game_event {
            message.GameInit(..) -> {
              let game = game.new(lobby.socket)
              let model = Model(page: Some(GamePage(game)))
              handle_event(model, event)
            }
            _ -> #(model, effect.none())
          }
        }
        GamePage(game) -> handle_game_event(model, game, game_event)
        _ -> #(model, effect.none())
      }
    }
  }
}

fn handle_lobby_event(
  model: Model,
  lobby: lobby.Lobby,
  event: message.LobbyEvent,
) -> #(Model, Effect(Message)) {
  case event {
    message.LobbyInit(id, users, user_id, host_id) -> {
      let lobby = lobby |> lobby.init(id, users, user_id, host_id)
      let model = Model(page: Some(LobbyPage(lobby)))
      #(model, modem.push("/" <> id.to_string(lobby.id), None, None))
    }
    message.LobbyUpdatedUsers(users, host_id) -> {
      let lobby = lobby |> lobby.update_users(users, host_id)
      let model = Model(page: Some(LobbyPage(lobby)))
      #(model, effect.none())
    }
  }
}

fn handle_game_event(
  model: Model,
  game: game.Game,
  event: message.GameEvent,
) -> #(Model, Effect(Message)) {
  case event {
    message.GameInit(id, players, player_id, deck_count) -> {
      let game = game |> game.init(id, players, player_id, deck_count)
      let model = Model(page: Some(GamePage(game)))
      #(model, effect.none())
    }
  }
}

pub fn view(model: Model) -> Element(Message) {
  use page <- just.try_some(model.page, fn() { element.none() })
  let page = case page {
    DashboardPage(dashboard) ->
      dashboard |> dashboard.view() |> element.map(DashboardCommand)
    InvitationPage(dashboard, id) ->
      dashboard
      |> dashboard.view_invitation(id)
      |> element.map(DashboardCommand)
    LobbyPage(lobby) -> lobby |> lobby.view() |> element.map(LobbyCommand)
    GamePage(game) -> game |> game.view() |> element.map(GameCommand)
  }
  html.main(main_style(), [], [page])
}

fn main_style() -> css.Class {
  css.class([css.height(length.vh(100))])
}
