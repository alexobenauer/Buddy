let runtime = libraryJS + """
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

function range(start, end) {
  return Array.from({ length: end - start + 1 }, (_, i) => start + i);
}

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

func charAt(_ str: String, index: Int) -> Character? {
    guard index >= 0, index < str.count else {
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

let libraryJS = [substrJS, charAtJS].joined(separator: "\n")
