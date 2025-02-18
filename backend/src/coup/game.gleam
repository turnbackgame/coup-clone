import coup/context.{type Context}
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/otp/actor
import gleam/result
import lib/coup
import lib/coup/ids.{type ID}
import lib/coup/message
import lib/just
import lib/ordered_dict as dict

const timeout = 100

const minimum_players = 2

pub type Game =
  Subject(Message)

/// todo: evaluate if we should use reply or not.
pub type Message {
  Message(ctx: Context, command: Command)
}

pub type Command

type State {
  State(
    id: ID(ids.Game),
    court: coup.Court,
    players: coup.Players(Context),
    turn: Int,
  )
}

pub fn start(
  id: ID(ids.Lobby),
  users: coup.Users(Context),
) -> Result(Game, coup.Error) {
  use <- bool.guard(
    dict.size(users) < minimum_players,
    Error(coup.PlayersNotEnough),
  )

  let #(court, players) = coup.new_court() |> coup.register_players(users)
  let game = State(id: ids.map(id), court:, players:, turn: 0)

  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    actor.Ready(game, selector)
  }

  let loop = fn(msg: Message, game: State) {
    let ctx = msg.ctx
    use player <- just.try_ok(get_player(game, ctx), fn(err) {
      context.send_error(ctx, err)
      actor.continue(game)
    })
    handle_command(msg.command, game, player)
  }

  let assert Ok(subject) =
    actor.start_spec(actor.Spec(init:, init_timeout: 100, loop:))

  let players = game.players |> dict.map(message.from_player) |> dict.to_list()
  let deck_count = coup.count_deck(game.court)
  use player <- dict.each(game.players, Ok(subject))
  message.GameInit(id: game.id, players:, player_id: player.id, deck_count:)
  |> send_player_event(player, _)
}

fn handle_command(
  _command: Command,
  _game: State,
  _player: coup.Player(Context),
) -> actor.Next(Message, State) {
  todo
}

fn get_player(
  game: State,
  ctx: Context,
) -> Result(coup.Player(Context), coup.Error) {
  game.players
  |> dict.get(ctx)
  |> result.map_error(fn(_) { coup.PlayerNotExist })
}

fn send_player_event(player: coup.Player(Context), event: message.GameEvent) {
  actor.send(player.ctx.subject, message.GameEvent(event))
}
