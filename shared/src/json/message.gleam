import gleam/dynamic/decode
import gleam/json

const event = "evt"

const command = "cmd"

pub fn to_string(buf: json.Json) -> String {
  json.to_string(buf)
}

pub type LobbyEvent {
  LobbyInit(lobby: Lobby, player: Player, players: List(Player))
  LobbyUpdated(players: List(Player))
}

pub fn encode_lobby_event(lobby_event: LobbyEvent) -> json.Json {
  case lobby_event {
    LobbyInit(lobby, player, players) -> {
      json.object([
        #(event, json.string("lobby_init")),
        #("lobby", encode_lobby(lobby)),
        #("player", encode_player(player)),
        #("players", json.array(players, encode_player)),
      ])
    }
    LobbyUpdated(players) -> {
      json.object([
        #(event, json.string("lobby_init")),
        #("players", json.array(players, encode_player)),
      ])
    }
  }
}

pub fn decode_lobby_event(buf: String) -> Result(LobbyEvent, json.DecodeError) {
  let decoder = {
    use lobby_event <- decode.field(event, decode.string)
    case lobby_event {
      "lobby_init" -> {
        use lobby <- decode.field("lobby", lobby_decoder())
        use player <- decode.field("player", player_decoder())
        use players <- decode.field("players", decode.list(player_decoder()))
        decode.success(LobbyInit(lobby:, player:, players:))
      }
      "lobby_updated" -> {
        use players <- decode.field("players", decode.list(player_decoder()))
        decode.success(LobbyUpdated(players:))
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub type Lobby {
  Lobby(id: String)
}

pub fn encode_lobby(lobby: Lobby) -> json.Json {
  json.object([#("id", json.string(lobby.id))])
}

pub fn decode_lobby(buf: String) -> Result(Lobby, json.DecodeError) {
  json.parse(buf, lobby_decoder())
}

fn lobby_decoder() -> decode.Decoder(Lobby) {
  use id <- decode.field("id", decode.string)
  decode.success(Lobby(id:))
}

pub type Player {
  Player(name: String)
}

pub fn encode_player(player: Player) -> json.Json {
  json.object([#("name", json.string(player.name))])
}

pub fn decode_player(buf: String) -> Result(Player, json.DecodeError) {
  json.parse(buf, player_decoder())
}

fn player_decoder() -> decode.Decoder(Player) {
  use name <- decode.field("name", decode.string)
  decode.success(Player(name:))
}

pub type GameEvent {
  GameInit(game: Game, player: Player, players: List(Player))
}

pub fn encode_game_event(game_event: GameEvent) -> json.Json {
  case game_event {
    GameInit(game, player, players) -> {
      json.object([
        #(event, json.string("game_init")),
        #("game", encode_game(game)),
        #("player", encode_player(player)),
        #("players", json.array(players, encode_player)),
      ])
    }
  }
}

pub fn decode_game_event(buf: String) -> Result(GameEvent, json.DecodeError) {
  let decoder = {
    use game_event <- decode.field(event, decode.string)
    case game_event {
      "game_init" -> {
        use game <- decode.field("game", game_decoder())
        use player <- decode.field("player", player_decoder())
        use players <- decode.field("players", decode.list(player_decoder()))
        decode.success(GameInit(game:, player:, players:))
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub type GameCommand {
  StartGame
}

pub fn encode_game_command(msg: GameCommand) -> json.Json {
  case msg {
    StartGame -> {
      json.object([#(command, json.string("start_game"))])
    }
  }
}

pub fn decode_game_command(buf: String) -> Result(GameCommand, json.DecodeError) {
  let decoder = {
    use game_command <- decode.field(command, decode.string)
    case game_command {
      "start_game" -> {
        decode.success(StartGame)
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub type Game {
  Game(id: String)
}

pub fn encode_game(game: Game) -> json.Json {
  json.object([#("id", json.string(game.id))])
}

pub fn decode_game(buf: String) -> Result(Game, json.DecodeError) {
  json.parse(buf, game_decoder())
}

fn game_decoder() -> decode.Decoder(Game) {
  use id <- decode.field("id", decode.string)
  decode.success(Game(id:))
}
