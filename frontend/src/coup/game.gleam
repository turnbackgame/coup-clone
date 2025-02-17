import gleam/int
import gleam/list
import gleam/string
import lib/message
import lustre/effect.{type Effect}
import lustre_websocket as ws
import sketch/css
import sketch/css/length
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

pub type Game {
  Game(
    socket: ws.WebSocket,
    id: String,
    players: List(message.Player),
    player_id: String,
    deck_count: Int,
  )
}

pub type Command

pub fn new(socket: ws.WebSocket) -> Game {
  Game(socket:, id: "", players: [], player_id: "", deck_count: 0)
}

pub fn update(_game: Game, _command: Command) -> #(Game, Effect(Command)) {
  todo
}

pub fn init(
  game: Game,
  id: String,
  players: List(message.Player),
  player_id: String,
  deck_count: Int,
) -> Game {
  Game(..game, id: id, players:, player_id:, deck_count:)
}

pub fn view(game: Game) -> Element(Command) {
  view_board(game)
}

fn view_board(game: Game) -> Element(Command) {
  let players_div =
    game.players
    |> list.index_map(fn(player, no) {
      html.div(player_area(no + 1), [], [view_player(player)])
    })

  html.div(board_style(players(list.length(players_div))), [], [
    html.div(court_area(), [], [html.text("court")]),
    ..players_div
  ])
}

fn view_player(player: message.Player) -> Element(Command) {
  let left_text = message.card_to_string(player.influence.left)
  let right_text = message.card_to_string(player.influence.right)
  html.text(player.name <> ": " <> left_text <> ", " <> right_text)
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
