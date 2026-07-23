///|
test {
  inspect(dot([1.0, 2.0], [3.0, 4.0]), content="11")
}

///|
test {
  let vector = [3.0, 4.0]
  normalize_in_place(vector)
  inspect(vector[0] > 0.0, content="true")
  inspect(vector[1] > 0.0, content="true")
}

///|
test {
  inspect(signature_bits_count(3, [1.0, -1.0, 0.5]), content="5")
}
