//
//  NumericalAnalysis header file
//
//
//  Created by 松本青空 on 2017/04/19.
//  Copyright © 2017年 松本青空. All rights reserved.
//

import Foundation
import HMFoundation

/*
 protocol Number:Integer, FloatingPoint {}
 func sum<T:Number>(_ members:T...) -> T {
 return members.reduce(0, +)
 }
 func sum<T:Number>(_ sets:[T]...) -> [T] {
 return sets.reduce([T](), +)
 }
 func mean<T:Number>(_ members:T...) -> T {
 return members.reduce(0, +)/members.count
 }
 func mean<T:Number>(_ sets:[T]...) -> [T] {
 return sets.reduce([T](), +).map($0/sets.count)
 }*/
public struct Point<T: FloatingPoint> {//Vectorに統合？
    public var x = T(0)
    public var y = T(0)
    
    public init(x: T, y: T) {
        self.x = x
        self.y = y
    }
    
    public static func +(left: Point, right: Point) -> Point {
        return Point(x: left.x + right.x, y: left.y + right.y)
    }
    
    public static func -(left: Point, right: Point) -> Point {
        return Point(x: left.x - right.x, y: left.y - right.y)
    }
}

public class Scalar<Element: CustomStringConvertible>: NSObject, NSCopying {
    public var element: Element
    
    public init(_ element: Element) {
        self.element = element
    }
    
    // MARK: CustomStringConvertible
    public override var description: String {
        return element.description
    }
    
    // MARK: NSCoping
    public func copy(with zone: NSZone? = nil) -> Any {
        let newScalar = Scalar(self.element)
        
        return newScalar
    }
    
}

public class Vector<Element: CustomStringConvertible>: NSObject, NSCopying {
    
    public var scalars: [Scalar<Element>]
    
    public init(_ elements: [Element]) {
        self.scalars = [Scalar<Element>]()
        for element in elements {
            self.scalars.append(Scalar(element))
        }
    }
    
    public init(repeating value: Element, count: Int) {
        
        self.scalars = [Scalar<Element>]()
        for _ in 0..<count {
            
            self.scalars.append(Scalar(value))
        }
    }
    
    public override convenience init() {
        
        self.init([Element]())
    }
    
    // MARK: CustomStringConvertible
    public override var description: String {
        
        return scalars.map() { $0.description }.joined(separator: " ")
    }
    
    // MARK: NSCoping
    public func copy(with zone: NSZone? = nil) -> Any {
        let newVector = Vector<Element>()
        newVector.scalars = self.scalars.map() { $0.copy() as! Scalar }
        
        return newVector
    }
    
}

public class Matrix<Element: CustomStringConvertible>: NSObject, NSCopying {
    
    public var rows: [Vector<Element>] /*{//長方形であることを保証する
        didSet {
            guard let firstColumnCount = rows.first?.scalars.count else {
                
                rowCount = 0
                columnCount = 0
                return
            }
            
            for index in 1..<rows.count {
                if firstColumnCount != rows[index].scalars.count {
     fatalError("The count of the \(index + 1)th scalars: \(rows[index].scalars.count) is not equal to the 1st one \(firstColumnCount).")
                }
            }
            
            rowCount = rows.count
            columnCount = firstColumnCount
        }
    }*/
    
    public var columns: [Vector<Element>] {
        get {
            return transposed.rows
        }
        
        set {
            let newMatrix = Matrix<Element>()
            
            newMatrix.rows = newValue
            
            rows = newMatrix.transposed.rows
        }
    }
    
    public var rowCount: Int {
        return rows.count
    }
    
    public var columnCount: Int {
        return rows.first?.scalars.count ?? 0
    }
    
    public init(repeating value: Element, rowCount: Int, columnCount: Int) {
        
        rows = [Vector<Element>]()
        if rowCount <= 0 || columnCount <= 0 {
            fatalError()
        }
        
        for index in 0..<rowCount {
            
            rows.append(Vector<Element>())
            for _ in 0..<columnCount {
                rows[index].scalars.append(Scalar(value))
            }
        }
    }
    
    public init(rows: [[Element]]) {
        
        self.rows = [Vector<Element>]()
        for row in rows {
            self.rows.append(Vector(row))
        }
    }
    
    public override init() {
        
        rows = [Vector<Element>]()
        
        super.init()
    }
    
    public var transposed: Matrix<Element> {
        
        let result = Matrix<Element>()
        
        guard let firstRow = rows.first?.scalars else {
            return result
        }
        for scalar in firstRow {
            let vector = Vector<Element>()
            vector.scalars.append(scalar)
            result.rows.append(vector)
        }
        
        for row in rows.dropFirst() {
            for (index, scalar) in row.scalars.enumerated() {
                result.rows[index].scalars.append(scalar)
            }
        }
        
        return result
    }
    
    
    // MARK: CustomStringConvertible
    public override var description: String {
        return rows.map() { $0.description }.joined(separator: "\n")
    }
    
    // MARK: NSCoping
    public func copy(with zone: NSZone? = nil) -> Any {
        let newMatrix = Matrix<Element>()
        newMatrix.rows = self.rows.map() { $0.copy() as! Vector }
        
        return newMatrix
    }
    
}

extension Matrix where Element == Double {
    
    public func readLine() {
        
        guard let string = Swift.readLine() else {
            Swift.print("The standard input is noting.")
            return
        }
        
        var scanner = Scanner(string: string)
        let setToSkip = CharacterSet.controlCharacters.union(.whitespaces)
        scanner.charactersToBeSkipped = setToSkip
        
        var temporaryDouble = 0.0
        while scanner.scanDouble(&temporaryDouble) {//最初の一行の単語数で列数を決定する
            self.columns.append(Vector([temporaryDouble]))
        }
        
        values: while let string = Swift.readLine() {//valueMatrix取得
            scanner = Scanner(string: string)
            let vector = Vector<Double>()
            for _ in 0..<self.columnCount {
                if scanner.scanDouble(&temporaryDouble) {
                    /*if let int = Int(exactly: temporaryDouble) {
                     column.values.append(int)
                     } else {*/
                    vector.scalars.append(Scalar(temporaryDouble))
                    //}
                } else {
                    if string == "" {
                        break values
                    }
                    Swift.print("\(string) is not numeric, so I cancel reading.")
                    return
                }
            }
            
            self.rows.append(vector)
        }
    }
    
    
    public static func plot<T: FloatingPoint>(between range: ClosedRange<T>, by n: UInt, functions: ((T) -> T)...) -> Matrix<T> {
        let result = Matrix<T>()
        
        for index in 1...n {
            let vector = Vector<T>()
            let x = (range.upperBound - range.lowerBound)/T(n)*T(index) + range.lowerBound
            for function in functions {
                vector.scalars.append(Scalar(function(x)))
            }
            result.rows.append(vector)
        }
        
        return result
    }
}

open class DataMatrix: NSObject, NSCopying {
    
    public var keyMatrix = Matrix<String>()
    public var valueMatrix = Matrix<Double>()
    
    public var rowCount: Int {
        return keyMatrix.rowCount + valueMatrix.rowCount
    }
    
    public var columnCount: Int {
        return keyMatrix.columnCount
    }
    
    public func readLine(keysCount: Int) {
        precondition(keysCount >= 0)
        
        guard keysCount >= 1 else {
            self.valueMatrix.readLine()
            return
        }
        
        guard let string = Swift.readLine() else {
            Swift.print("The standard input is noting.")
            return
        }
        
        var scanner = Scanner(string: string)
        let setToSkip = CharacterSet.controlCharacters.union(.whitespaces)
        scanner.charactersToBeSkipped = setToSkip
        let keyMatrix = Matrix<String>()
        
        var temporaryNSString: NSString? = ""
        while scanner.scanUpToCharacters(from: setToSkip, into: &temporaryNSString) {//最初の一行の単語数で列数を決定する
            let newString = temporaryNSString! as String
            keyMatrix.columns.append(Vector([newString]))
        }
        
        for rowCount in 1..<keysCount {//keyMatrix取得
            guard let string = Swift.readLine() else {
                Swift.print("I can't recognize only \(rowCount - 1) rows, so cancel reading.")
                return
            }
            scanner = Scanner(string: string)
            
            let newRow = Vector<String>()
            for _ in 0..<keyMatrix.columnCount {
                let newScalar: Scalar<String>
                if scanner.scanUpToCharacters(from: setToSkip, into: &temporaryNSString) {
                    newScalar = Scalar(temporaryNSString! as String)
                } else {
                    newScalar = Scalar("")
                }
                newRow.scalars.append(newScalar)
            }
            
            keyMatrix.rows.append(newRow)
        }
        
        let valueMatrix = Matrix<Double>()
        values: while let string = Swift.readLine() {//valueMatrix取得
            scanner = Scanner(string: string)
            let vector = Vector<Double>()
            for _ in 0..<keyMatrix.columnCount {
                var temporaryDouble = 0.0
                if scanner.scanDouble(&temporaryDouble) {
                    /*if let int = Int(exactly: temporaryDouble) {
                     column.values.append(int)
                     } else {*/
                    vector.scalars.append(Scalar(temporaryDouble))
                    //}
                } else {
                    if string == "" {
                        break values
                    }
                    Swift.print("\(string) is not numeric, so I cancel reading.")
                    return
                }
            }
            
            valueMatrix.rows.append(vector)
        }
        
        self.keyMatrix = keyMatrix
        self.valueMatrix = valueMatrix
    }
    
    // MARK: CustomStringConvertible
    open override var description: String {
        return keyMatrix.description + "\n" + valueMatrix.description
    }
    
    // MARK: NSCopying
    public func copy(with zone: NSZone? = nil) -> Any {
        let newDataMatrix = DataMatrix()
        newDataMatrix.keyMatrix = self.keyMatrix.copy() as! Matrix
        newDataMatrix.valueMatrix = self.valueMatrix.copy() as! Matrix
        
        return newDataMatrix
    }
    
}


public func signedErrorRate(_ numerical: Double, to analysis: Double) -> Double {
    return (numerical - analysis)/abs(analysis)*100.0
}

public func factorial(_ n: Int) -> Int {//要一般化
    var result = 1
    for i in 1...n {
        result *= i
    }
    
    return result
}

public func combination(n: Int, k: Int) -> Int {
    return factorial(n)/(factorial(k)*factorial(k))
}

public func combination(n: Double, k: Double) -> Double {
    return tgamma(n + 1.0)/(tgamma(k + 1.0)*tgamma(n - k + 1.0))
}


//数値計算シリーズ
//MARK: 関数
public func normalDistributionGenerator(max: Double, mean: Double, dispersion: Double) -> (Double) -> Double {
    return {
        return max*exp(-(($0 - mean)**2.0/(2.0*dispersion)))
    }
}

public func binomialDistributionGenerator(max: Double, mean: Double, p: Double, n: Int) -> (Int) -> Double {
    let dn = Double(n)
    let dmaxK = mean.rounded()
    return {
        let dk = Double($0)
        return max/(tgamma(dk + 1.0)*tgamma(dn - dk + 1.0))*p**dk*(1.0 - p)**(dn - dk)*tgamma(dmaxK + 1.0)*tgamma(dn - dmaxK + 1.0)/(p**dmaxK*(1.0 - p)**(dn - dmaxK))
    }
}

public func poissonDistributionGenerator(max: Double, mean: Double) -> (Int) -> Double {
    let dmaxK = mean.rounded()
    return {
        let dk = Double($0)
        return max*mean**dk/tgamma(dk + 1.0)/(mean**dmaxK/tgamma(dmaxK + 1.0))
    }
}

//MARK: マシンイプシロンチェック
public func printMachineEpsilon() {//なんが標準で出た
    var a = 0.0, e = 1.0
    var i = 0
    
    repeat {
        e /= 2.0
        i += 1
        a = 1.0 + e
    } while a > 1.0
    
    print("Double型のマシンイプシロンは2.0e-\(i - 1)です\n")
}

//MARK: 補間法
public func lagrangeInterpolation<T>(points: [Point<T>], x: T) -> T {
    var result = T(0)
    
    for outerIndex in 0..<points.count {
        var numerator = points[outerIndex].y
        var denominator = T(1)
        for innerIndex in 0..<points.count {
            if outerIndex != innerIndex {
                numerator *= x - points[innerIndex].x
                denominator *= points[outerIndex].x - points[innerIndex].x
            }
        }
        result += numerator/denominator
    }
    
    return result
}

public extension Array where Iterator.Element == Point<Double> {
    /**
     点配列に対応する次数最小の補間式f(x)を返す
     -parameter 取り出す補間値yのx座標
 */
    func interpolation(x: Double) -> Double {
        return lagrangeInterpolation(points: self, x: x)
    }
}

//MARK: 積分
public func trapezoidalRule<T: FloatingPoint>(a: T, b: T, n: UInt, f: (T) -> T) -> T {
    var result = T(0)
    let h = (b - a)/T(n)

    result += (f(a) + f(b))/T(2)
    precondition(n > 1)
    for i in 1...n - 1 {
        result += f(a + T(i)*h)
    }
    
    result *= h

    return result
}

public func simpson3<T: FloatingPoint>(a: T, b: T, n: UInt, f: (T) -> T) -> T {//シンプソン1/3公式 Eulerに置換？
    var result = T(0)
    let h = (b - a)/T(2*n)
    
    result += f(a) + f(b)
    precondition(n > 1)
    for i in 1...n - 1 {
        result += T(4)*f(a + (T(2*i - 1))*h)
        result += T(2)*f(a + T(2*i)*h)
    }
    result += T(4)*f(a + T(2*n - 1)*h)
    
    result *= h
    result /= T(3)
    
    return result
}

public func simpson8<T: FloatingPoint>(a: T, b: T, n: UInt, f: (T) -> T) -> T {//シンプソン3/8公式
    var result = T(0)
    let h = (b - a)/T(3*n)
    
    result += f(a) + f(b)
    for i in 1...n - 1 {
        result += T(3)*(f(a + T(3*i - 1)*h) + f(a + T(3*i - 2)*h))
        result += T(2)*f(a + T(3*i)*h)
    }
    result += T(3)*(f(a + T(3*n - 1)*h) + f(a + T(3*n - 2)*h))
    
    result *= T(3)*h
    result /= T(8)
    
    return result
}

/**
 関数f(x)についてaからbまでn等分した近似積分を行う。 simpson3と同値。
 -parameter from a: 始点
 to b: 終点
 by n: 分割数
 f: 被積分関数
 */
public func definiteIntegrate<T: FloatingPoint>(from a: T, to b: T, by n: UInt, f: (T) -> T) -> T {
    switch n {
    case 0:
        return T(0)
    case 1:
        return (f(a) + f(b))/T(2)
    default:
        return simpson3(a: a, b: b, n: n, f: f)
    }
}

public func indefiniteIntegrate<T: BinaryFloatingPoint>(withInitialCondition constant: Point<T>, dx: T, function: @escaping (T) -> T) -> (T) -> T {
    return { x in
        let a = constant.x
        let index = UInt((x - a)/dx)
        return definiteIntegrate(from: a, to: x, by: index, f: function) + constant.y
    }
}

//MARK: 微分
//三点近似法
public func differentiate<T: FloatingPoint>(ofEffectiveRange range: ClosedRange<T>, by n: UInt, function: @escaping (T) -> (T)) -> (T) -> T {
    return {
        let h = (range.upperBound - range.lowerBound)/T(n)
        return (function($0 + h) - function($0 - h)) / (T(2) * h)
    }
}

//MARK: 常微分方程式
public func eulerMethod<T>(initialPoint: Point<T>, x: T, n: UInt, f: (Point<T>) -> T) -> T {
    let h = (x - initialPoint.x)/T(n)
    
    var point = initialPoint
    for _ in 0..<n {
        point.y += h*f(point)
        point.x += h
    }
    
    return point.y
}

public func modifiedEulerMethod<T>(initialPoint: Point<T>, x: T, n: UInt, f: (Point<T>) -> T) -> T {
    let h = (x - initialPoint.x)/T(n)
    
    var point = initialPoint
    for _ in 0..<n {
        point.y += h*f(point + Point(x: h/T(2), y: h*f(point)/T(2)))
        point.x += h
    }
    
    return point.y
}

public func rungeKuttaMethod<T>(initialPoint: Point<T>, x: T, n: UInt, f: (Point<T>) -> T) -> T {
    let h = (x - initialPoint.x)/T(n)
    var k = Array(repeating: T(0), count: 4)
    
    var point = initialPoint
    for _ in 0..<n {
        k[0] = f(point)
        k[1] = f(point + Point(x: h/T(2), y: h*k[0]/T(2)))
        k[2] = f(point + Point(x: h/T(2), y: h*k[1]/T(2)))
        k[3] = f(point + Point(x: h, y: h*k[2]))
        point.y += k[0] + k[3]
        point.y += T(2)*(k[1] + k[2])
        point.x += h
    }
    point.y *= h/T(6)
    
    return point.y
}

/**
 一階常微分方程式dy/dx = f(x,y)について, 初期条件(x_0,y_0)を与えて解く。
 -parameter initialPoint: 初期条件(x_0,y_0)
 x: 欲しい値のx座標
 f: 関数f(x,y)
 */
public func firstOrderOrdinalDifferentialEquation<T>(initialPoint: Point<T>, x: T, n: UInt, f: (Point<T>) -> T) -> T {
    return rungeKuttaMethod(initialPoint: initialPoint, x: x, n: n, f: f)
}

/**
 n本の関数dy_i/dx=f_i(x,y_1,...,y_n) (nは非負整数)について, 初期条件y_i(a)を与えてx=bまで解き, [b,y_1(b),...,y_n(b)]を返す。
 */
@discardableResult
public func simultaneousOrdinalDifferentialEquation(
    from initialX: Double,
    to terminalX: Double,
    by n: Int,
    of contents: [(df:([Double]) -> Double, initialY: Double)],
    forEach: (([Double]) -> Void)? = nil
    ) -> [Double] {
    
    let h = (terminalX - initialX)/Double(n)
    
    var arguments = [Double]()
    var ys = [Double]()
    arguments.append(initialX)
    for (_, aY) in contents {
        arguments.append(aY)
        ys.append(aY)
    }
    
    var k = Array(repeating: Array(repeating: 0.0, count: 4), count: contents.count)
    for _ in 0..<n {
        forEach?(arguments)
        
        for index in 0..<contents.count {
            k[index][0] = contents[index].df(arguments)
        }
        
        arguments[0] += h/2.0
        for index in 1..<arguments.count {
            arguments[index] = ys[index - 1] + h*k[index - 1][0]/2.0
        }
        for index in 0..<contents.count {
            k[index][1] = contents[index].df(arguments)
        }
        
        for index in 1..<arguments.count {
            arguments[index] = ys[index - 1] + h*k[index - 1][1]/2.0
        }
        for index in 0..<contents.count {
            k[index][2] = contents[index].df(arguments)
        }
        
        arguments[0] += h/2.0
        for index in 1..<arguments.count {
            arguments[index] = ys[index - 1] + h*k[index - 1][2]
        }
        for index in 0..<contents.count {
            k[index][3] = contents[index].df(arguments)
            
        }
        
        for index in 0..<contents.count {
            ys[index] += h*(k[index][0] + 2.0*(k[index][1] + k[index][2]) + k[index][3])/6.0
            arguments[index + 1] = ys[index]
        }
    }
    forEach?(arguments)
    
    return ys
}

//MARK: 非線形方程式
let epsilon = (numerator: 1, denominator: 10_000_000)
let nmax = 1000000
/**
 (a, b)で関数f(x)は連続であり、この区間で一つだけf(x)=0となる解x_0が存在するときその解を返す。
 間に変曲点があってもいける？
 */
public func bisectionMethod<T: FloatingPoint>(a bufferA: T, b bufferB: T, f: (T) -> T) -> T {
    var a = bufferA, b = bufferB, c = T(0)
    let fa = f(a)
    
    while b - a > T(epsilon.numerator)/T(epsilon.denominator) {//?
        c = (a + b)/T(2)
        
        if fa*f(c) <= T(0) {
            b = c
        } else {
            a = c
        }
    }
    
    return a
}
/**
 (a, b)で関数f(x)は連続であり、この区間で一つだけf(x)=0となる解x_0が存在するときその解を返す。
 変曲点が解である時無限ループ
 */
public func regulaFalsiMethod<T: FloatingPoint>(a bufferA: T, b bufferB: T, f: (T) -> T) -> T {
    var a = bufferA, b = bufferB, c = T(0)
    let fa = f(a)
    
    var i = 0
    while true {
        c = (a + b)/T(2)
        
        i += 1
        if (c - a)*(b - c) < T(epsilon.numerator)/T(epsilon.denominator) {
            break
        } else if i == nmax {
            print("計算を打ち切りました。")
            break
        }
        
        if fa*f(c) <= T(0) {
            b = c
        } else {
            a = c
        }
    }
    
    return a
}
/**
 (a, b)で関数f(x), f'(x)は連続であり、この区間で一つだけf(x)=0となる解x_0が存在するときその解を返す。
 f'(x)=0になるループが起こった時ランニングエラー
 */
public func newtonMethod<T: FloatingPoint>(x bufferX: T, f: (T) -> T, df: (T) -> T) -> T {
    var d = T(0)
    var x = bufferX
    
    var i = 0
    while true {
        d = f(x)/df(x)
        x = x - d
        
        i += 1
        if abs(d) > T(epsilon.numerator)/T(epsilon.denominator) {
            break
        } else if i == nmax {
            print("計算を打ち切りました。")
            break
        }
    }
    
    return x
}
/**
 (a, b)で関数f(x),f'(x)は連続であり、この区間で一つだけf(x)=0となる解x_0が存在するときその解を返す。
 f'(x)=0になるループが起こった時ランニングエラー
 四つの手法の中で最速
 間に変曲点があるとダメ？
 */
public func secantMethod<T: FloatingPoint>(a bufferA: T, b bufferB: T, f: (T) -> T) -> T {
    var a = bufferA, b = bufferB, c = T(0)
    
    var i = 0
    while true {
        c = f(b)*(b - a)/(f(b) - f(a))
        a = b
        b = b - c
        
        i += 1
        if abs(c) > T(epsilon.numerator)/T(epsilon.denominator) {
            break
        } else if i == nmax {
            print("計算を打ち切りました。")
            break
        }
    }
    
    return b
}

//MARK: 系列相関検定
public func serialCorrelationExamination<T: FloatingPoint>(n: UInt, randFunction: () -> T) -> [Point<T>] {
    var returnValue = [Point<T>]()
    var r0: T, r1: T
    
    r0 = randFunction()
    for _ in 0..<n {
        r1 = randFunction()
        returnValue.append(Point(x: r0, y: r1))
        r0 = r1
    }
    
    return returnValue
}

//MARK: 重み付き乱数

public func vonNeumannRejectionMethod(x1: Double, x2: Double, fMax: Double, f: (Double) -> Double) -> Double {
    var x = 0.0, y = 0.0
    
    repeat {
        x = Double.random()*(x2 - x1)
        y = Double.random()*fMax
    } while y > f(x)
    
    return x
}

public func inverseTransformSampling(G: (Double) -> Double) -> Double {
    return G(Double.random())
}


//MARK: Variable Size Floating Point Number

/*
struct VInt {
    var radix: UInt8 = 10 {
        didSet {
            if radix == 0 {
                assertionFailure()
            }
        }
    }
    var sign: Bool = true
    var fraction: [UInt8] = [0]//逆順
    
    private struct Buffer {//いらない？
        var radix: UInt = 10 {
            didSet {
                if radix == 0 {
                    assertionFailure()
                }
            }
        }
        var sign: Bool = true
        var fraction: [UInt16] = [0]//逆順
    }
    
    func convertedRadix(to newRadix: UInt8) -> VInt {
        var buffer = UInt16()
        var newVInt = VInt()
        
        newVInt.radix = newRadix
        newVInt.sign = self.sign
        for i in 0..<self.fraction.count {
            var j = 0
            
            while true {
                buffer = self.fraction[i]*self.radix ^^ i + newVInt.fraction[j]
                newVInt[j] = buffer%newVInt.radix
                if buffer < newVInt.radix {
                    break
                }
                newVInt.append((buffer - newVInt[j])/newVInt.radix)
                
                j += 1
            }
        }
        
        return newVInt
    }
    
    mutating func convertRadix(to newRadix: UInt8) {
        self = self.convertedRadix(to: newRadix)
    }
    
    static func +(left: VInt, right: VInt) -> VInt {
        if left.radix != right.radix {//異基数は弾く
            assertionFailure
        }
        
        var buffer = UInt16()
        var newVInt = VInt()
        
        newVInt.radix = left.radix
        if !(left.sign ^ right.sign) {
            if left.sign {
                right.sign = true
                return left - right
            } else {
                left.sign = true
                return right - left
            }
        }
        for i in 0..<left.fraction.count {
            if i >= right.fraction.count {
                return left
            }
            //こっから
            buffer = left.fraction[i] + right.fraction[i]
            
            var j = i
            
                newVInt[j] = buffer%newVInt.radix
                if buffer < newVInt.radix {
                    break
                }
                newVInt.append((buffer - newVInt[j])/newVInt.radix)
                
                j += 1
            }
        return left
        }
}


struct VFloat {
    var numerator = VInt()
    var denominator = VInt(radix: 10, sign: true, fraction: [1])
    
    var sign: Bool {
        get {
            return numerator.sign + denominator.sign
        }
    }
    
    enum TypeOfArrangeRadix {
        case number(UInt8)
        case numerator, denominator
    }
    func arrangeRadix(to buffer: TypeOfArrangeRadix) {
        switch buffer {
        case .number(newRadix):
            numerator.convertRadix(to: newRadix)
            denominator.convertRadix(to: newRadix)
        case .numerator:
            denominator.convertRadix(to: numerator.radix)
        case .denominator:
            numerator.convertRadix(to: denominator.radix)
        }
    }
    
    
}

*/
















