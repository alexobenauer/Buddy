let a = 1
let b = 2
let c = a + b
var d = 1;
d = 2;
print(c)

func greet(name: String) -> String {
  let message = "Hello, " + name + "!"
  return message
}

let result = greet(name: "World")
print(result)

class Example {
  var value: String?

  init(value: String? = "Hi") {
    self.value = value
  }
}

let example = Example(value: "Hello")

if let example {
  print(example.value)
} else {
  print("No value")
}