import coup
import gleam/bytes_tree
import gleam/erlang/process
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import mist.{type Connection}

pub fn main() {
  let pool = coup.new_pool()

  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        [] -> home()
        ["ws"] -> {
          let lobby = coup.create_lobby(pool)
          handle_req_ws(req, lobby)
        }
        ["ws", id] -> {
          case coup.get_lobby(pool, coup.ID(id)) {
            Ok(lobby) -> handle_req_ws(req, lobby)
            Error(_) -> not_found()
          }
        }
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

fn home() {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("Hello, World!")))
}

fn handle_req_ws(req: Request(Connection), lobby: coup.Lobby) {
  let name =
    request.get_query(req)
    |> result.try(list.key_find(_, "name"))
    |> result.unwrap("")

  mist.websocket(
    request: req,
    handler: handle_message_ws,
    on_init: fn(_state) {
      let player = coup.new_player(name)
      let selector =
        process.new_selector()
        |> process.selecting(player.subject, function.identity)
      coup.join_lobby(lobby, player)
      #(player, Some(selector))
    },
    on_close: fn(player) { coup.leave_lobby(lobby, player) },
  )
}

fn handle_message_ws(
  player: coup.Player,
  conn: mist.WebsocketConnection,
  message: mist.WebsocketMessage(coup.PlayerMessage),
) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(player)
    }
    mist.Custom(message) -> {
      let assert Ok(_) = coup.handle_player_message(conn, message)
      actor.continue(player)
    }
    mist.Binary(_) | mist.Text(_) | mist.Custom(_) -> actor.continue(player)
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}
