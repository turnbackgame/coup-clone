import coup/dashboard.{type Dashboard}
import coup/game.{type Game}
import coup/lobby.{type Lobby}
import coup/user.{type User}
import gleam/bool
import gleam/erlang/process
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import lib/coup
import lib/coup/json
import lib/coup/message
import lib/just
import mist.{type Connection, type ResponseData}

pub type Session {
  Session(
    user: User,
    dashboard: Dashboard,
    lobby: Option(Lobby),
    game: Option(Game),
  )
}

pub fn send_error(session: Session, err: coup.Error) -> Session {
  actor.send(session.user.subject, message.ErrorEvent(err))
  session
}

pub fn handle_request(
  request: Request(Connection),
  dashboard: Dashboard,
) -> Response(ResponseData) {
  let on_init = fn(_conn) {
    let user = user.new()
    let selector =
      process.new_selector()
      |> process.selecting(user.subject, function.identity)
    let session = Session(user:, dashboard:, lobby: None, game: None)
    #(session, Some(selector))
  }

  let on_close = fn(session: Session) {
    {
      case session.lobby {
        Some(lobby) -> lobby.leave(lobby, session.user)
        None -> Nil
      }
    }
    {
      case session.game {
        Some(_game) -> todo as "convert player to bot"
        None -> Nil
      }
    }
  }

  use session, conn, msg <- mist.websocket(request:, on_init:, on_close:)
  case msg {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(session)
    }

    mist.Text(buf) -> {
      use <- just.try(fn(_err) { panic as "cannot handling command" })
      use command <- result.try(json.decode_command(buf))
      handle_command(session, command)
      |> actor.continue
      |> Ok
    }

    mist.Custom(event) -> {
      use <- just.try(fn(_err) { panic as "cannot handling event" })
      let buf = json.encode_event(event)
      use _ <- result.try(mist.send_text_frame(conn, buf))
      Ok(actor.continue(session))
    }

    mist.Binary(_) | mist.Text(_) | mist.Custom(_) -> actor.continue(session)
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}

fn handle_command(session: Session, command: message.Command) -> Session {
  case command {
    message.DashboardCommand(dashboard_command) -> {
      let dashboard = session.dashboard
      handle_dashboard_command(session, dashboard_command, dashboard)
    }

    message.LobbyCommand(lobby_command) -> {
      use lobby <- just.try_some(session.lobby, fn() { session })
      handle_lobby_command(session, lobby_command, lobby)
    }

    message.GameCommand(game_command) -> {
      use game <- just.try_some(session.game, fn() { session })
      handle_game_command(session, game_command, game)
    }
  }
}

fn handle_dashboard_command(
  session: Session,
  command: message.DashboardCommand,
  dashboard: Dashboard,
) -> Session {
  case command {
    message.UserCreateLobby(name) -> {
      let user = {
        use <- bool.guard(name |> string.is_empty, session.user)
        session.user |> user.update_name(name)
      }
      let lobby = dashboard.create_lobby(dashboard)
      let assert Ok(_) = lobby.join(lobby, user)
      Session(..session, user:, lobby: Some(lobby))
    }

    message.UserJoinLobby(id, name) -> {
      let user = {
        use <- bool.guard(name |> string.is_empty, session.user)
        session.user |> user.update_name(name)
      }
      use <- just.try(send_error(session, _))
      use lobby <- result.try(dashboard |> dashboard.get_lobby(id))
      use _ <- result.try(lobby.join(lobby, user))
      Ok(Session(..session, user:, lobby: Some(lobby)))
    }
  }
}

fn handle_lobby_command(
  session: Session,
  command: message.LobbyCommand,
  lobby: Lobby,
) -> Session {
  case command {
    message.UserLeaveLobby -> {
      lobby.leave(lobby, session.user)
      Session(..session, lobby: None)
    }

    message.UserStartGame -> {
      use <- just.try(send_error(session, _))
      use game <- result.try(lobby.start_game(lobby, session.user))
      Ok(Session(..session, game: Some(game)))
    }
  }
}

fn handle_game_command(
  _session: Session,
  _command: message.GameCommand,
  _game: Game,
) -> Session {
  todo
}
