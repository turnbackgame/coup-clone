import coup
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/otp/actor
import gleam/result
import lib/coup/ids.{type ID}
import lib/coup/message
import lib/just
import lib/ordered_dict as dict

const timeout = 100

const minimum_players = 2

pub type Game =
  Subject(Message)

pub type Message {
  Message(ctx: coup.Context, command: Command)
}

pub type Command

type State {
  State(
    id: ID(ids.Game),
    players: dict.OrderedDict(coup.Context, Player),
    turn: Int,
    court: coup.Deck,
  )
}

pub type Player {
  Player(ctx: coup.Context, name: String, influence: coup.CardSet)
}

pub fn start(
  id: ID(ids.Lobby),
  players: dict.OrderedDict(coup.Context, Player),
) -> Result(Game, coup.Error) {
  use <- bool.guard(
    dict.size(players) < minimum_players,
    Error(coup.PlayersNotEnough),
  )

  let game =
    State(id: ids.map(id), players:, turn: 0, court: coup.new_deck())
    |> shuffle_deck()
    |> initial_deal()

  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, function.identity)
    actor.Ready(game, selector)
  }

  let loop = fn(msg: Message, game: State) {
    let ctx = msg.ctx
    use <- just.try(fn(err) {
      coup.send_error(ctx, err)
      actor.continue(game)
    })
    use player <- result.try(get_player(game, ctx))
    use game <- result.try(handle_command(player, msg.command, game))
    Ok(actor.continue(game))
  }

  let assert Ok(subject) =
    actor.start_spec(actor.Spec(init:, init_timeout: 100, loop:))

  let players = dict.map(game.players, player_to_message) |> dict.to_list
  let deck_count = coup.count_deck(game.court)
  use player <- dict.each(game.players, Ok(subject))
  message.GameInit(id: game.id, players:, player_id: player.ctx.id, deck_count:)
  |> send_player_event(player, _)
}

fn handle_command(
  _player: Player,
  _command: Command,
  _game: State,
) -> Result(State, coup.Error) {
  todo
}

fn get_player(game: State, ctx: coup.Context) -> Result(Player, coup.Error) {
  game.players
  |> dict.get(ctx)
  |> result.map_error(fn(_) { coup.PlayerNotExist })
}

fn send_player_event(player: Player, event: message.GameEvent) {
  actor.send(player.ctx.subject, message.GameEvent(event))
}

fn player_to_message(player: Player) -> message.Player {
  message.Player(
    id: player.ctx.id,
    name: player.name,
    influence: coup.card_set_to_message(player.influence),
  )
}

fn shuffle_deck(game: State) -> State {
  State(..game, court: game.court |> coup.shuffle_deck)
}

fn initial_deal(game: State) -> State {
  use game, ctx, player <- dict.fold(game.players, game)
  let #(court, influence) = coup.draw_initial_card(game.court)
  let players =
    game.players
    |> dict.insert_back(ctx, Player(..player, influence:))
  State(..game, players:, court:)
}
