pub type User {
  User(id: String, name: String)
}

pub type Player {
  Player(id: String, name: String, influence: CardSet)
}

pub type Character {
  Duke
  Assassin
  Contessa
  Captain
  Ambassador
  UnknownCharacter
}

pub fn string_to_character(character: String) -> Character {
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

pub type Card {
  FaceDown(Character)
  FaceUp(Character)
}

pub fn string_to_card(card: String) -> Card {
  case card {
    "face-down:" <> character ->
      string_to_character(character)
      |> FaceDown
    character ->
      string_to_character(character)
      |> FaceUp
  }
}

pub fn card_to_string(card: Card) -> String {
  case card {
    FaceDown(character) -> "face-down:" <> character_to_string(character)
    FaceUp(character) -> character_to_string(character)
  }
}

pub type CardSet {
  CardSet(left: Card, right: Card)
}

pub type Deck {
  Deck(cards: List(Card))
}

pub type Event {
  ErrorEvent(String)
  LobbyEvent(LobbyEvent)
  GameEvent(GameEvent)
}

pub type LobbyEvent {
  LobbyInit(id: String, users: List(User), user_id: String, host_id: String)
  LobbyUpdatedUsers(users: List(User), host_id: String)
}

pub type GameEvent {
  GameInit(
    id: String,
    players: List(Player),
    player_id: String,
    deck_count: Int,
  )
}

pub type Command {
  DashboardCommand(DashboardCommand)
  LobbyCommand(LobbyCommand)
  GameCommand(GameCommand)
}

pub type DashboardCommand {
  UserCreateLobby(name: String)
  UserJoinLobby(id: String, name: String)
}

pub type LobbyCommand {
  UserLeaveLobby
  UserStartGame
}

pub type GameCommand
