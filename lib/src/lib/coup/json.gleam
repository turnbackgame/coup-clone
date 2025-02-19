import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string
import lib/coup.{type Actor}
import lib/coup/message
import lib/id.{type Id}

type Decoder(a) =
  decode.Decoder(a)

type Encoder =
  json.Json

const evt = "evt"

pub fn decode_event(buf: String) -> Result(message.Event, json.DecodeError) {
  let decoder = {
    use event <- decode.field(evt, decode.string)
    case string.split(event, "/") {
      ["error"] -> {
        use err <- decode.field("msg", decode.string)
        coup.error_from_string(err)
        |> message.ErrorEvent
        |> decode.success
      }
      ["lobby", ..] -> {
        use lobby_event <- decode.then(lobby_event_decoder(event))
        message.LobbyEvent(lobby_event)
        |> decode.success
      }
      ["game", ..] -> {
        use game_event <- decode.then(game_event_decoder(event))
        message.GameEvent(game_event)
        |> decode.success
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub fn encode_event(event: message.Event) -> String {
  let encoder = case event {
    message.ErrorEvent(err) -> {
      [
        #(evt, json.string("error")),
        #("msg", json.string(coup.error_to_string(err))),
      ]
      |> json.object
    }
    message.LobbyEvent(event) -> lobby_event_encoder(event)
    message.GameEvent(event) -> game_event_encoder(event)
  }
  json.to_string(encoder)
}

fn lobby_event_decoder(event: String) -> Decoder(message.LobbyEvent) {
  case event {
    "lobby/init" -> {
      use id <- decode.field("id", decode.string)
      use users <- decode.field("users", decode.list(user_decoder()))
      use user_id <- decode.field("user_id", decode.string)
      use host_id <- decode.field("host_id", decode.string)
      message.LobbyInit(
        id: id |> id.from_string,
        users:,
        user_id: user_id |> id.from_string,
        host_id: host_id |> id.from_string,
      )
      |> decode.success
    }
    "lobby/updated_users" -> {
      use users <- decode.field("users", decode.list(user_decoder()))
      use host_id <- decode.field("host_id", decode.string)
      decode.success(message.LobbyUpdatedUsers(
        users:,
        host_id: host_id |> id.from_string,
      ))
    }
    _ -> todo
  }
}

fn lobby_event_encoder(event: message.LobbyEvent) -> Encoder {
  case event {
    message.LobbyInit(id, users, user_id, host_id) -> {
      [
        #(evt, json.string("lobby/init")),
        #("id", id |> id.to_string |> json.string),
        #("users", users |> json.array(user_encoder)),
        #("user_id", user_id |> id.to_string |> json.string),
        #("host_id", host_id |> id.to_string |> json.string),
      ]
      |> json.object
    }
    message.LobbyUpdatedUsers(users, host_id) -> {
      [
        #(evt, json.string("lobby/updated_users")),
        #("users", users |> json.array(user_encoder)),
        #("host_id", host_id |> id.to_string |> json.string),
      ]
      |> json.object
    }
  }
}

fn game_event_decoder(event: String) -> Decoder(message.GameEvent) {
  case event {
    "game/init" -> {
      use id <- decode.field("id", decode.string)
      use players <- decode.field("players", decode.list(player_decoder()))
      use player_id <- decode.field("player_id", decode.string)
      use deck_count <- decode.field("deck_count", decode.int)
      message.GameInit(
        id: id |> id.from_string,
        players:,
        player_id: player_id |> id.from_string,
        deck_count:,
      )
      |> decode.success
    }
    _ -> todo
  }
}

fn game_event_encoder(event: message.GameEvent) -> Encoder {
  case event {
    message.GameInit(id, players, player_id, deck_count) -> {
      let #(left, right) =
        players |> list.split_while(fn(p) { p.id != player_id })
      let players = list.append(right, left)
      [
        #(evt, json.string("game/init")),
        #("id", id |> id.to_string |> json.string),
        #("players", players |> json.array(player_encoder(_, player_id))),
        #("player_id", player_id |> id.to_string |> json.string),
        #("deck_count", deck_count |> json.int),
      ]
      |> json.object
    }
  }
}

const cmd = "cmd"

pub fn decode_command(buf: String) -> Result(message.Command, json.DecodeError) {
  let decoder = {
    use command <- decode.field(cmd, decode.string)
    case string.split(command, "/") {
      ["dashboard", ..] -> {
        use dashboard_command <- decode.then(dashboard_command_decoder(command))
        decode.success(message.DashboardCommand(dashboard_command))
      }
      ["lobby", ..] -> {
        use lobby_command <- decode.then(lobby_command_decoder(command))
        decode.success(message.LobbyCommand(lobby_command))
      }
      ["game", ..] -> {
        use game_command <- decode.then(game_command_decoder(command))
        decode.success(message.GameCommand(game_command))
      }
      _ -> todo
    }
  }
  json.parse(buf, decoder)
}

pub fn encode_command(command: message.Command) -> String {
  case command {
    message.DashboardCommand(command) -> dashboard_command_encoder(command)
    message.LobbyCommand(command) -> lobby_command_encoder(command)
    message.GameCommand(command) -> game_command_encoder(command)
  }
  |> json.to_string
}

pub fn dashboard_command_decoder(
  command: String,
) -> Decoder(message.DashboardCommand) {
  case command {
    "dashboard/user_create_lobby" -> {
      use name <- decode.field("name", decode.string)
      message.UserCreateLobby(name)
      |> decode.success
    }
    "dashboard/user_join_lobby" -> {
      use id <- decode.field("id", decode.string)
      use name <- decode.field("name", decode.string)
      message.UserJoinLobby(id: id |> id.from_string, name:)
      |> decode.success
    }
    _ -> todo
  }
}

pub fn dashboard_command_encoder(command: message.DashboardCommand) -> Encoder {
  case command {
    message.UserCreateLobby(name) -> {
      [
        #(cmd, json.string("dashboard/user_create_lobby")),
        #("name", name |> json.string),
      ]
      |> json.object
    }
    message.UserJoinLobby(id, name) -> {
      [
        #(cmd, json.string("dashboard/user_join_lobby")),
        #("id", id |> id.to_string |> json.string),
        #("name", name |> json.string),
      ]
      |> json.object
    }
  }
}

pub fn lobby_command_decoder(command: String) -> Decoder(message.LobbyCommand) {
  case command {
    "lobby/user_leave_lobby" -> {
      message.UserLeaveLobby
      |> decode.success
    }
    "lobby/user_start_game" -> {
      message.UserStartGame
      |> decode.success
    }
    _ -> todo
  }
}

pub fn lobby_command_encoder(command: message.LobbyCommand) -> Encoder {
  case command {
    message.UserLeaveLobby -> {
      [#(cmd, json.string("lobby/user_leave_lobby"))]
      |> json.object
    }
    message.UserStartGame -> {
      [#(cmd, json.string("lobby/user_start_game"))]
      |> json.object
    }
  }
}

pub fn game_command_decoder(_command: String) -> Decoder(message.GameCommand) {
  todo
}

pub fn game_command_encoder(_command: message.GameCommand) -> Encoder {
  todo
}

fn user_decoder() -> Decoder(message.User) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  message.User(id: id |> id.from_string, name:)
  |> decode.success
}

fn user_encoder(user: message.User) -> Encoder {
  [
    #("id", user.id |> id.to_string |> json.string),
    #("name", user.name |> json.string),
  ]
  |> json.object
}

fn player_decoder() -> Decoder(message.Player) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use influences <- decode.field("influences", influences_decoder())
  use coin <- decode.field("coin", decode.int)
  message.Player(id: id |> id.from_string, name:, influences:, coin:)
  |> decode.success
}

fn player_encoder(player: message.Player, player_id: Id(Actor)) -> Encoder {
  let reveal = player.id == player_id
  [
    #("id", player.id |> id.to_string |> json.string),
    #("name", player.name |> json.string),
    #("influences", player.influences |> influences_encoder(reveal)),
    #("coin", player.coin |> json.int),
  ]
  |> json.object
}

fn influence_decoder() -> Decoder(coup.Influence) {
  use influence <- decode.then(decode.string)
  influence
  |> coup.influence_from_string
  |> decode.success
}

fn influence_encoder(influence: coup.Influence, reveal: Bool) -> Encoder {
  case influence {
    coup.FaceUp(..) -> influence
    coup.FaceDown(..) -> {
      case reveal {
        True -> influence
        False -> coup.FaceDown(coup.UnknownCharacter)
      }
    }
  }
  |> coup.influence_to_string
  |> json.string
}

fn influences_decoder() -> Decoder(coup.Influences) {
  use left <- decode.field("left", influence_decoder())
  use right <- decode.field("right", influence_decoder())
  coup.Influences(left, right)
  |> decode.success
}

fn influences_encoder(influences: coup.Influences, reveal: Bool) -> Encoder {
  let coup.Influences(left, right) = influences
  [
    #("left", influence_encoder(left, reveal)),
    #("right", influence_encoder(right, reveal)),
  ]
  |> json.object
}
