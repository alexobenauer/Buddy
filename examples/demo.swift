func greet(name: String) -> String {
  let message = "Hello, " + name + "!";
  return message;
}

let result = greet(name: "World")
print(result)