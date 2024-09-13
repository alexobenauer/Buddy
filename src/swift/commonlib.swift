let runtime = libraryJS + """
Array.prototype.append = function(params) {
  const { _: element } = params;
  this.push(element);
  return this;
};

Object.defineProperty(String.prototype, 'count', {
  get: function() {
    return this.length;
  },
  enumerable: false,
  configurable: true
});

function range(start, end) {
  return Array.from({ length: end - start + 1 }, (_, i) => start + i);
}

function tryOptional(fn) {
    try {
        return fn();
    } catch {
        return null;
    }
}

function tryForce(fn) {
    try {
        return fn();
    } catch {
        throw new Error("Fatal error: force try failed with error: " + error);
    }
}
"""

// Above functions are used by the code emitted from the transpiler

// Below functions are available to user Swift code, providing both JS and Swift implementations so the transpiler can be built in Swift

let libraryJS = [substrJS, charAtJS].joined(separator: "\n") + """

function stringify(params) {
    const { _: arg } = params;
    return JSON.stringify(arg);
}

//function print(...args) {
//  console.log(...args);
//}

function print(params) {
    const { _: arg } = params; // TODO: Multi-arg support
    console.log(arg);
}
""";

func substr(_ str: String, start: Int, end: Int) -> String {
    guard start >= 0, end >= start, end <= str.count else {
        return ""  // Return empty string for invalid indices
    }
    
    let startIndex = str.index(str.startIndex, offsetBy: start)
    let endIndex = str.index(str.startIndex, offsetBy: end)
    
    return String(str[startIndex..<endIndex])
}

let substrJS = """
function substr(params) {
    const { _: str, start, end } = params;
    if (start < 0 || end < start || end > str.length) {
        return "";  // Return empty string for invalid indices
    }
    
    return str.slice(start, end);
}
"""

func charAt(_ str: String, index: Int, stringLength: Int? = 0) -> Character? {
    guard index >= 0, index < (stringLength ?? str.count) else {
        return nil  // Return nil for invalid index
    }
    
    let stringIndex = str.index(str.startIndex, offsetBy: index)
    return str[stringIndex]
}

let charAtJS = """
function charAt(params) {
    const { _: str, index } = params;
    if (index < 0 || index >= str.length) {
        return null;  // Return null for invalid index
    }

    return str.charAt(index);
}
"""

// func repeatString(_ str: String, count: Int) -> String {
//     return String(repeating: str, count: count)
// }

// let repeatJS = """
// function repeatString(params) {
//     const { _: str, count } = params;
//     return str.repeat(count);
// }
// """
