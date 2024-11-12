//
//  in-out-parameter-lab.swift
//  swift-lab
//
//  Created by minghao xue on 2024/11/11.
//

func runInOutParameterTests() {
    runBasicUsage()
    runCopyMechanism()
    runSimultaneous()
}

// MARK: Basic usage

func runBasicUsage() {
    var a = 1
    var b = 2
    swapInt(&a, &b)
    print("Basic usage, a: ", a, " b: ", b)
}

// MARK: Copy-in, copy-out

struct Container {
    private var _a: Int = 1
    private var _b: Int = 2
    var a: Int {
        get {
            print("Getter of a is called")
            return _a
        }
        set {
            print("Setter of a is called")
            _a = newValue
        }
    }
    var b: Int {
        get {
            print("Getter of b is called")
            return _b
        }
        set {
            print("Setter of b is called")
            _b = newValue
        }
    }
}

func runCopyMechanism() {
    var c = Container()
    increment(&c.a)
    increment(&c.b)
    print("Copy mechnism, a: ", c.a, " b: ", c.b)
}

// MARK: Simultaneous access

func runSimultaneous() {
    var outer = 10
    
    func write(_ a: inout Int) {
        a = outer
    }
    
    func read(_ a: inout Int, _ b: inout Int) {
        
    }
//    write(&outer)
    
//    read(&outer, &outer)
}


// MARK: Helper methods

func increment(_ value: inout Int) {
    value += 1
}

func swapInt(_ a: inout Int, _ b: inout Int) {
    let temporaryA = a
    a = b
    b = temporaryA
}
