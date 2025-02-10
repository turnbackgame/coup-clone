import coup/coup
import coup/pool
import coup/room
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import lib/ids
import lib/message/json

const timeout = 100

pub type Pool =
  pool.Pool

pub type Room =
  room.Room

pub fn new_pool() -> pool.Pool {
  pool.new()
}

pub fn new_user(name: String) -> coup.User {
  let id = ids.generate(8)
  let name = case name {
    "" -> "player-" <> ids.generate(5)
    _ -> name
  }
  coup.User(subject: process.new_subject(), id:, name:)
}

pub fn create_room(pool: pool.Pool) -> room.Room {
  actor.call(pool, pool.CreateRoom(_), timeout)
}

pub fn get_room(pool: pool.Pool, id: String) -> Result(room.Room, Nil) {
  actor.call(pool, pool.GetRoom(_, id), timeout)
}

pub fn join_lobby(room: room.Room, user: coup.User) {
  actor.send(room, coup.JoinLobby(user))
}

pub fn leave_lobby(room: room.Room, user: coup.User) {
  actor.send(room, coup.LeaveLobby(user))
}

pub fn handle_command(user: coup.User, command: json.Command) -> coup.Command {
  case command {
    json.LobbyCommand(json.LobbyStartGame) -> coup.StartGame(user)
  }
}

pub fn handle_event(_user: coup.User, event: coup.Event) -> json.Event {
  case event {
    coup.SendError(msg) -> json.Error(msg)

    coup.LobbyInit(id, user_id, host_id, users) -> {
      users
      |> list.map(fn(u) { json.User(id: u.id, name: u.name) })
      |> json.Lobby(id:, user_id:, host_id:, users: _)
      |> json.LobbyInit
      |> json.LobbyEvent
    }

    coup.LobbyUpdatedUsers(host_id, users) -> {
      users
      |> list.map(fn(u) { json.User(id: u.id, name: u.name) })
      |> json.LobbyUpdatedUsers(host_id:, users: _)
      |> json.LobbyEvent
    }

    coup.GameInit(id, player, other_players, deck_count) -> {
      let cards =
        player.cards |> list.map(fn(card) { json.FaceUp(card_to_json(card)) })
      let player = json.Player(id: player.id, name: player.name, cards:)

      other_players
      |> list.map(fn(p) {
        json.Player(id: p.id, name: p.name, cards: [
          json.FaceDown,
          json.FaceDown,
        ])
      })
      |> json.Game(id:, player:, other_players: _, deck_count:)
      |> json.GameInit
      |> json.GameEvent
    }
  }
}

fn card_to_json(card: coup.Card) -> json.Character {
  case card {
    coup.Duke -> json.Duke
    coup.Assassin -> json.Assassin
    coup.Contessa -> json.Contessa
    coup.Captain -> json.Captain
    coup.Ambassador -> json.Ambassador
  }
}
