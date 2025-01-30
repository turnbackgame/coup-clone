import gleam/dynamic/decode
import gleam/json

pub fn to_string(buf: json.Json) -> String {
  json.to_string(buf)
}

pub type Lobby {
  Lobby(id: String)
}

pub fn encode_lobby(lobby: Lobby) -> json.Json {
  json.object([#("id", json.string(lobby.id))])
}

fn lobby_decoder() -> decode.Decoder(Lobby) {
  use id <- decode.field("id", decode.string)
  decode.success(Lobby(id:))
}

pub fn decode_lobby(buf: String) -> Result(Lobby, json.DecodeError) {
  json.parse(buf, lobby_decoder())
}

pub type Player {
  Player(name: String)
}

pub fn encode_player(player: Player) -> json.Json {
  json.object([#("name", json.string(player.name))])
}

fn player_decoder() -> decode.Decoder(Player) {
  use name <- decode.field("name", decode.string)
  decode.success(Player(name:))
}

pub fn decode_player(buf: String) -> Result(Player, json.DecodeError) {
  json.parse(buf, player_decoder())
}

pub type PlayerMessage {
  PlayerJoinedLobby(lobby: Lobby, players: List(Player))
  PlayerLeavedLobby(lobby: Lobby, players: List(Player))
}

pub fn encode_player_message(msg: PlayerMessage) -> json.Json {
  json.object([
    #("type", json.string(player_message_action(msg))),
    #("lobby", encode_lobby(msg.lobby)),
    #("players", json.array(msg.players, encode_player)),
  ])
}

pub fn decode_player_message(
  buf: String,
) -> Result(PlayerMessage, json.DecodeError) {
  let decoder = {
    use msg_type <- decode.field("type", decode.string)
    use lobby <- decode.field("lobby", lobby_decoder())
    use players <- decode.field("players", decode.list(player_decoder()))
    let player_message = case msg_type {
      "player_joined_lobby" -> PlayerJoinedLobby(lobby:, players:)
      "player_leaved_lobby" -> PlayerLeavedLobby(lobby:, players:)
      _ -> todo
    }
    decode.success(player_message)
  }
  json.parse(buf, decoder)
}

fn player_message_action(msg: PlayerMessage) -> String {
  case msg {
    PlayerJoinedLobby(..) -> "player_joined_lobby"
    PlayerLeavedLobby(..) -> "player_leaved_lobby"
  }
}
