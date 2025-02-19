pub type Character {
  Duke
  Assassin
  Contessa
  Captain
  Ambassador
  Unknown
}

pub fn from_string(character: String) -> Character {
  case character {
    "duke" -> Duke
    "assassin" -> Assassin
    "contessa" -> Contessa
    "captain" -> Captain
    "ambassador" -> Ambassador
    _ -> Unknown
  }
}

pub fn to_string(character: Character) -> String {
  case character {
    Duke -> "duke"
    Assassin -> "assassin"
    Contessa -> "contessa"
    Captain -> "captain"
    Ambassador -> "ambassador"
    Unknown -> "-"
  }
}
