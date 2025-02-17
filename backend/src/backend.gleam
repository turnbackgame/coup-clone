import coup/dashboard
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import mist
import websocket

pub fn main() {
  let dashboard = dashboard.new()

  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        ["ws"] -> websocket.handle_request(req, dashboard)
        _ -> not_found()
      }
    }
    |> mist.new
    |> mist.port(8080)
    |> mist.start_http

  process.sleep_forever()
}

fn not_found() {
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_tree.new()))
}
