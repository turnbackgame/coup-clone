import lib/coup/character.{type Character}

pub type Influences {
  Influences(Influence, Influence)
}

pub type Influence {
  FaceDown(Character)
  FaceUp(Character)
}

pub fn from_string(influence: String) -> Influence {
  case influence {
    "face-down:" <> character ->
      character.from_string(character)
      |> FaceDown
    character ->
      character.from_string(character)
      |> FaceUp
  }
}

pub fn to_string(influence: Influence) -> String {
  case influence {
    FaceDown(character) -> "face-down:" <> character.to_string(character)
    FaceUp(character) -> character.to_string(character)
  }
}
