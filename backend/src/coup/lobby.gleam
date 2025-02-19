import coup/game.{type Game}
import coup/user.{type User, type Users}
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/otp/actor
import gleam/result
import lib/coup.{type Actor, type Room}
import lib/coup/message
import lib/id.{type Id}
import lib/just
import lib/ordered_dict as dict

const timeout = 100

pub type Lobby =
  Subject(Message)

pub fn new(id: Id(Room)) -> Lobby {
  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    let lobby = State(id:, users: dict.new(), host_id: id.new_empty())
    actor.Ready(lobby, selector)
  }

  let loop = fn(msg: Message, lobby: State) {
    handle_command(msg.command, lobby, msg.user)
  }

  let assert Ok(subject) =
    actor.start_spec(actor.Spec(init:, init_timeout: timeout, loop:))
  subject
}

pub fn join(lobby: Lobby, user: User) -> Result(Nil, coup.Error) {
  use reply <- actor.call(lobby, _, timeout)
  Message(user, Join(reply))
}

pub fn leave(lobby: Lobby, user: User) {
  actor.send(lobby, Message(user, Leave))
}

pub fn start_game(lobby: Lobby, user: User) -> Result(Game, coup.Error) {
  use reply <- actor.call(lobby, _, timeout)
  Message(user, StartGame(reply))
}

pub type Message {
  Message(user: User, command: Command)
}

pub type Command {
  Join(reply: Subject(Result(Nil, coup.Error)))
  Leave
  StartGame(reply: Subject(Result(Game, coup.Error)))
}

fn handle_command(
  command: Command,
  lobby: State,
  user: User,
) -> actor.Next(Message, State) {
  case command {
    Join(reply) -> {
      use <- just.try(reply_error(reply, lobby, _))
      use <- guard_lobby_full(lobby)

      let lobby = lobby |> add_user(user) |> try_set_host(user)
      let users = lobby.users |> dict.map(user.to_message) |> dict.to_list()
      actor.send(reply, Ok(Nil))

      use u <- dict.each(lobby.users, Ok(actor.continue(lobby)))
      case u == user {
        True ->
          message.LobbyInit(
            id: lobby.id,
            users: users,
            user_id: u.id,
            host_id: lobby.host_id,
          )
        False -> message.LobbyUpdatedUsers(users:, host_id: lobby.host_id)
      }
      |> send_user_event(u, _)
    }

    Leave -> {
      use <- just.try(fn(_err) { actor.Stop(process.Normal) })
      let lobby = lobby |> remove_user(user)
      use <- guard_lobby_empty(lobby)

      let lobby = lobby |> try_promote_host(user)
      let users = lobby.users |> dict.map(user.to_message) |> dict.to_list()

      use u <- dict.each(lobby.users, Ok(actor.continue(lobby)))
      message.LobbyUpdatedUsers(users:, host_id: lobby.host_id)
      |> send_user_event(u, _)
    }

    StartGame(reply) -> {
      use <- just.try(reply_error(reply, lobby, _))
      use game <- result.try(game.start(lobby.id, lobby.users))
      actor.send(reply, Ok(game))
      Ok(actor.continue(lobby))
    }
  }
}

fn reply_error(
  reply: Subject(Result(a, err)),
  state: state,
  error: err,
) -> actor.Next(message, state) {
  actor.send(reply, Error(error))
  actor.continue(state)
}

fn send_user_event(user: User, event: message.LobbyEvent) {
  actor.send(user.subject, message.LobbyEvent(event))
}

type State {
  State(id: Id(Room), users: Users, host_id: Id(Actor))
}

fn add_user(lobby: State, user: User) -> State {
  let users = lobby.users |> dict.insert_back(user.id, user)
  State(..lobby, users:)
}

fn remove_user(lobby: State, user: User) -> State {
  let users = lobby.users |> dict.delete(user.id)
  State(..lobby, users:)
}

fn try_set_host(lobby: State, user: User) -> State {
  let host_id = case id.is_empty(lobby.host_id) {
    True -> user.id
    False -> lobby.host_id
  }
  State(..lobby, host_id:)
}

fn try_promote_host(lobby: State, user: User) -> State {
  let host_id = case lobby.host_id == user.id {
    True -> {
      let assert Ok(first) = dict.first(lobby.users)
      first.id
    }
    False -> lobby.host_id
  }
  State(..lobby, host_id:)
}

fn guard_lobby_full(
  lobby: State,
  fun: fn() -> Result(a, coup.Error),
) -> Result(a, coup.Error) {
  bool.guard(dict.size(lobby.users) >= 6, Error(coup.LobbyFull), fun)
}

fn guard_lobby_empty(
  lobby: State,
  fun: fn() -> Result(a, coup.Error),
) -> Result(a, coup.Error) {
  bool.guard(dict.is_empty(lobby.users), Error(coup.LobbyEmpty), fun)
}
