import coup/game
import coup/lobby
import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri
import json/game_message
import json/lobby_message
import json/message
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/event
import lustre_websocket as ws
import modem
import sketch/css
import sketch/css/length
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

pub type Model {
  Model(name: String, socket: Option(ws.WebSocket), page: Page)
}

pub fn init(_flags) -> #(Model, Effect(Message)) {
  let page = case modem.initial_uri() {
    Error(_) -> DashboardPage
    Ok(uri) -> {
      case uri.path_segments(uri.path) {
        [id] -> PreLobbyPage(id)
        _ -> DashboardPage
      }
    }
  }
  #(Model(name: "", socket: None, page:), effect.none())
}

pub type Message {
  WebSocket(ws_event: ws.WebSocketEvent)

  Event(event: message.Event)
  Command(command: message.Command)

  UserUpdatedName(name: String)
  UserCreatedLobby(key_pressed: String)
  UserJoinedLobby(key_pressed: String)
}

pub fn update(model: Model, msg: Message) -> #(Model, Effect(Message)) {
  case model.page, msg {
    _, WebSocket(ws_event) -> {
      case ws_event {
        ws.InvalidUrl -> todo as "handle invalid URL"
        ws.OnBinaryMessage(_) -> todo as "handle binary message"
        ws.OnOpen(socket) -> {
          #(Model(..model, socket: Some(socket)), effect.none())
        }
        ws.OnClose(_) -> {
          #(Model(..model, socket: None), effect.none())
        }
        ws.OnTextMessage(buf) -> {
          case message.decode_event(buf) {
            Error(_) -> todo as "handle decode event error"
            Ok(event) -> update(model, Event(event))
          }
        }
      }
    }

    _, Event(event) -> handle_event(model, event)
    _, Command(command) -> handle_command(model, command)

    _, UserUpdatedName(name) -> #(Model(..model, name:), effect.none())

    DashboardPage, UserCreatedLobby(key_pressed) -> {
      let enter = bool.and(key_pressed == "Enter", model.name != "")
      use <- bool.guard(bool.negate(enter), #(model, effect.none()))
      let effect =
        ws.init("ws://127.0.0.1:8080/ws?name=" <> model.name, WebSocket)
      #(model, effect)
    }

    PreLobbyPage(id), UserJoinedLobby(key_pressed) -> {
      let enter = bool.and(key_pressed == "Enter", model.name != "")
      use <- bool.guard(bool.negate(enter), #(model, effect.none()))
      let effect =
        ws.init(
          "ws://127.0.0.1:8080/ws/" <> id <> "?name=" <> model.name,
          WebSocket,
        )
      #(model, effect)
    }

    _, _ -> todo
  }
}

pub type Page {
  DashboardPage
  PreLobbyPage(id: String)
  LobbyPage(lobby.Model)
  GamePage(game.Model)
}

fn handle_event(model: Model, event: message.Event) -> #(Model, Effect(Message)) {
  case event {
    message.LobbyEvent(lobby_event) -> {
      case model.page {
        DashboardPage | PreLobbyPage(_) -> {
          case lobby_event {
            lobby_message.Init(..) -> {
              let assert Some(socket) = model.socket
              let lobby = lobby.new(socket)
              let model = Model(..model, page: LobbyPage(lobby))
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
      case model.page {
        LobbyPage(..) -> {
          case game_event {
            game_message.Init(..) -> {
              let assert Some(socket) = model.socket
              let game = game.new(socket)
              let model = Model(..model, page: GamePage(game))
              handle_event(model, event)
            }
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
  lobby: lobby.Model,
  event: lobby_message.Event,
) -> #(Model, Effect(Message)) {
  case event {
    lobby_message.Init(msg_lobby, msg_player, msg_players) -> {
      let lobby = lobby.init(lobby, msg_lobby, msg_player, msg_players)
      let model = Model(..model, page: LobbyPage(lobby))
      #(model, modem.push("/" <> lobby.id, None, None))
    }

    lobby_message.PlayersUpdated(msg_players) -> {
      let lobby = lobby.update_players(lobby, msg_players)
      let model = Model(..model, page: LobbyPage(lobby))
      #(model, effect.none())
    }
  }
}

fn handle_game_event(
  model: Model,
  game: game.Model,
  event: game_message.Event,
) -> #(Model, Effect(Message)) {
  case event {
    game_message.Init(msg_game, msg_player, msg_players) -> {
      let game = game.init(game, msg_game, msg_player, msg_players)
      let model = Model(..model, page: GamePage(game))
      #(model, effect.none())
    }
  }
}

fn handle_command(
  model: Model,
  command: message.Command,
) -> #(Model, Effect(Message)) {
  case model.page, command {
    LobbyPage(lobby), message.LobbyCommand(lobby_command) -> {
      handle_lobby_command(model, lobby, lobby_command)
    }
    _, _ -> #(model, effect.none())
  }
}

fn handle_lobby_command(
  model: Model,
  lobby: lobby.Model,
  command: lobby_message.Command,
) -> #(Model, Effect(Message)) {
  case command {
    lobby_message.StartGame -> #(model, lobby.start_game(lobby))
  }
}

pub fn view(model: Model) -> Element(Message) {
  let page = case model.page {
    DashboardPage -> view_dashboard()
    PreLobbyPage(_) -> view_pre_lobby()
    LobbyPage(lobby) -> view_lobby(lobby)
    GamePage(game) -> view_game(game)
  }
  html.main(main_style(), [], [page])
}

fn view_dashboard() -> Element(Message) {
  html.div_([], [
    html.h1_([], [html.text("Dashboard")]),
    html.input_([
      attribute.placeholder("Type your name ..."),
      event.on_input(UserUpdatedName),
      event.on_keydown(UserCreatedLobby),
    ]),
  ])
}

fn view_pre_lobby() -> Element(Message) {
  html.div_([], [
    html.h1_([], [html.text("Pre-Lobby")]),
    html.input_([
      attribute.placeholder("Type your name ..."),
      event.on_input(UserUpdatedName),
      event.on_keydown(UserJoinedLobby),
    ]),
  ])
}

fn view_lobby(lobby: lobby.Model) -> Element(Message) {
  html.div_([], [
    html.p_([], [
      html.text(
        "dear " <> lobby.player.name <> ", welcome to lobby " <> lobby.id,
      ),
    ]),
    html.ul_(
      [],
      lobby.players |> list.map(fn(p) { html.li_([], [html.text(p.name)]) }),
    ),
    html.button_(
      [
        event.on_click(
          lobby_message.StartGame
          |> message.LobbyCommand
          |> Command,
        ),
      ],
      [html.text("start")],
    ),
  ])
}

fn view_game(game: game.Model) -> Element(Message) {
  html.div_([], [
    html.p_([], [
      html.text("dear " <> game.player.name <> ", welcome to game " <> game.id),
    ]),
    html.ul_(
      [],
      game.players |> list.map(fn(p) { html.li_([], [html.text(p.name)]) }),
    ),
  ])
}

fn main_style() -> css.Class {
  css.class([css.height(length.vh(100))])
}

fn view_board(player_count: Int) -> Element(Message) {
  let players_div =
    list.range(1, player_count)
    |> list.map(fn(no: Int) {
      html.div(player_area(no), [], [html.text("player " <> int.to_string(no))])
    })

  html.div(board_style(players(player_count)), [], [
    html.div(court_area(), [], [html.text("court")]),
    ..players_div
  ])
}

fn board_style(players) -> css.Class {
  css.class([
    css.compose(players),
    css.display("grid"),
    css.gap(length.rem(1.0)),
    css.min_height(length.vh(100)),
  ])
}

fn players(player_count: Int) {
  case player_count {
    2 ->
      css.class([
        css.grid_template_areas([".  p2 p2 .", repeat("court", 4), ". p1 p1 ."]),
        css.grid_template_columns(repeat("1fr", 4)),
        css.grid_template_rows("auto 1fr auto"),
      ])
    3 ->
      css.class([
        css.grid_template_areas(["p2 p2 p3 p3", repeat("court", 4), ". p1 p1 ."]),
        css.grid_template_columns(repeat("1fr", 4)),
        css.grid_template_rows("auto 1fr auto"),
      ])
    4 ->
      css.class([
        css.grid_template_areas([
          "p2 p2 p3 p3 p4 p4",
          repeat("court", 6),
          ". . p1 p1 . .",
        ]),
        css.grid_template_columns(repeat("1fr", 6)),
        css.grid_template_rows("auto 1fr auto"),
      ])
    5 ->
      css.class([
        css.grid_template_areas([
          "p2 p2 p3 p3 p4 p4 p5 p5",
          repeat("court", 8),
          ". . . p1 p1 . . .",
        ]),
        css.grid_template_columns(repeat("1fr", 8)),
        css.grid_template_rows("auto 1fr auto"),
      ])
    6 ->
      css.class([
        css.grid_template_areas([
          "p2 p2 p3 p3 p4 p4 p5 p5 p6 p6",
          repeat("court", 10),
          ". . . . p1 p1 . . . .",
        ]),
        css.grid_template_columns(repeat("1fr", 10)),
        css.grid_template_rows("auto 1fr auto"),
      ])
    // TODO: handle properly
    _ -> css.class([])
  }
}

fn court_area() -> css.Class {
  css.class([
    css.grid_area("court"),
    css.compose(center()),
    css.compose(border()),
  ])
}

fn player_area(number: Int) -> css.Class {
  css.class([
    css.grid_area("p" <> int.to_string(number)),
    css.compose(center()),
    css.compose(border()),
  ])
}

fn center() -> css.Class {
  css.class([
    css.display("flex"),
    css.justify_content("center"),
    css.align_items("center"),
  ])
}

fn border() -> css.Class {
  css.class([css.border_style("solid"), css.border_color("turquoise")])
}

fn repeat(item: String, times: Int) -> String {
  list.repeat(item, times)
  |> string.join(" ")
}
