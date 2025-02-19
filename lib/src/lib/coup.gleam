import gleam/list
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

pub type Character {
  Duke
  Assassin
  Contessa
  Captain
  Ambassador
  UnknownCharacter
}

pub fn character_from_string(character: String) -> Character {
  case character {
    "duke" -> Duke
    "assassin" -> Assassin
    "contessa" -> Contessa
    "captain" -> Captain
    "ambassador" -> Ambassador
    _ -> UnknownCharacter
  }
}

pub fn character_to_string(character: Character) -> String {
  case character {
    Duke -> "duke"
    Assassin -> "assassin"
    Contessa -> "contessa"
    Captain -> "captain"
    Ambassador -> "ambassador"
    UnknownCharacter -> "-"
  }
}

pub type Influence {
  FaceDown(Character)
  FaceUp(Character)
}

pub fn influence_from_string(influence: String) -> Influence {
  case influence {
    "face-down:" <> character ->
      character_from_string(character)
      |> FaceDown
    character ->
      character_from_string(character)
      |> FaceUp
  }
}

pub fn influence_to_string(influence: Influence) -> String {
  case influence {
    FaceDown(character) -> "face-down:" <> character_to_string(character)
    FaceUp(character) -> character_to_string(character)
  }
}

pub type Influences {
  Influences(Influence, Influence)
}

pub type Court {
  Court(List(Influence))
}

pub fn new_court() -> Court {
  []
  |> list.append(list.repeat(FaceDown(Duke), 3))
  |> list.append(list.repeat(FaceDown(Assassin), 3))
  |> list.append(list.repeat(FaceDown(Contessa), 3))
  |> list.append(list.repeat(FaceDown(Captain), 3))
  |> list.append(list.repeat(FaceDown(Ambassador), 3))
  |> Court
  |> shuffle_deck
}

fn shuffle_deck(court: Court) -> Court {
  let Court(deck) = court
  deck
  |> list.shuffle
  |> Court
}

fn draw_initial_influences(court: Court) -> #(Court, Influences) {
  let Court(deck) = court
  let assert [left, right, ..rest] = deck
  #(Court(rest), Influences(left, right))
}

pub fn register_players(court: Court, users: Users(t)) -> #(Court, Players(t)) {
  use #(court, players), ctx, user <- dict.fold(users, #(court, dict.new()))
  let #(court, influences) = draw_initial_influences(court)
  let player = Player(ctx:, id: user.id, name: user.name, influences:, coin: 2)
  let players = players |> dict.insert_back(ctx, player)
  #(court, players)
}

pub fn count_deck(court: Court) -> Int {
  let Court(deck) = court
  list.length(deck)
}

pub fn draw_influence(court: Court) -> Result(#(Court, Influence), Nil) {
  let Court(deck) = court
  case deck {
    [first, ..rest] -> Ok(#(Court(rest), first))
    _ -> Error(Nil)
  }
}

pub fn return_influence(court: Court, influence: Influence) -> Court {
  let character = case influence {
    FaceDown(character) -> character
    FaceUp(character) -> character
  }
  let Court(deck) = court
  deck
  |> list.prepend(FaceDown(character))
  |> Court
  |> shuffle_deck
}

pub type Action {
  Income
  Coup
  ForeignAid
  Tax
  Assassinate
  Exchange
  Steal
}

pub type Counteraction {
  BlockForeignAid
  BlockStealing
  BlockAssassination
}

pub type Room

pub type Lobby(t) {
  Lobby(id: Id(Room), users: Users(t), host_id: Id(Actor))
}

pub type Game(t) {
  Game(id: Id(Room), court: Court, players: Players(t), turn: Int)
}
