import gleam/dynamic/decode
import gleam/json

type Decoder(a) =
  decode.Decoder(a)

type Encoder =
  json.Json

const evt = "evt"

pub type Event {
  Init(lobby: Lobby, player: Player, players: List(Player))
  PlayersUpdated(players: List(Player))
}

pub fn event_decoder(event: String) -> Decoder(Event) {
  case event {
    "lobby/init" -> {
      use lobby <- decode.field("lobby", lobby_decoder())
      use player <- decode.field("player", player_decoder())
      use players <- decode.field("players", decode.list(player_decoder()))
      decode.success(Init(lobby:, player:, players:))
    }
    "lobby/players_updated" -> {
      use players <- decode.field("players", decode.list(player_decoder()))
      decode.success(PlayersUpdated(players:))
    }
    _ -> todo
  }
}

pub fn event_encoder(event: Event) -> Encoder {
  case event {
    Init(lobby, player, players) -> {
      json.object([
        #(evt, json.string("lobby/init")),
        #("lobby", lobby_encoder(lobby)),
        #("player", player_encoder(player)),
        #("players", json.array(players, player_encoder)),
      ])
    }
    PlayersUpdated(players) -> {
      json.object([
        #(evt, json.string("lobby/players_updated")),
        #("players", json.array(players, player_encoder)),
      ])
    }
  }
}

const cmd = "cmd"

pub type Command {
  StartGame
}

pub fn command_decoder(command: String) -> Decoder(Command) {
  case command {
    "lobby/start_game" -> {
      decode.success(StartGame)
    }
    _ -> todo
  }
}

pub fn command_encoder(command: Command) -> Encoder {
  case command {
    StartGame -> {
      json.object([#(cmd, json.string("lobby/start_game"))])
    }
  }
}

pub type Player {
  Player(name: String)
}

pub type Lobby {
  Lobby(id: String)
}

fn player_encoder(player: Player) -> Encoder {
  json.object([#("name", json.string(player.name))])
}

fn player_decoder() -> Decoder(Player) {
  use name <- decode.field("name", decode.string)
  decode.success(Player(name:))
}

fn lobby_encoder(lobby: Lobby) -> Encoder {
  json.object([#("id", json.string(lobby.id))])
}

fn lobby_decoder() -> Decoder(Lobby) {
  use id <- decode.field("id", decode.string)
  decode.success(Lobby(id:))
}
