import gleam/list
import lib/coup/character
import lib/coup/influence.{type Influence}

pub type Court {
  Court(List(Influence))
}

pub fn new() -> Court {
  []
  |> list.append(character.Duke |> influence.FaceDown |> list.repeat(3))
  |> list.append(character.Assassin |> influence.FaceDown |> list.repeat(3))
  |> list.append(character.Ambassador |> influence.FaceDown |> list.repeat(3))
  |> list.append(character.Captain |> influence.FaceDown |> list.repeat(3))
  |> list.append(character.Contessa |> influence.FaceDown |> list.repeat(3))
  |> Court
  |> shuffle
}

fn shuffle(court: Court) -> Court {
  let Court(deck) = court
  deck
  |> list.shuffle
  |> Court
}

pub fn count(court: Court) -> Int {
  let Court(deck) = court
  list.length(deck)
}

pub fn draw_initial_influences(court: Court) -> #(Court, influence.Influences) {
  let Court(deck) = court
  let assert [left, right, ..rest] = deck
  #(Court(rest), influence.Influences(left, right))
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
    influence.FaceDown(character) -> character
    influence.FaceUp(character) -> character
  }
  let Court(deck) = court
  deck
  |> list.prepend(influence.FaceDown(character))
  |> Court
  |> shuffle
}
