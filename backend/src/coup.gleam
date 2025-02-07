import coup/room
import domain
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/option.{Some}
import gleam/otp/actor
import lib/ids

const timeout = 100

const id_length = 8

pub type PoolState {
  PoolState(
    rooms: dict.Dict(String, domain.Room),
    selector: process.Selector(PoolMessage),
  )
}

pub type PoolMessage {
  DeleteRoom(process.ProcessDown, id: String)
  CreateRoom(reply_with: Subject(domain.Room))
  GetRoom(reply_with: Subject(Result(domain.Room, Nil)), id: String)
}

pub fn new_pool() -> Subject(PoolMessage) {
  let assert Ok(subject) =
    actor.start_spec(
      actor.Spec(init_timeout: timeout, loop: pool_loop, init: fn() {
        let subject = process.new_subject()
        let selector =
          process.new_selector()
          |> process.selecting(subject, function.identity)
        let state = PoolState(rooms: dict.new(), selector: selector)
        actor.Ready(state, selector)
      }),
    )
  subject
}

pub fn create_room(pool: Subject(PoolMessage)) -> domain.Room {
  actor.call(pool, CreateRoom(_), timeout)
}

pub fn get_room(
  pool: Subject(PoolMessage),
  id: String,
) -> Result(domain.Room, Nil) {
  actor.call(pool, GetRoom(_, id), timeout)
}

fn pool_loop(
  message: PoolMessage,
  state: PoolState,
) -> actor.Next(PoolMessage, PoolState) {
  case message {
    DeleteRoom(_, id) -> {
      let state = PoolState(..state, rooms: dict.delete(state.rooms, id))
      actor.continue(state)
    }

    CreateRoom(reply_with) -> {
      let id = ids.generate(id_length)
      let room = room.new_room(id)
      actor.send(reply_with, room)

      let monitor =
        room
        |> process.subject_owner
        |> process.monitor_process

      let selector =
        state.selector
        |> process.selecting_process_down(monitor, DeleteRoom(_, id))

      let state =
        PoolState(rooms: dict.insert(state.rooms, id, room), selector:)

      actor.Continue(state, Some(selector))
    }

    GetRoom(reply_with, id) -> {
      dict.get(state.rooms, id)
      |> actor.send(reply_with, _)
      actor.continue(state)
    }
  }
}
