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

const cmd = "cmd"

pub type Command {
  LobbyCommand(lobby_message.Command)
}

pub fn decode_command(buf: String) -> Result(Command, json.DecodeError) {
  let decoder = {
    use command <- decode.field(cmd, decode.string)
    case string.split(command, "/") {
      ["lobby", ..] -> {
        use lobby_command <- decode.then(lobby_message.command_decoder(command))
        decode.success(LobbyCommand(lobby_command))
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub fn encode_command(command: Command) -> String {
  let encoder = case command {
    LobbyCommand(command) -> lobby_message.command_encoder(command)
  }
  json.to_string(encoder)
}
