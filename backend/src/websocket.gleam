import coup
import coup/dashboard.{type Dashboard}
import coup/game.{type Game}
import coup/lobby.{type Lobby}
import gleam/erlang/process
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import lib/coup/json
import lib/coup/message
import lib/just
import mist.{type Connection, type ResponseData}

pub type User {
  User(
    ctx: coup.Context,
    dashboard: Dashboard,
    lobby: Option(Lobby),
    game: Option(Game),
  )
}

fn send_user_error(user: User, err: coup.Error) -> User {
  coup.error_to_string(err)
  |> message.ErrorEvent
  |> actor.send(user.ctx.subject, _)
  user
}

pub fn handle_request(
  request: Request(Connection),
  dashboard: Dashboard,
) -> Response(ResponseData) {
  let on_init = fn(_conn) {
    let ctx = coup.new_context()
    let selector =
      process.new_selector()
      |> process.selecting(ctx.subject, function.identity)
    let user = User(ctx:, dashboard:, lobby: None, game: None)
    #(user, Some(selector))
  }

  let on_close = fn(user: User) {
    {
      case user.lobby {
        Some(lobby) -> lobby.leave(lobby, user.ctx)
        None -> Nil
      }
    }
    {
      case user.game {
        Some(_game) -> todo as "convert player to bot"
        None -> Nil
      }
    }
  }

  use user, conn, msg <- mist.websocket(request:, on_init:, on_close:)
  case msg {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(user)
    }

    mist.Text(buf) -> {
      use <- just.try(fn(_err) { panic as "cannot handling command" })
      use command <- result.try(json.decode_command(buf))
      let user = handle_command(command, user)
      Ok(actor.continue(user))
    }

    mist.Custom(event) -> {
      use <- just.try(fn(_err) { panic as "cannot handling event" })
      let buf = json.encode_event(event)
      use _ <- result.try(mist.send_text_frame(conn, buf))
      Ok(actor.continue(user))
    }

    mist.Binary(_) | mist.Text(_) | mist.Custom(_) -> actor.continue(user)
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}

fn handle_command(command: message.Command, user: User) -> User {
  case command {
    message.DashboardCommand(dashboard_command) -> {
      let dashboard = user.dashboard
      handle_dashboard_command(dashboard_command, dashboard, user)
    }

    message.LobbyCommand(lobby_command) -> {
      use lobby <- just.try_some(user.lobby, fn() { user })
      handle_lobby_command(lobby_command, lobby, user)
    }

    message.GameCommand(game_command) -> {
      use game <- just.try_some(user.game, fn() { user })
      handle_game_command(game_command, game, user)
    }
  }
}

fn handle_dashboard_command(
  command: message.DashboardCommand,
  dashboard: Dashboard,
  user: User,
) -> User {
  case command {
    message.UserCreateLobby(name) -> {
      let lobby = dashboard.create_lobby(dashboard)
      let assert Ok(_) = lobby.join(lobby, user.ctx, name)
      User(..user, lobby: Some(lobby))
    }

    message.UserJoinLobby(id, name) -> {
      use <- just.try(send_user_error(user, _))
      use lobby <- result.try(dashboard |> dashboard.get_lobby(id))
      use _ <- result.try(lobby.join(lobby, user.ctx, name))
      Ok(User(..user, lobby: Some(lobby)))
    }
  }
}

fn handle_lobby_command(
  command: message.LobbyCommand,
  lobby: Lobby,
  user: User,
) -> User {
  case command {
    message.UserLeaveLobby -> {
      lobby.leave(lobby, user.ctx)
      User(..user, lobby: None)
    }

    message.UserStartGame -> {
      use <- just.try(send_user_error(user, _))
      use game <- result.try(lobby.start_game(lobby, user.ctx))
      Ok(User(..user, game: Some(game)))
    }
  }
}

fn handle_game_command(
  _command: message.GameCommand,
  _game: Game,
  _user: User,
) -> User {
  todo
}
