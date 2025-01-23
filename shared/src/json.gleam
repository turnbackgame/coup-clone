import gleam/dynamic/decode
import gleam/json

pub type Lobby {
  Lobby(id: String)
}

pub fn encode_lobby(lobby: Lobby) -> json.Json {
  json.object([#("id", json.string(lobby.id))])
}

pub fn decode_lobby(buf: String) -> Result(Lobby, json.DecodeError) {
  let decoder = {
    use id <- decode.field("id", decode.string)
    decode.success(Lobby(id:))
  }
  json.parse(buf, decoder)
}

pub type Player {
  Player(name: String)
}

pub fn encode_player(player: Player) -> json.Json {
  json.object([#("name", json.string(player.name))])
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

fn player_message_action(msg: PlayerMessage) -> String {
  case msg {
    PlayerJoinedLobby(..) -> "player_joined_lobby"
    PlayerLeavedLobby(..) -> "player_leaved_lobby"
  }
}
