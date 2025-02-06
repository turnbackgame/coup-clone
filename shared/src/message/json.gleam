import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string

type Decoder(a) =
  decode.Decoder(a)

type Encoder =
  json.Json

const evt = "evt"

pub type Event {
  LobbyEvent(LobbyEvent)
  GameEvent(GameEvent)
}

pub fn decode_event(buf: String) -> Result(Event, json.DecodeError) {
  let decoder = {
    use event <- decode.field(evt, decode.string)
    case string.split(event, "/") {
      ["lobby", ..] -> {
        use lobby_event <- decode.then(lobby_event_decoder(event))
        decode.success(LobbyEvent(lobby_event))
      }
      ["game", ..] -> {
        use game_event <- decode.then(game_event_decoder(event))
        decode.success(GameEvent(game_event))
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub fn encode_event(event: Event) -> String {
  let encoder = case event {
    LobbyEvent(event) -> lobby_event_encoder(event)
    GameEvent(event) -> game_event_encoder(event)
  }
  json.to_string(encoder)
}

pub type LobbyEvent {
  LobbyInit(lobby: Lobby, player: LobbyPlayer, players: List(LobbyPlayer))
  LobbyPlayersUpdated(players: List(LobbyPlayer))
}

fn lobby_event_decoder(event: String) -> Decoder(LobbyEvent) {
  case event {
    "lobby/init" -> {
      use lobby <- decode.field("lobby", lobby_decoder())
      use player <- decode.field("player", lobby_player_decoder())
      use players <- decode.field(
        "players",
        decode.list(lobby_player_decoder()),
      )
      decode.success(LobbyInit(lobby:, player:, players:))
    }
    "lobby/players_updated" -> {
      use players <- decode.field(
        "players",
        decode.list(lobby_player_decoder()),
      )
      decode.success(LobbyPlayersUpdated(players:))
    }
    _ -> todo
  }
}

fn lobby_event_encoder(event: LobbyEvent) -> Encoder {
  case event {
    LobbyInit(lobby, player, players) -> {
      json.object([
        #(evt, json.string("lobby/init")),
        #("lobby", lobby_encoder(lobby)),
        #("player", lobby_player_encoder(player)),
        #("players", json.array(players, lobby_player_encoder)),
      ])
    }
    LobbyPlayersUpdated(players) -> {
      json.object([
        #(evt, json.string("lobby/players_updated")),
        #("players", json.array(players, lobby_player_encoder)),
      ])
    }
  }
}

pub type GameEvent {
  GameInit(game: Game, player: GamePlayer, players: List(GamePlayer))
}

fn game_event_decoder(event: String) -> Decoder(GameEvent) {
  case event {
    "game/init" -> {
      use game <- decode.field("game", game_decoder())
      use player <- decode.field("player", player_decoder())
      use players <- decode.field("players", decode.list(player_decoder()))
      decode.success(GameInit(game:, player:, players:))
    }
    _ -> todo
  }
}

fn game_event_encoder(event: GameEvent) -> Encoder {
  case event {
    GameInit(game, player, players) -> {
      json.object([
        #(evt, json.string("game/init")),
        #("game", game_encoder(game)),
        #("player", player_encoder(player)),
        #("players", json.array(players, player_encoder)),
      ])
    }
  }
}

const cmd = "cmd"

pub type Command {
  LobbyCommand(LobbyCommand)
}

pub fn decode_command(buf: String) -> Result(Command, json.DecodeError) {
  let decoder = {
    use command <- decode.field(cmd, decode.string)
    case string.split(command, "/") {
      ["lobby", ..] -> {
        use lobby_command <- decode.then(lobby_command_decoder(command))
        decode.success(LobbyCommand(lobby_command))
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub fn encode_command(command: Command) -> String {
  let encoder = case command {
    LobbyCommand(command) -> lobby_command_encoder(command)
  }
  json.to_string(encoder)
}

pub type LobbyCommand {
  LobbyStartGame
}

pub fn lobby_command_decoder(command: String) -> Decoder(LobbyCommand) {
  case command {
    "lobby/start_game" -> {
      decode.success(LobbyStartGame)
    }
    _ -> todo
  }
}

pub fn lobby_command_encoder(command: LobbyCommand) -> Encoder {
  case command {
    LobbyStartGame -> {
      json.object([#(cmd, json.string("lobby/start_game"))])
    }
  }
}

pub type Lobby {
  Lobby(id: String)
}

fn lobby_encoder(lobby: Lobby) -> Encoder {
  json.object([#("id", json.string(lobby.id))])
}

fn lobby_decoder() -> Decoder(Lobby) {
  use id <- decode.field("id", decode.string)
  decode.success(Lobby(id:))
}

pub type LobbyPlayer {
  LobbyPlayer(name: String, host: Bool)
}

fn lobby_player_encoder(player: LobbyPlayer) -> Encoder {
  case player.host {
    False -> []
    True -> [#("host", json.bool(player.host))]
  }
  |> list.append([#("name", json.string(player.name))])
  |> json.object
}

fn lobby_player_decoder() -> Decoder(LobbyPlayer) {
  use name <- decode.field("name", decode.string)
  use host <- decode.optional_field("host", False, decode.bool)
  decode.success(LobbyPlayer(name:, host:))
}

pub type Game {
  Game(id: String)
}

fn game_encoder(game: Game) -> Encoder {
  json.object([#("id", json.string(game.id))])
}

fn game_decoder() -> Decoder(Game) {
  use id <- decode.field("id", decode.string)
  decode.success(Game(id:))
}

pub type GamePlayer {
  GamePlayer(name: String)
}

fn player_encoder(player: GamePlayer) -> Encoder {
  json.object([#("name", json.string(player.name))])
}

fn player_decoder() -> Decoder(GamePlayer) {
  use name <- decode.field("name", decode.string)
  decode.success(GamePlayer(name:))
}
