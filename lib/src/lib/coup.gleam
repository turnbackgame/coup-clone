import gleam/int
import lib/coup/court.{type Court}
import lib/coup/influence.{type Influences}
import lib/id.{type Id}
import lib/ordered_dict as dict

pub type Error {
  LobbyNotExist
  LobbyFull
  LobbyEmpty
  UserNotExist
  UserNotHost
  GameNotExist
  GameAlreadyStarted
  PlayerNotExist
  PlayersNotEnough
  InternalServerError
}

pub fn error_to_string(err: Error) -> String {
  case err {
    LobbyNotExist -> "lobby_not_exist"
    LobbyFull -> "lobby_full"
    LobbyEmpty -> "lobby_empty"
    UserNotExist -> "user_not_exist"
    UserNotHost -> "user_not_host"
    GameNotExist -> "game_not_exist"
    GameAlreadyStarted -> "game_already_started"
    PlayerNotExist -> "player_not_exist"
    PlayersNotEnough -> "players_not_enough"
    InternalServerError -> "internal_error"
  }
}

pub fn error_from_string(err: String) -> Error {
  case err {
    "lobby_not_exist" -> LobbyNotExist
    "lobby_full" -> LobbyFull
    "lobby_empty" -> LobbyEmpty
    "user_not_exist" -> UserNotExist
    "user_not_host" -> UserNotHost
    "game_not_exist" -> GameNotExist
    "game_already_started" -> GameAlreadyStarted
    "player_not_exist" -> PlayerNotExist
    "players_not_enough" -> PlayersNotEnough
    _ -> InternalServerError
  }
}

pub type Actor

pub type User(t) {
  User(ctx: t, id: Id(Actor), name: String)
}

pub fn new_user(ctx: t, id: Id(Actor), name: String) -> User(t) {
  User(ctx:, id:, name:)
}

pub type Users(t) =
  dict.OrderedDict(t, User(t))

pub type Player(t) {
  Player(ctx: t, id: Id(Actor), name: String, influences: Influences, coin: Int)
}

pub type Players(t) =
  dict.OrderedDict(t, Player(t))

pub type Room

pub type Game(t) {
  Game(
    id: Id(Room),
    court: Court,
    players: Players(t),
    turn: Int,
    state: State(t),
  )
}

fn player_turn(_game: Game(t)) -> Player(t) {
  todo
}

fn pay_coin(game: Game(t), player: Player(t), coin: Int) -> Game(t) {
  let player = Player(..player, coin: player.coin |> int.subtract(coin))
  let players = game.players |> dict.update(player.ctx, player)
  Game(..game, players:)
}

fn take_coin(game: Game(t), player: Player(t), coin: Int) -> Game(t) {
  let player = Player(..player, coin: player.coin |> int.add(coin))
  let players = game.players |> dict.update(player.ctx, player)
  Game(..game, players:)
}

pub fn register_players(
  court: court.Court,
  users: Users(t),
) -> #(Court, Players(t)) {
  use #(court, players), ctx, user <- dict.fold(users, #(court, dict.new()))
  let #(court, influences) = court.draw_initial_influences(court)
  let player = Player(ctx:, id: user.id, name: user.name, influences:, coin: 2)
  let players = players |> dict.insert_back(ctx, player)
  #(court, players)
}

pub type State(t) {
  Waiting
  TakingAction
  OpenBlock(fn() -> Game(t))
  OpenChallenge(fn() -> Game(t))
  OpenBlockOrChallenge(fn() -> Game(t))
  Resolution(fn() -> Game(t))
}

pub type Event(t) {
  StartTurn
  Action(Action(t))
  Block
  Challenge
  Allow
  EndTurn
}

pub type Action(t) {
  Income
  ForeignAid
  Coup(Player(t))
  Tax
  Assassinate(Player(t))
  Exchange
  Steal(Player(t))
}

pub fn take_action(
  action: Action(t),
  game: Game(t),
  player: Player(t),
) -> State(t) {
  case action {
    Income -> {
      use <- Resolution
      game |> take_coin(player, 1)
    }

    ForeignAid -> {
      use <- OpenBlock
      game |> take_coin(player, 2)
    }

    Coup(_target) -> {
      use <- Resolution
      game |> pay_coin(player, 7)
      todo
    }

    Tax -> {
      use <- OpenChallenge
      game |> take_coin(player, 3)
    }

    Assassinate(_target) -> {
      use <- OpenBlockOrChallenge
      game |> pay_coin(player, 3)
      todo
    }

    Exchange -> {
      use <- OpenChallenge
      game
    }

    Steal(target) -> {
      use <- OpenBlockOrChallenge
      game |> take_coin(player, 3) |> pay_coin(target, 3)
    }
  }
}

pub fn next(game: Game(t), event: Event(t)) -> State(t) {
  let player = game |> player_turn
  case game.state {
    Waiting ->
      case event {
        StartTurn -> TakingAction
        _ -> Waiting
      }
    TakingAction ->
      case event {
        Action(action) -> take_action(action, game, player)
        _ -> TakingAction
      }
    OpenBlock(do) ->
      case event {
        Allow -> Resolution(do)
        Block -> OpenChallenge(do)
        _ -> OpenBlock(do)
      }
    OpenChallenge(do) ->
      case event {
        Allow -> Resolution(do)
        Challenge -> todo
        _ -> OpenChallenge(do)
      }
    OpenBlockOrChallenge(do) ->
      case event {
        Allow -> Resolution(do)
        Block -> OpenChallenge(do)
        Challenge -> todo
        _ -> OpenBlockOrChallenge(do)
      }
    Resolution(do) -> Resolution(do)
  }
}
