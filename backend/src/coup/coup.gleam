import gleam/deque.{type Deque}
import gleam/erlang/process.{type Subject}
import gleam/list

pub type Command {
  JoinLobby(User)
  LeaveLobby(User)
  StartGame(User)
}

pub type Event {
  SendError(String)
  LobbyInit(id: String, user_id: String, host_id: String, users: List(User))
  LobbyUpdatedUsers(host_id: String, users: List(User))
  GameInit(
    id: String,
    player: Player,
    other_players: List(Player),
    deck_count: Int,
  )
}

pub type User {
  User(subject: Subject(Event), id: String, name: String)
}

pub type Player {
  Player(subject: Subject(Event), id: String, name: String, cards: List(Card))
}

pub fn to_players(users: Deque(User)) -> Deque(Player) {
  users
  |> deque.to_list
  |> list.map(fn(u) {
    Player(subject: u.subject, id: u.id, name: u.name, cards: [])
  })
  |> deque.from_list
}

pub type Card {
  Duke
  Assassin
  Contessa
  Captain
  Ambassador
}

pub type Deck {
  Deck(cards: List(Card))
}

pub fn new_deck() -> Deck {
  []
  |> list.append(list.repeat(Duke, 3))
  |> list.append(list.repeat(Assassin, 3))
  |> list.append(list.repeat(Contessa, 3))
  |> list.append(list.repeat(Captain, 3))
  |> list.append(list.repeat(Ambassador, 3))
  |> Deck(cards: _)
}

pub fn shuffle_deck(deck: Deck) -> Deck {
  deck.cards
  |> list.shuffle
  |> Deck(cards: _)
}

pub fn deck_count(deck: Deck) -> Int {
  list.length(deck.cards)
}

pub fn draw_card(deck: Deck) -> Result(#(Deck, Card), Nil) {
  case deck.cards {
    [first, ..rest] -> Ok(#(Deck(cards: rest), first))
    _ -> Error(Nil)
  }
}
