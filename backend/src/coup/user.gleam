import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import lib/coup.{type Actor, type Error}
import lib/coup/message.{type Event}
import lib/generator
import lib/id.{type Id}
import lib/ordered_dict as dict

pub type Users =
  dict.OrderedDict(Id(Actor), User)

pub type User {
  User(subject: Subject(Event), id: Id(Actor), name: String)
}

pub fn new() -> User {
  let id = generator.generate(5)
  User(
    subject: process.new_subject(),
    id: id |> id.from_string,
    name: "player-" <> id,
  )
}

pub fn send_error(user: User, err: Error) {
  actor.send(user.subject, message.ErrorEvent(err))
}

pub fn to_message(user: User) -> message.User {
  message.User(id: user.id, name: user.name)
}

pub fn update_name(user: User, name: String) -> User {
  User(..user, name:)
}
