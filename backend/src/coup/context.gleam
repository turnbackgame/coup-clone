import gleam/erlang/process
import gleam/otp/actor
import lib/coup
import lib/coup/message

pub type Context {
  Context(subject: process.Subject(message.Event))
}

pub fn new() -> Context {
  Context(subject: process.new_subject())
}

pub fn send_error(ctx: Context, err: coup.Error) {
  actor.send(ctx.subject, message.ErrorEvent(err))
}
