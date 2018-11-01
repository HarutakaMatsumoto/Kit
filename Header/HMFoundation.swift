//
//  HMFoundation.swift
//
//
//  Created by 松本青空 on 2018/10/10.
//  Copyright © 2018年 松本青空. All rights reserved.
//
import Foundation

public extension CustomStringConvertible {
    public func printed() -> Self {
        print(self)
        return self
    }
}

public func printIndex() {
    print("\n")
}

public func printLine(_ line: Int = #line) {
    print(line)
}


public func HMPrint(_ items: Any...) {
    var initial = true
    for item in items {
        if initial {
            initial = false
        } else {
            print(", ", terminator: "")
        }
        switch item {/*
             case let it as SimpleCGRect:
             print(CGRect(sRect: it), terminator: "")*/
        default:
            print(item, terminator: "")
        }
    }
    print("")
}

public enum Side {
    case right,up,left,low
}

public enum Place: Int {
    case previous,center,upperRight,up,upperLeft,Left,lowerLeft,low,lowerRight,inner,next
}

public extension Array {
    public func chooseRandom() -> Element {
        return self[Int(arc4random_uniform(UInt32(self.count)))]
    }
}

public extension ArraySlice {
    public func chooseRandom() -> Element {
        return self[Int(arc4random_uniform(UInt32(self.count)))]
    }
    
    public func independentized() -> Array<Element> {
        return self.map { $0 }
    }
}

public extension Character {
    public var isHiragana: Bool {
        return 0x3040...0x309f ~= self.unicodeScalars.first!.value//なんか汚い
    }
}

public extension StringProtocol {
    public var katakanalized: String {
        let mapped = self.map { (character: Character) -> String in
            if character.isHiragana {
                return String(UnicodeScalar(character.unicodeScalars.first!.value + UInt32(0x30a0 - 0x3040))!)
            }
            return String(character)
        }
        
        let joined = mapped.joined()
        
        return joined
    }
}


infix operator **: PowerPrecedence//publicいらない
precedencegroup PowerPrecedence {//publicいらない
    higherThan: MultiplicationPrecedence
    lowerThan: BitwiseShiftPrecedence
    associativity: right
}

infix operator **=: AssignmentPrecedence

public protocol Powerable {
    static func ** (_: Self, _: Self) -> Self
}

public extension Powerable {
    public static func **= (lhs: inout Self, rhs: Self) {
        lhs = lhs ** rhs
    }
}

extension Double: Powerable {
    public static func ** (radix: Double, power: Double) -> Double {
        return pow(radix,power)
    }
    
    public static func random() -> Double {//0<=x<=1?
        return Double(arc4random())/Double(UInt32.max)
    }
}

extension Int: Powerable {
    public static func ** (radix: Int, power: Int) -> Int {
        var result = 1
        for _ in 0..<power {
            result *= radix
        }
        
        return result
    }
}

public extension Array {
    func printEach() {
        for one in self {
            print(one)
        }
    }
}



//MARK: system
#if os(macOS)
public func system(_ body: String) throws {
    let process = Process()
    let transProcess = Process()
    let pipe = Pipe()
    
    let directory: URL
    if #available(macOS 10.12, *)  {
        directory = FileManager.default.temporaryDirectory
    } else {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
    }
    let file = directory.appendingPathComponent("system.bash")
    try body.write(to: file, atomically: true, encoding: .utf8)
    
    process.arguments = [file.path]
    transProcess.arguments = [file.path]
    process.standardOutput = pipe
    process.standardError = pipe
    
    #if swift(>=4.1)
    if #available(macOS 10.13, *) {
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        transProcess.executableURL = URL(fileURLWithPath: "/usr/local/bin/dos2unix")
        try transProcess.run()
        try process.run()
    } else {
        process.launchPath = "/bin/bash"
        transProcess.launchPath = "/usr/local/bin/dos2unix"
        transProcess.launch()
        process.launch()
    }
    #else
    process.launchPath = "/bin/bash"
    transProcess.launchPath = "/usr/local/bin/dos2unix"
    transProcess.launch()
    process.launch()
    #endif
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()//availableDataで一つのコマンドの結果を出力する
    let output = String(data: data, encoding: String.Encoding.utf8)!
    print(output, terminator: "")
}
#endif

/************************************************Type Precedence***************************************************/
/*
protocol Ordered {}
protocol TypePrecedence {}

enum SingleTypePrecedence: Int, TypePrecedence {
    case cgFloat, double, int
}
extension TypePrecedence {
    var singel: SingleTypePrecedence{
        return self as! SingleTypePrecedence
    }
    
    var double: DoubleTypePrecedence{
        return self as! DoubleTypePrecedence
    }
}
protocol SingleOrdered: Ordered {}
extension Int: SingleOrdered {}
extension Double: SingleOrdered {}
extension CGFloat: SingleOrdered {}

struct HMQuantity {
    var type: TypePrecedence = SingleTypePrecedence.int
    var value: Ordered?
}

func transformedIntoHMQuantity(_ value: Ordered) -> HMQuantity {
    switch value {
    case is CGFloat:
        return HMQuantity(type: SingleTypePrecedence.cgFloat, value: value)
    case is Double:
        return HMQuantity(type: SingleTypePrecedence.double, value: value)
    case is Int:
        return HMQuantity(type: SingleTypePrecedence.int, value: value)
        
    case is CGPoint:
        return HMQuantity(type: DoubleTypePrecedence.cgPoint, value: value)
    case is CGSize:
        return HMQuantity(type: DoubleTypePrecedence.cgSize, value: value)
    default:
        assertionFailure()
        return HMQuantity()
    }
}
/*できたらこいつで一気に処理したい
func tranformedIntoOrdered(_ hmQuantity: HMQuantity) -> Ordered {
    switch hmQuantity.type {
    case SingleTypePrecedence.int:
        return hmQuantity.value as! Int
    case SingleTypePrecedence.double:
        return hmQuantity.value as! Double
    case SingleTypePrecedence.cgFloat:
        return hmQuantity.value as! CGFloat
        
    case DoubleTypePrecedence.cgPoint:
        return hmQuantity.value as! CGPoint
    case DoubleTypePrecedence.cgSize:
        return hmQuantity.value as! CGSize
    default:
        assertionFailure()
        return Int()
    }
}*/

func typeTransition(_ quantity: inout HMQuantity, to type: TypePrecedence) {
    switch type {
    case let singleType as SingleTypePrecedence:
        repeat {
            switch quantity.type {
            case SingleTypePrecedence.int:
                quantity.value = Double(quantity.value as! Int)
                quantity.type = SingleTypePrecedence.double
            case SingleTypePrecedence.double:
                quantity.value = CGFloat(quantity.value as! Double)
                quantity.type = SingleTypePrecedence.cgFloat
            case SingleTypePrecedence.cgFloat:
                assertionFailure()
            default:
                assertionFailure()
            }
        } while quantity.type as! SingleTypePrecedence != singleType
    case let doubleType as DoubleTypePrecedence:
        repeat {
            switch quantity.type {
            case DoubleTypePrecedence.cgSize:
                quantity.value = CGPoint(quantity.value as! CGSize)
                quantity.type = DoubleTypePrecedence.cgPoint
            case DoubleTypePrecedence.cgPoint:
                assertionFailure()
            default:
                assertionFailure()
            }
        } while quantity.type as! DoubleTypePrecedence != doubleType
    default:
        assertionFailure()
    }
}

func + (left: Ordered, right: Ordered) -> Ordered {//処理重くなる？
    var leftQuantity = HMQuantity()
    var rightQuantity = HMQuantity()
    
    leftQuantity = transformedIntoHMQuantity(left)
    rightQuantity = transformedIntoHMQuantity(right)
    
    if leftQuantity.type.singel.rawValue < rightQuantity.type.singel.rawValue {
        typeTransition(&rightQuantity, to: leftQuantity.type)
    } else if leftQuantity.type.singel.rawValue > rightQuantity.type.singel.rawValue {
        typeTransition(&leftQuantity, to: rightQuantity.type)
    }
    
    
    switch leftQuantity.type {
    case SingleTypePrecedence.int:
        return (leftQuantity.value as! Int) + (rightQuantity.value as! Int)
    case SingleTypePrecedence.double:
        return (leftQuantity.value as! Double) + (rightQuantity.value as! Double)
    case SingleTypePrecedence.cgFloat:
        return (leftQuantity.value as! CGFloat) + (rightQuantity.value as! CGFloat)
    case DoubleTypePrecedence.cgPoint:
        let leftCGPoint = leftQuantity.value as! CGPoint
        let rightCGPoint = rightQuantity.value as! CGPoint
        return CGPoint(x: leftCGPoint.x + rightCGPoint.x, y: leftCGPoint.y + rightCGPoint.y)
    case DoubleTypePrecedence.cgSize:
        let leftCGSize = leftQuantity.value as! CGSize
        let rightCGSize = rightQuantity.value as! CGSize
        return CGSize(width: leftCGSize.width + rightCGSize.width, height: leftCGSize.height + rightCGSize.height)
    default:
        assertionFailure()
        return Int()
    }
}

enum DoubleTypePrecedence: Int, TypePrecedence {
    case cgPoint, cgSize
}
protocol DoubleOrdered: Ordered {}
extension CGPoint: DoubleOrdered {}
extension CGSize: DoubleOrdered {}
//extension (SingleOrdered, SingleOrdered): DoubleOrdered {} これがやりたいいいいいいいいいいいいい
/*
func + (left: DoubleOrdered, right: DoubleOrdered) -> DoubleOrdered {//処理重くなる？
    var leftQuantity: HMQuantity? = nil
    var rightQuantity: HMQuantity? = nil
    
    switch left {
    case let value as CGPoint:
        leftQuantity = HMQuantity(type: DoubleTypePrecedence.cgPoint, value: value)
    case let value as CGSize:
        leftQuantity = HMQuantity(type: DoubleTypePrecedence.cgSize, value: value)
    /*case let value as (SingleOrdered, SingleOrdered):
         leftQuantity = HMQuantity(type: DoubleTypePrecedence.tuple, value: value) tupleはプロトコルをつけることができない*/
    }
    
    switch right {
    case let value as CGPoint:
        rightQuantity = HMQuantity(type: DoubleTypePrecedence.cgPoint, value: value)
    case let value as CGSize:
        rightQuantity = HMQuantity(type: DoubleTypePrecedence.cgSize, value: value)
    /*case let value as (SingleOrdered, SingleOrdered):
        rightQuantity = HMQuantity(type: DoubleTypePrecedence.tuple, value: value)*/
    }
    
    if leftQuantity!.type.double.rawValue < rightQuantity!.type.double.rawValue {
        typeTransition(&rightQuantity!, to: leftQuantity!.type)
    } else if leftQuantity!.type.singel.rawValue > rightQuantity!.type.singel.rawValue {
        typeTransition(&leftQuantity!, to: rightQuantity!.type)
    }
    
    switch leftQuantity!.type {
    case DoubleTypePrecedence.cgPoint:
        let leftCGPoint = leftQuantity!.value as! CGPoint
        let rightCGPoint = rightQuantity!.value as! CGPoint
        return CGPoint(x: leftCGPoint.x + rightCGPoint.x, y: leftCGPoint.y + rightCGPoint.y)
    case DoubleTypePrecedence.cgSize:
        let leftCGSize = leftQuantity!.value as! CGSize
        let rightCGSize = rightQuantity!.value as! CGSize
        return CGSize(width: leftCGSize.width + rightCGSize.width, height: leftCGSize.height + rightCGSize.height)/*
    case DoubleTypePrecedence.tuple:
        let leftTuple = left as! (SingleOrdered, SingleOrdered)
        let rightTuple = right as! (SingleOrdered, SingleOrdered)
        return (leftTuple.0 + rightTuple.0, leftTuple.1 + rightTuple.1) as! DoubleOrdered*/
    }
}*/
*/
/************************************************Type Precedence***************************************************/


