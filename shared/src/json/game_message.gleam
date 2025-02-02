import gleam/dynamic/decode
import gleam/json

type Decoder(a) =
  decode.Decoder(a)

type Encoder =
  json.Json

const evt = "evt"

pub type Event {
  Init(game: Game, player: Player, players: List(Player))
}

pub fn event_decoder(event: String) -> Decoder(Event) {
  case event {
    "game/init" -> {
      use game <- decode.field("game", game_decoder())
      use player <- decode.field("player", player_decoder())
      use players <- decode.field("players", decode.list(player_decoder()))
      decode.success(Init(game:, player:, players:))
    }
    _ -> todo
  }
}

pub fn event_encoder(event: Event) -> Encoder {
  case event {
    Init(game, player, players) -> {
      json.object([
        #(evt, json.string("lobby/init")),
        #("lobby", game_encoder(game)),
        #("player", player_encoder(player)),
        #("players", json.array(players, player_encoder)),
      ])
    }
  }
}

pub type Player {
  Player(name: String)
}

pub type Game {
  Game(id: String)
}

fn player_encoder(player: Player) -> Encoder {
  json.object([#("name", json.string(player.name))])
}

fn player_decoder() -> Decoder(Player) {
  use name <- decode.field("name", decode.string)
  decode.success(Player(name:))
}

fn game_encoder(game: Game) -> Encoder {
  json.object([#("id", json.string(game.id))])
}

fn game_decoder() -> Decoder(Game) {
  use id <- decode.field("id", decode.string)
  decode.success(Game(id:))
}
