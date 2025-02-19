import lib/coup.{type Actor, type Room}
import lib/coup/influence
import lib/id.{type Id}

pub type User {
  User(id: Id(Actor), name: String)
}

pub type Player {
  Player(
    id: Id(Actor),
    name: String,
    influences: influence.Influences,
    coin: Int,
  )
}

pub type Event {
  ErrorEvent(coup.Error)
  LobbyEvent(LobbyEvent)
  GameEvent(GameEvent)
}

pub type LobbyEvent {
  LobbyInit(
    id: Id(Room),
    users: List(User),
    user_id: Id(Actor),
    host_id: Id(Actor),
  )
  LobbyUpdatedUsers(users: List(User), host_id: Id(Actor))
}

pub type GameEvent {
  GameInit(
    id: Id(Room),
    players: List(Player),
    player_id: Id(Actor),
    deck_count: Int,
  )
}

pub type Command {
  DashboardCommand(DashboardCommand)
  LobbyCommand(LobbyCommand)
  GameCommand(GameCommand)
}

pub type DashboardCommand {
  UserCreateLobby(name: String)
  UserJoinLobby(id: Id(Room), name: String)
}

pub type LobbyCommand {
  UserLeaveLobby
  UserStartGame
}

pub type GameCommand
