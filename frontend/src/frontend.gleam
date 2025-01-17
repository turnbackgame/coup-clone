import coup
import lustre
import sketch
import sketch/lustre as sketch_lustre

pub fn main() {
  let assert Ok(stylesheet) = sketch.stylesheet(strategy: sketch.Ephemeral)
  let assert Ok(_) =
    lustre.application(coup.init, coup.update, fn(model) {
      use <- sketch_lustre.render(stylesheet, [sketch_lustre.node()])
      coup.view(model)
    })
    |> lustre.start("#app", Nil)
}
