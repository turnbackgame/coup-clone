import lib/coup
import lib/coup/ids.{type ID}

pub type User {
  User(id: String, name: String)
}

pub fn from_user(user: coup.User(context)) -> User {
  User(id: user.id, name: user.name)
}

pub type Player {
  Player(id: String, name: String, influences: coup.Influences, coin: Int)
}

pub fn from_player(player: coup.Player(context)) -> Player {
  Player(
    id: player.id,
    name: player.name,
    influences: player.influences,
    coin: player.coin,
  )
}

pub type Event {
  ErrorEvent(coup.Error)
  LobbyEvent(LobbyEvent)
  GameEvent(GameEvent)
}

pub type LobbyEvent {
  LobbyInit(
    id: ID(ids.Lobby),
    users: List(User),
    user_id: String,
    host_id: String,
  )
  LobbyUpdatedUsers(users: List(User), host_id: String)
}

pub type GameEvent {
  GameInit(
    id: ID(ids.Game),
    players: List(Player),
    player_id: String,
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
  UserJoinLobby(id: ID(ids.Lobby), name: String)
}

pub type LobbyCommand {
  UserLeaveLobby
  UserStartGame
}

pub type GameCommand
