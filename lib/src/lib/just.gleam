import gleam/option.{type Option, None, Some}

pub fn try(alt: fn(err) -> b, result: fn() -> Result(b, err)) -> b {
  case result() {
    Ok(val) -> val
    Error(err) -> alt(err)
  }
}

pub fn try_ok(result: Result(a, err), alt: fn(err) -> b, ok: fn(a) -> b) -> b {
  case result {
    Ok(val) -> ok(val)
    Error(err) -> alt(err)
  }
}

pub fn try_error(
  result: Result(a, err),
  alt: fn(a) -> b,
  error: fn(err) -> b,
) -> b {
  case result {
    Ok(val) -> alt(val)
    Error(err) -> error(err)
  }
}

pub fn try_some(option: Option(a), alt: fn() -> b, some: fn(a) -> b) -> b {
  case option {
    Some(val) -> some(val)
    None -> alt()
  }
}

pub fn try_none(option: Option(a), alt: fn(a) -> b, none: fn() -> b) -> b {
  case option {
    Some(val) -> alt(val)
    None -> none()
  }
}
