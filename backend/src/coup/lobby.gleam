import coup
import coup/game.{type Game}
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/otp/actor
import gleam/result
import lib/ids.{type ID}
import lib/just
import lib/message
import lib/ordered_dict as dict

const timeout = 100

pub type Lobby =
  Subject(Message)

pub type Message {
  Message(ctx: coup.Context, command: Command)
}

pub type Command {
  Join(reply: Subject(Result(Nil, coup.Error)), name: String)
  Leave
  StartGame(reply: Subject(Result(Game, coup.Error)))
}

type State {
  State(
    id: ID(ids.Lobby),
    users: dict.OrderedDict(coup.Context, User),
    host_id: String,
  )
}

type User {
  User(ctx: coup.Context, name: String)
}

pub fn new(id: ID(ids.Lobby)) -> Lobby {
  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    let lobby = State(id:, users: dict.new(), host_id: "")
    actor.Ready(lobby, selector)
  }

  let loop = fn(msg: Message, lobby: State) {
    let ctx = msg.ctx
    let user = case lobby.users |> dict.get(ctx) {
      Ok(user) -> user
      Error(_) -> User(ctx: ctx, name: "")
    }
    handle_command(msg.command, lobby, user)
  }

  let assert Ok(subject) =
    actor.start_spec(actor.Spec(init:, init_timeout: timeout, loop:))
  subject
}

pub fn join(
  lobby: Lobby,
  ctx: coup.Context,
  name: String,
) -> Result(Nil, coup.Error) {
  use reply <- actor.call(lobby, _, timeout)
  Message(ctx, Join(reply, name))
}

pub fn leave(lobby: Lobby, ctx: coup.Context) {
  actor.send(lobby, Message(ctx, Leave))
}

pub fn start_game(lobby: Lobby, ctx: coup.Context) -> Result(Game, coup.Error) {
  use reply <- actor.call(lobby, _, timeout)
  Message(ctx, StartGame(reply))
}

fn handle_command(
  command: Command,
  lobby: State,
  user: User,
) -> actor.Next(Message, State) {
  case command {
    Join(reply, name) -> {
      use <- just.try(reply_error(reply, lobby, _))
      use <- guard_lobby_full(lobby)

      let user = User(..user, name:)
      let lobby = lobby |> add_user(user) |> try_set_host(user)
      let msg_users = lobby.users |> dict.map(user_to_message) |> dict.to_list()
      actor.send(reply, Ok(Nil))

      use u <- dict.each(lobby.users, Ok(actor.continue(lobby)))
      case u == user {
        True ->
          message.LobbyInit(
            id: lobby.id,
            users: msg_users,
            user_id: u.ctx.id,
            host_id: lobby.host_id,
          )
        False ->
          message.LobbyUpdatedUsers(users: msg_users, host_id: lobby.host_id)
      }
      |> send_user_event(u, _)
    }

    Leave -> {
      use <- just.try(fn(_err) { actor.Stop(process.Normal) })
      let lobby = lobby |> remove_user(user)
      use <- guard_lobby_empty(lobby)

      let lobby = lobby |> try_promote_host(user)
      let msg_users = lobby.users |> dict.map(user_to_message) |> dict.to_list()

      use u <- dict.each(lobby.users, Ok(actor.continue(lobby)))
      message.LobbyUpdatedUsers(users: msg_users, host_id: lobby.host_id)
      |> send_user_event(u, _)
    }

    StartGame(reply) -> {
      use <- just.try(reply_error(reply, lobby, _))
      let players = dict.map(lobby.users, user_to_player)
      use game <- result.try(game.start(lobby.id, players))
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

fn add_user(lobby: State, user: User) -> State {
  State(..lobby, users: lobby.users |> dict.insert_back(user.ctx, user))
}

fn remove_user(lobby: State, user: User) -> State {
  State(..lobby, users: lobby.users |> dict.delete(user.ctx))
}

fn send_user_event(user: User, event: message.LobbyEvent) {
  actor.send(user.ctx.subject, message.LobbyEvent(event))
}

fn user_to_message(user: User) -> message.User {
  message.User(id: user.ctx.id, name: user.name)
}

fn user_to_player(user: User) -> game.Player {
  game.Player(ctx: user.ctx, name: user.name, influence: coup.new_card_set())
}

fn try_set_host(lobby: State, user: User) -> State {
  let host_id = case lobby.host_id {
    "" -> user.ctx.id
    host_id -> host_id
  }
  State(..lobby, host_id:)
}

fn try_promote_host(lobby: State, user: User) -> State {
  let host_id = case lobby.host_id == user.ctx.id {
    True -> {
      let assert Ok(first) = dict.first(lobby.users)
      first.ctx.id
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
