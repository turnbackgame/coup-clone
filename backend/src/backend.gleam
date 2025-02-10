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
import lib/message/json
import mist.{type Connection}

pub fn main() {
  let pool = coup.new_pool()

  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        [] -> home()
        ["ws"] -> {
          let room = coup.create_room(pool)
          handle_req_ws(req, room)
        }
        ["ws", id] -> {
          case coup.get_room(pool, id) {
            Ok(room) -> handle_req_ws(req, room)
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

fn handle_req_ws(req: Request(Connection), room: coup.Room) {
  let name =
    request.get_query(req)
    |> result.try(list.key_find(_, "name"))
    |> result.unwrap("")

  mist.websocket(
    request: req,
    handler: fn(user, conn, msg) {
      case msg {
        mist.Text("ping") -> {
          let assert Ok(_) = mist.send_text_frame(conn, "pong")
          actor.continue(user)
        }
        mist.Text(buf) -> {
          let assert Ok(command) = json.decode_command(buf)
          coup.handle_command(user, command)
          |> actor.send(room, _)
          actor.continue(user)
        }
        mist.Custom(event) -> {
          let assert Ok(_) =
            coup.handle_event(user, event)
            |> json.encode_event
            |> mist.send_text_frame(conn, _)
          actor.continue(user)
        }
        mist.Binary(_) | mist.Text(_) | mist.Custom(_) -> actor.continue(user)
        mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
      }
    },
    on_init: fn(_state) {
      let user = coup.new_user(name)
      let selector =
        process.new_selector()
        |> process.selecting(user.subject, function.identity)
      coup.join_lobby(room, user)
      #(user, Some(selector))
    },
    on_close: fn(user) { coup.leave_lobby(room, user) },
  )
}
