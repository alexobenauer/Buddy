func runtime(minimalRuntime: Bool) -> String {
    return [
        // Functions used by the code emitted from the transpiler
        """
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
        """,
    
        // Functions available to user Swift code, providing both JS and Swift implementations so the transpiler can be built in Swift
        makeFunction(substrJS, minimalRuntime: minimalRuntime),
        makeFunction(charAtJS, minimalRuntime: minimalRuntime),
        
        // Functions available to user Swift code, only JS implementation provided
        makeFunction(stringifyJS, minimalRuntime: minimalRuntime),
        makeFunction(printJS, minimalRuntime: minimalRuntime)
    ].joined(separator: "\n")
}

// Above functions are used by the code emitted from the transpiler

// Below functions are available to user Swift code, providing both JS and Swift implementations so the transpiler can be built in Swift

// let libraryJS = [substrJS, charAtJS].joined(separator: "\n") + """

// const stringify = {
//     value: (params) => {
//         const { _: arg } = params;
//         return JSON.stringify(arg);
//     }
// }

// const print = {
//     value: (params) => {
//         const { _: arg } = params; // TODO: Multi-arg support
//         console.log(arg);
//     }

//     // TODO: Multi-arg support
//     //(...args) {
//     //  console.log(...args);
//     //}
// }
// """;

let stringifyJS = JSFunctionDeclaration(name: "stringify", body: """
const { _: arg } = params;
return JSON.stringify(arg);
""")

let printJS = JSFunctionDeclaration(name: "print", body: """
const { _: arg } = params; // TODO: Multi-arg support
console.log(arg);

// TODO: Multi-arg support
//(...args) {
//  console.log(...args);
//}
""")

func substr(_ str: String, start: Int, end: Int) -> String {
    guard start >= 0, end >= start, end <= str.count else {
        return ""  // Return empty string for invalid indices
    }
    
    let startIndex = str.index(str.startIndex, offsetBy: start)
    let endIndex = str.index(str.startIndex, offsetBy: end)
    
    return String(str[startIndex..<endIndex])
}

let substrJS = JSFunctionDeclaration(name: "substr", body: """
const { _: str, start, end } = params;

if (start < 0 || end < start || end > str.length) {
    return "";  // Return empty string for invalid indices
}

return str.slice(start, end);
""")

func charAt(_ str: String, index: Int, stringLength: Int? = 0) -> Character? {
    guard index >= 0, index < (stringLength ?? str.count) else {
        return nil  // Return nil for invalid index
    }
    
    let stringIndex = str.index(str.startIndex, offsetBy: index)
    return str[stringIndex]
}

let charAtJS = JSFunctionDeclaration(name: "charAt", body: """
const { _: str, index } = params;

if (index < 0 || index >= str.length) {
    return null;  // Return null for invalid index
}

return str.charAt(index);
""")

struct JSFunctionDeclaration {
    let name: String
    let body: String
}

func makeFunction(_ function: JSFunctionDeclaration, minimalRuntime: Bool) -> String {
    let fnName = function.name
    let fnBody = function.body

    if minimalRuntime {
        return """
        function \(fnName)(params) {
            \(fnBody)
        }
        """
    }
    else {
        return """
        const \(fnName) = {
            value: (params) => {
                \(fnBody)
            }
        }
        """
    }
}
