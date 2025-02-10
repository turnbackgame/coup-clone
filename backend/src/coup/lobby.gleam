import coup/coup
import gleam/bool
import gleam/deque.{type Deque}
import gleam/list

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
  let updated_users =
    lobby.users
    |> deque.push_back(user)
  let users_count = deque.length(updated_users)
  use <- bool.guard(users_count > 6, Error(Nil))
  use <- bool.guard(
    users_count == 1,
    Ok(Lobby(..lobby, host_id: user.id, users: updated_users)),
  )
  Ok(Lobby(..lobby, users: updated_users))
}

/// Remove user from the lobby.
/// If no users left in the lobby, returns Error(Nil).
/// If the user is the host, transfer host status to other user.
pub fn remove_user(lobby: Lobby, user: coup.User) -> Result(Lobby, Nil) {
  let updated_users =
    lobby.users
    |> deque.to_list
    |> list.filter(fn(u) { u != user })
  use <- bool.guard(list.is_empty(updated_users), Error(Nil))
  use <- bool.guard(
    user.id != lobby.host_id,
    Ok(Lobby(..lobby, users: deque.from_list(updated_users))),
  )
  let assert Ok(first) = list.first(updated_users)
  Ok(Lobby(..lobby, host_id: first.id, users: deque.from_list(updated_users)))
}
