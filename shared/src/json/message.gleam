import gleam/dynamic/decode
import gleam/json
import gleam/string
import json/game_message
import json/lobby_message

const evt = "evt"

pub type Event {
  LobbyEvent(lobby_message.Event)
  GameEvent(game_message.Event)
}

pub fn decode_event(buf: String) -> Result(Event, json.DecodeError) {
  let decoder = {
    use event <- decode.field(evt, decode.string)
    case string.split(event, "/") {
      ["lobby", ..] -> {
        use lobby_event <- decode.then(lobby_message.event_decoder(event))
        decode.success(LobbyEvent(lobby_event))
      }
      ["game", ..] -> {
        use game_event <- decode.then(game_message.event_decoder(event))
        decode.success(GameEvent(game_event))
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub fn encode_event(event: Event) -> String {
  let encoder = case event {
    LobbyEvent(event) -> lobby_message.event_encoder(event)
    GameEvent(event) -> game_message.event_encoder(event)
  }
  json.to_string(encoder)
}
