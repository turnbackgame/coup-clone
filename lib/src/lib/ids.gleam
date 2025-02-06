import glanoid

const default_alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

pub fn generate(n: Int) -> String {
  let assert Ok(generator) = glanoid.make_generator(default_alphabet)
  generator(n)
}
