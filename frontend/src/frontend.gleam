import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/effect.{type Effect}
import sketch
import sketch/lustre as sketch_lustre
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html
import sketch/size

pub fn main() {
  let assert Ok(cache) = sketch.cache(strategy: sketch.Ephemeral)
  sketch_lustre.node()
  |> sketch_lustre.compose(view, cache)
  |> lustre.application(init, update, _)
  |> lustre.start("#app", Nil)
}

type Model =
  Int

fn init(_) -> #(Model, Effect(Msg)) {
  #(0, effect.none())
}

pub type Msg

fn update(_model: Model, _msg: Msg) -> #(Model, Effect(Msg)) {
  #(0, effect.none())
}

fn view(_model: Model) -> Element(Msg) {
  html.main(main_style(), [], [view_board(4)])
}

fn main_style() {
  sketch.class([sketch.height(size.vh(100))])
}

fn view_board(player_count: Int) -> Element(Msg) {
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

fn board_style(players: sketch.Class) {
  sketch.class([
    sketch.compose(players),
    sketch.display("grid"),
    sketch.gap(size.rem(1.0)),
    sketch.min_height(size.vh(100)),
  ])
}

fn players(player_count: Int) {
  case player_count {
    2 ->
      sketch.class([
        sketch.grid_template_areas([
          ".  p2 p2 .",
          repeat("court", 4),
          ". p1 p1 .",
        ]),
        sketch.grid_template_columns(repeat("1fr", 4)),
        sketch.grid_template_rows("auto 1fr auto"),
      ])
    3 ->
      sketch.class([
        sketch.grid_template_areas([
          "p2 p2 p3 p3",
          repeat("court", 4),
          ". p1 p1 .",
        ]),
        sketch.grid_template_columns(repeat("1fr", 4)),
        sketch.grid_template_rows("auto 1fr auto"),
      ])
    4 ->
      sketch.class([
        sketch.grid_template_areas([
          "p2 p2 p3 p3 p4 p4",
          repeat("court", 6),
          ". . p1 p1 . .",
        ]),
        sketch.grid_template_columns(repeat("1fr", 6)),
        sketch.grid_template_rows("auto 1fr auto"),
      ])
    5 ->
      sketch.class([
        sketch.grid_template_areas([
          "p2 p2 p3 p3 p4 p4 p5 p5",
          repeat("court", 8),
          ". . . p1 p1 . . .",
        ]),
        sketch.grid_template_columns(repeat("1fr", 8)),
        sketch.grid_template_rows("auto 1fr auto"),
      ])
    6 ->
      sketch.class([
        sketch.grid_template_areas([
          "p2 p2 p3 p3 p4 p4 p5 p5 p6 p6",
          repeat("court", 10),
          ". . . . p1 p1 . . . .",
        ]),
        sketch.grid_template_columns(repeat("1fr", 10)),
        sketch.grid_template_rows("auto 1fr auto"),
      ])
    // TODO: handle properly
    _ -> sketch.class([])
  }
}

fn court_area() {
  sketch.class([
    sketch.grid_area("court"),
    sketch.compose(center()),
    sketch.compose(border()),
  ])
}

fn player_area(number: Int) {
  sketch.class([
    sketch.grid_area("p" <> int.to_string(number)),
    sketch.compose(center()),
    sketch.compose(border()),
  ])
}

fn center() {
  sketch.class([
    sketch.display("flex"),
    sketch.justify_content("center"),
    sketch.align_items("center"),
  ])
}

fn border() {
  sketch.class([sketch.border_style("solid"), sketch.border_color("turquoise")])
}

fn repeat(item: String, times: Int) -> String {
  list.repeat(item, times)
  |> string.join(" ")
}
