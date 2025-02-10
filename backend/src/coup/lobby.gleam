import coup/coup
import gleam/bool
import gleam/deque.{type Deque}
import gleam/list
import gleam/otp/actor

pub type Lobby {
  Lobby(id: String, host_id: String, users: Deque(coup.User))
}

pub fn new(id: String) -> Lobby {
  Lobby(id:, host_id: "", users: deque.new())
}

/// Add user to the lobby.
/// If more than 6 users in the lobby, returns Error(Nil).
/// If only one user in the lobby, set host status to the user.
pub fn add_user(lobby: Lobby, user: coup.User) -> Result(Lobby, Nil) {
  let users =
    lobby.users
    |> deque.push_back(user)
    |> deque.to_list

  let users_count = list.length(users)

  use <- bool.lazy_guard(users_count > 6, fn() {
    coup.SendError("the lobby is full")
    |> actor.send(user.subject, _)
    Error(Nil)
  })

  let host_id = {
    use <- bool.guard(users_count == 1, user.id)
    lobby.host_id
  }

  users
  |> list.each(fn(u) {
    case u == user {
      True -> coup.LobbyInit(id: lobby.id, user_id: u.id, host_id:, users:)
      False -> coup.LobbyUpdatedUsers(host_id:, users:)
    }
    |> actor.send(u.subject, _)
  })

  Ok(Lobby(..lobby, host_id:, users: deque.from_list(users)))
}

/// Remove user from the lobby.
/// If no users left in the lobby, returns Error(Nil).
/// If the user is the host, transfer host status to other user.
pub fn remove_user(lobby: Lobby, user: coup.User) -> Result(Lobby, Nil) {
  let users =
    lobby.users
    |> deque.to_list
    |> list.filter(fn(u) { u != user })

  use <- bool.guard(list.is_empty(users), Error(Nil))

  let host_id = {
    use <- bool.guard(user.id != lobby.host_id, lobby.host_id)
    let assert Ok(first) = list.first(users)
    first.id
  }

  users
  |> list.each(fn(u) {
    coup.LobbyUpdatedUsers(host_id:, users:)
    |> actor.send(u.subject, _)
  })

  Ok(Lobby(..lobby, host_id:, users: deque.from_list(users)))
}

pub fn is_user_host(lobby: Lobby, user: coup.User) -> Bool {
  lobby.host_id == user.id
}
