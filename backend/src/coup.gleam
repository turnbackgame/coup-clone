import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import lib/generator
import lib/message

pub type Context {
  Context(subject: Subject(message.Event), id: String)
}

pub fn new_context() -> Context {
  Context(subject: process.new_subject(), id: generator.generate(5))
}

/// todo: remove this
pub fn send_error(ctx: Context, err: Error) {
  error_to_string(err)
  |> message.ErrorEvent
  |> actor.send(ctx.subject, _)
}

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
}

pub fn error_to_string(err: Error) -> String {
  case err {
    LobbyNotExist -> "lobby not exist"
    LobbyFull -> "lobby is full"
    LobbyEmpty -> "lobby is empty"

    UserNotExist -> "user not exist"
    UserNotHost -> "require host to start the game"

    GameNotExist -> "game not exist"
    GameAlreadyStarted -> "game already started"

    PlayerNotExist -> "player not exist"
    PlayersNotEnough -> "not enough players to start the game"
  }
}

pub type Character {
  Duke
  Assassin
  Contessa
  Captain
  Ambassador
}

pub fn character_to_message(character: Character) -> message.Character {
  case character {
    Duke -> message.Duke
    Assassin -> message.Assassin
    Contessa -> message.Contessa
    Captain -> message.Captain
    Ambassador -> message.Ambassador
  }
}

pub type Card {
  FaceDown(Character)
  FaceUp(Character)
}

pub fn card_to_message(card: Card) -> message.Card {
  case card {
    FaceDown(character) -> message.FaceDown(character_to_message(character))
    FaceUp(character) -> message.FaceUp(character_to_message(character))
  }
}

pub type CardSet {
  CardSet(left: Card, right: Card)
}

pub fn new_card_set() -> CardSet {
  CardSet(FaceDown(Duke), FaceDown(Duke))
}

pub fn card_set_to_message(card_set: CardSet) -> message.CardSet {
  message.CardSet(
    left: card_to_message(card_set.left),
    right: card_to_message(card_set.right),
  )
}

pub opaque type Deck {
  Deck(cards: List(Card))
}

pub fn new_deck() -> Deck {
  []
  |> list.append(list.repeat(FaceDown(Duke), 3))
  |> list.append(list.repeat(FaceDown(Assassin), 3))
  |> list.append(list.repeat(FaceDown(Contessa), 3))
  |> list.append(list.repeat(FaceDown(Captain), 3))
  |> list.append(list.repeat(FaceDown(Ambassador), 3))
  |> Deck
}

pub fn shuffle_deck(deck: Deck) -> Deck {
  deck.cards
  |> list.shuffle
  |> Deck
}

pub fn count_deck(deck: Deck) -> Int {
  list.length(deck.cards)
}

pub fn draw_initial_card(deck: Deck) -> #(Deck, CardSet) {
  let assert [left, right, ..rest] = deck.cards
  #(Deck(rest), CardSet(left, right))
}

pub fn draw_card(deck: Deck) -> Result(#(Deck, Card), Nil) {
  case deck.cards {
    [first, ..rest] -> Ok(#(Deck(rest), first))
    _ -> Error(Nil)
  }
}
