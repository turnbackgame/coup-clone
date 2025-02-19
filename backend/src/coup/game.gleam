import coup/user.{type User, type Users}
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/otp/actor
import gleam/result
import lib/coup.{type Actor, type Room}
import lib/coup/court.{type Court}
import lib/coup/influence.{type Influences}
import lib/coup/message
import lib/id.{type Id}
import lib/just
import lib/ordered_dict as dict

const minimum_players = 2

pub type Game =
  Subject(Message)

pub fn start(id: Id(Room), users: Users) -> Result(Game, coup.Error) {
  use <- bool.guard(
    dict.size(users) < minimum_players,
    Error(coup.PlayersNotEnough),
  )

  let game =
    State(id:, court: court.new(), players: dict.new(), turn: 0)
    |> register_players(users)

  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    actor.Ready(game, selector)
  }

  let loop = fn(msg: Message, game: State) {
    use player <- just.try_ok(get_player(game, msg.user), fn(err) {
      user.send_error(msg.user, err)
      actor.continue(game)
    })
    handle_command(msg.command, game, player)
  }

  let assert Ok(subject) =
    actor.start_spec(actor.Spec(init:, init_timeout: 100, loop:))

  let players = game.players |> dict.map(player_to_message) |> dict.to_list()
  let deck_count = court.count(game.court)
  use player <- dict.each(game.players, Ok(subject))
  message.GameInit(
    id: game.id,
    players:,
    player_id: player.user.id,
    deck_count:,
  )
  |> send_player_event(player, _)
}

/// todo: evaluate if we should use reply or not.
pub type Message {
  Message(user: User, command: Command)
}

pub type Command

fn handle_command(
  _command: Command,
  _game: State,
  _player: Player,
) -> actor.Next(Message, State) {
  todo
}

type Players =
  dict.OrderedDict(Id(Actor), Player)

type Player {
  Player(user: User, influences: Influences, coin: Int)
}

fn send_player_event(player: Player, event: message.GameEvent) {
  actor.send(player.user.subject, message.GameEvent(event))
}

fn player_to_message(player: Player) -> message.Player {
  message.Player(
    id: player.user.id,
    name: player.user.name,
    influences: player.influences,
    coin: player.coin,
  )
}

type State {
  State(id: Id(Room), court: Court, players: Players, turn: Int)
}

fn register_players(game: State, users: Users) -> State {
  use game, id, user <- dict.fold(users, game)
  let #(court, influences) = court.draw_initial_influences(game.court)
  let player = Player(user:, influences:, coin: 2)
  let players = game.players |> dict.insert_back(id, player)
  State(..game, court:, players:)
}

fn get_player(game: State, user: User) -> Result(Player, coup.Error) {
  game.players
  |> dict.get(user.id)
  |> result.map_error(fn(_) { coup.PlayerNotExist })
}
