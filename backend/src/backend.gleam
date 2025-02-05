import coup
import coup/lobby
import coup/message as msg
import gleam/bytes_tree
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import json/message
import mist.{type Connection}

pub fn main() {
  let pool = coup.new_pool()

  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        [] -> home()
        ["ws"] -> {
          let room = coup.create_room(pool)
          handle_req_ws(req, room, True)
        }
        ["ws", id] -> {
          case coup.get_room(pool, id) {
            Ok(room) -> handle_req_ws(req, room, False)
            Error(_) -> todo as "handle room not found"
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

fn home() {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("Hello, World!")))
}

fn not_found() {
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_tree.new()))
}

fn handle_req_ws(
  req: Request(Connection),
  room: Subject(msg.Command),
  host: Bool,
) {
  let name =
    request.get_query(req)
    |> result.try(list.key_find(_, "name"))
    |> result.unwrap("")

  mist.websocket(
    request: req,
    handler: fn(player, conn, msg) {
      case msg {
        mist.Text("ping") -> {
          let assert Ok(_) = mist.send_text_frame(conn, "pong")
          actor.continue(player)
        }
        mist.Text(buf) -> {
          let assert Ok(command) = message.decode_command(buf)
          coup.handle_command(room, msg.Command(command))
          actor.continue(player)
        }
        mist.Custom(event) -> {
          let assert Ok(_) = coup.handle_event(conn, event)
          actor.continue(player)
        }
        mist.Binary(_) | mist.Text(_) | mist.Custom(_) -> actor.continue(player)
        mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
      }
    },
    on_init: fn(_state) {
      let player = msg.new_player(name, host)
      let selector =
        process.new_selector()
        |> process.selecting(player.subject, function.identity)
      lobby.join_lobby(room, player)
      #(player, Some(selector))
    },
    on_close: fn(player) { lobby.leave_lobby(room, player) },
  )
}
