import gleam/int
import gleam/list
import gleam/string
import lustre/effect.{type Effect}
import sketch/css
import sketch/css/length
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html

pub type Model =
  Int

pub fn init(_flags) -> #(Model, Effect(Message)) {
  #(0, effect.none())
}

pub type Message

pub fn update(_model: Model, _msg: Message) -> #(Model, Effect(Message)) {
  #(0, effect.none())
}

pub fn view(_model: Model) -> Element(Message) {
  html.main(main_style(), [], [view_board(4)])
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
