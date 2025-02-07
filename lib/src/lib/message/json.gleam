import gleam/dynamic/decode
import gleam/json
import gleam/string

type Decoder(a) =
  decode.Decoder(a)

type Encoder =
  json.Json

const evt = "evt"

pub type Event {
  Error(String)
  LobbyEvent(LobbyEvent)
  GameEvent(GameEvent)
}

pub fn decode_event(buf: String) -> Result(Event, json.DecodeError) {
  let decoder = {
    use event <- decode.field(evt, decode.string)
    case string.split(event, "/") {
      ["error"] -> {
        use err <- decode.field("msg", decode.string)
        decode.success(Error(err))
      }
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
    Error(err) -> {
      [#(evt, json.string("error")), #("msg", json.string(err))]
      |> json.object
    }
    LobbyEvent(event) -> lobby_event_encoder(event)
    GameEvent(event) -> game_event_encoder(event)
  }
  json.to_string(encoder)
}

pub type LobbyEvent {
  LobbyInit(lobby: Lobby)
  LobbyUpdatedUsers(host_id: String, users: List(User))
}

fn lobby_event_decoder(event: String) -> Decoder(LobbyEvent) {
  case event {
    "lobby/init" -> {
      use lobby <- decode.field("lobby", lobby_decoder())
      decode.success(LobbyInit(lobby:))
    }
    "lobby/updated_users" -> {
      use host_id <- decode.field("host_id", decode.string)
      use users <- decode.field("users", decode.list(user_decoder()))
      decode.success(LobbyUpdatedUsers(host_id:, users:))
    }
    _ -> todo
  }
}

fn lobby_event_encoder(event: LobbyEvent) -> Encoder {
  case event {
    LobbyInit(lobby) -> {
      [#(evt, json.string("lobby/init")), #("lobby", lobby_encoder(lobby))]
      |> json.object
    }
    LobbyUpdatedUsers(host_id, users) -> {
      [
        #(evt, json.string("lobby/updated_users")),
        #("host_id", json.string(host_id)),
        #("users", json.array(users, user_encoder)),
      ]
      |> json.object
    }
  }
}

pub type GameEvent {
  GameInit(game: Game)
}

fn game_event_decoder(event: String) -> Decoder(GameEvent) {
  case event {
    "game/init" -> {
      use game <- decode.field("game", game_decoder())
      decode.success(GameInit(game:))
    }
    _ -> todo
  }
}

fn game_event_encoder(event: GameEvent) -> Encoder {
  case event {
    GameInit(game) -> {
      [#(evt, json.string("game/init")), #("game", game_encoder(game))]
      |> json.object
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
      [#(cmd, json.string("lobby/start_game"))]
      |> json.object
    }
  }
}

pub type Lobby {
  Lobby(id: String, user_id: String, host_id: String, users: List(User))
}

fn lobby_encoder(lobby: Lobby) -> Encoder {
  [
    #("id", json.string(lobby.id)),
    #("user_id", json.string(lobby.user_id)),
    #("host_id", json.string(lobby.host_id)),
    #("users", json.array(lobby.users, user_encoder)),
  ]
  |> json.object
}

fn lobby_decoder() -> Decoder(Lobby) {
  use id <- decode.field("id", decode.string)
  use user_id <- decode.field("user_id", decode.string)
  use host_id <- decode.field("host_id", decode.string)
  use users <- decode.field("users", decode.list(user_decoder()))
  decode.success(Lobby(id:, user_id:, host_id:, users:))
}

pub type User {
  User(id: String, name: String)
}

fn user_encoder(user: User) -> Encoder {
  [#("id", json.string(user.id)), #("name", json.string(user.name))]
  |> json.object
}

fn user_decoder() -> Decoder(User) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  decode.success(User(id:, name:))
}

pub type Game {
  Game(id: String, player_id: String, players: List(Player))
}

fn game_encoder(game: Game) -> Encoder {
  [
    #("id", json.string(game.id)),
    #("player_id", json.string(game.player_id)),
    #("players", json.array(game.players, player_encoder)),
  ]
  |> json.object
}

fn game_decoder() -> Decoder(Game) {
  use id <- decode.field("id", decode.string)
  use player_id <- decode.field("player_id", decode.string)
  use players <- decode.field("players", decode.list(player_decoder()))
  decode.success(Game(id:, player_id:, players:))
}

pub type Player {
  Player(id: String, name: String)
}

fn player_encoder(player: Player) -> Encoder {
  [#("id", json.string(player.id)), #("name", json.string(player.name))]
  |> json.object
}

fn player_decoder() -> Decoder(Player) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  decode.success(Player(id:, name:))
}
