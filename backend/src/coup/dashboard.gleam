import coup/lobby.{type Lobby}
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/option.{Some}
import gleam/otp/actor
import gleam/result
import lib/coup.{type Room}
import lib/generator
import lib/id.{type Id}

const timeout = 100

pub type Dashboard =
  Subject(Message)

type State {
  State(
    lobbies: dict.Dict(Id(Room), Lobby),
    selector: process.Selector(Message),
  )
}

pub type Message {
  DeleteLobby(process.ProcessDown, id: Id(Room))
  GetLobby(reply: Subject(Result(Lobby, coup.Error)), id: Id(Room))
  CreateLobby(reply: Subject(Lobby))
}

pub fn new() -> Dashboard {
  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    let dashboard = State(lobbies: dict.new(), selector: selector)
    actor.Ready(dashboard, selector)
  }

  let assert Ok(subject) =
    actor.start_spec(actor.Spec(init:, init_timeout: 100, loop:))
  subject
}

pub fn create_lobby(dashboard: Dashboard) -> Lobby {
  actor.call(dashboard, CreateLobby, timeout)
}

pub fn get_lobby(
  dashboard: Dashboard,
  id: Id(Room),
) -> Result(Lobby, coup.Error) {
  actor.call(dashboard, GetLobby(_, id), timeout)
}

fn loop(msg: Message, dashboard: State) -> actor.Next(Message, State) {
  case msg {
    DeleteLobby(_, id) -> {
      State(..dashboard, lobbies: dashboard.lobbies |> dict.delete(id))
      |> actor.continue
    }

    GetLobby(reply, id) -> {
      dashboard.lobbies
      |> dict.get(id)
      |> result.map_error(fn(_) { coup.LobbyNotExist })
      |> actor.send(reply, _)
      actor.continue(dashboard)
    }

    CreateLobby(reply) -> {
      let id = generator.generate(8) |> id.from_string
      let lobby = lobby.new(id)

      let monitor =
        lobby
        |> process.subject_owner
        |> process.monitor_process

      let selector =
        dashboard.selector
        |> process.selecting_process_down(monitor, DeleteLobby(_, id))

      let dashboard =
        State(lobbies: dict.insert(dashboard.lobbies, id, lobby), selector:)

      actor.send(reply, lobby)
      actor.Continue(dashboard, Some(selector))
    }
  }
}
