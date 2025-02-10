import coup/coup
import gleam/deque.{type Deque}
import gleam/list
import gleam/otp/actor

const minimum_players = 2

pub type Game {
  Game(id: String, players: Deque(coup.Player), deck: coup.Deck)
}

pub fn new(id: String) -> Game {
  Game(id:, players: deque.new(), deck: coup.new_deck() |> coup.shuffle_deck)
}

pub fn is_enough_player(players: Deque(coup.Player)) -> Bool {
  deque.length(players) >= minimum_players
}

pub fn add_players(game: Game, players: Deque(coup.Player)) -> Game {
  Game(..game, players:)
}

pub fn assign_cards(game: Game) -> Game {
  let #(players, deck) =
    game.players
    |> deque.to_list
    |> list.fold(#([], game.deck), fn(acc, p) {
      let #(players, deck) = acc
      let assert Ok(#(deck, card1)) = coup.draw_card(deck)
      let assert Ok(#(deck, card2)) = coup.draw_card(deck)
      let p = coup.Player(..p, cards: [card1, card2])
      #(list.prepend(players, p), deck)
    })

  Game(..game, players: deque.from_list(players |> list.reverse), deck:)
}

pub fn start_game(game: Game) -> Game {
  let player_list = game.players |> deque.to_list

  player_list
  |> list.each(fn(player) {
    let #(left, right) = player_list |> list.split_while(fn(p) { p != player })
    let assert [_, ..right] = right
    let other_players = list.append(right, left)
    coup.GameInit(
      id: game.id,
      player:,
      other_players:,
      deck_count: coup.deck_count(game.deck),
    )
    |> actor.send(player.subject, _)
  })

  game
}
