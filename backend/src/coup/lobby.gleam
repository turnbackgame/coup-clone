import coup/context.{type Context}
import coup/game.{type Game}
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/otp/actor
import gleam/result
import lib/coup.{type Room}
import lib/coup/message
import lib/generator
import lib/id.{type Id}
import lib/just
import lib/ordered_dict as dict

const timeout = 100

pub type Lobby =
  Subject(Message)

pub type Message {
  Message(ctx: Context, command: Command)
}

pub type Command {
  Join(reply: Subject(Result(Nil, coup.Error)), name: String)
  Leave
  StartGame(reply: Subject(Result(Game, coup.Error)))
}

pub fn new(id: Id(Room)) -> Lobby {
  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    let lobby = coup.Lobby(id:, users: dict.new(), host_id: id.new_empty())
    actor.Ready(lobby, selector)
  }

  let loop = fn(msg: Message, lobby: coup.Lobby(Context)) {
    let ctx = msg.ctx
    let user = case lobby.users |> dict.get(ctx) {
      Ok(user) -> user
      Error(_) -> coup.User(ctx: ctx, id: id.new_empty(), name: "")
    }
    handle_command(msg.command, lobby, user)
  }

  let assert Ok(subject) =
    actor.start_spec(actor.Spec(init:, init_timeout: timeout, loop:))
  subject
}

pub fn join(lobby: Lobby, ctx: Context, name: String) -> Result(Nil, coup.Error) {
  use reply <- actor.call(lobby, _, timeout)
  Message(ctx, Join(reply, name))
}

pub fn leave(lobby: Lobby, ctx: Context) {
  actor.send(lobby, Message(ctx, Leave))
}

pub fn start_game(lobby: Lobby, ctx: Context) -> Result(Game, coup.Error) {
  use reply <- actor.call(lobby, _, timeout)
  Message(ctx, StartGame(reply))
}

fn handle_command(
  command: Command,
  lobby: coup.Lobby(Context),
  user: coup.User(Context),
) -> actor.Next(Message, coup.Lobby(Context)) {
  case command {
    Join(reply, name) -> {
      use <- just.try(reply_error(reply, lobby, _))
      use <- guard_lobby_full(lobby)

      let user =
        coup.User(..user, id: generator.generate(5) |> id.from_string, name:)
      let lobby = lobby |> add_user(user) |> try_set_host(user)
      let users = lobby.users |> dict.map(message.from_user) |> dict.to_list()
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
      let users = lobby.users |> dict.map(message.from_user) |> dict.to_list()

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

fn add_user(
  lobby: coup.Lobby(Context),
  user: coup.User(Context),
) -> coup.Lobby(Context) {
  coup.Lobby(..lobby, users: lobby.users |> dict.insert_back(user.ctx, user))
}

fn remove_user(
  lobby: coup.Lobby(Context),
  user: coup.User(Context),
) -> coup.Lobby(Context) {
  coup.Lobby(..lobby, users: lobby.users |> dict.delete(user.ctx))
}

fn send_user_event(user: coup.User(Context), event: message.LobbyEvent) {
  actor.send(user.ctx.subject, message.LobbyEvent(event))
}

fn try_set_host(
  lobby: coup.Lobby(Context),
  user: coup.User(Context),
) -> coup.Lobby(Context) {
  let host_id = case id.is_empty(lobby.host_id) {
    True -> user.id
    False -> lobby.host_id
  }
  coup.Lobby(..lobby, host_id:)
}

fn try_promote_host(
  lobby: coup.Lobby(Context),
  user: coup.User(Context),
) -> coup.Lobby(Context) {
  let host_id = case lobby.host_id == user.id {
    True -> {
      let assert Ok(first) = dict.first(lobby.users)
      first.id
    }
    False -> lobby.host_id
  }
  coup.Lobby(..lobby, host_id:)
}

fn guard_lobby_full(
  lobby: coup.Lobby(Context),
  fun: fn() -> Result(a, coup.Error),
) -> Result(a, coup.Error) {
  bool.guard(dict.size(lobby.users) >= 6, Error(coup.LobbyFull), fun)
}

fn guard_lobby_empty(
  lobby: coup.Lobby(Context),
  fun: fn() -> Result(a, coup.Error),
) -> Result(a, coup.Error) {
  bool.guard(dict.is_empty(lobby.users), Error(coup.LobbyEmpty), fun)
}
