//
//  HMHeader.swift
//  マスターノート２
//
//  Created by 松本青空 on 2016/10/26.
//  Copyright © 2016年 松本青空. All rights reserved.
//

import UIKit
import HMFoundationForiOS

extension CGFloat: Powerable {
    static func ** (radix: Double, power: CGFloat) -> CGFloat {
        return pow(CGFloat(radix),power)
    }
    static func ** (radix: CGFloat, power: Double) -> CGFloat {
        return pow(radix,CGFloat(power))
    }
    public static func ** (radix: CGFloat, power: CGFloat) -> CGFloat {
        return pow(radix,power)
    }
}

func arc4random_uniform(_ range: CountableClosedRange<UInt32>) -> UInt32 {//upperBoundを含まない？
    return range.lowerBound + arc4random_uniform(range.upperBound - range.lowerBound)
}
extension CGPoint {//演算は基本的にCGPointを介す
    init(_ size: CGSize) {
        self.init(x: size.width, y: size.height)
    }
    
    init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY)
    }
    
    func length() -> CGFloat {
        return sqrt(self.x**2.0 + self.y**2.0)
    }
}

func += (left: inout CGPoint, right: CGPoint) {
    left.x += right.x
    left.y += right.y
}


func -= (left: inout CGPoint, right: CGPoint) {
    left.x -= right.x
    left.y -= right.y
}


func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + -right.x, y: left.y + -right.y)
}

func * (left: CGFloat, right: Double) -> CGFloat {
    return left*CGFloat(right)
}

func * (left: CGPoint, right: Double) -> CGPoint {
    return CGPoint(x: left.x*right, y: left.y*right)
}

func / (left: CGFloat, right: Double) -> CGFloat {
    return left/CGFloat(right)
}

func / (left: CGPoint, right: Double) -> CGPoint {
    return CGPoint(x: left.x/right, y: left.y/right)
}

extension CGSize {
    init(_ rect: CGRect) {
        self.init(width: rect.width, height: rect.height)
    }
    
    var center: CGPoint{
        return CGPoint(self)/2.0
    }
}

func += (left: inout CGSize, right: CGSize) {
    left.width += right.width
    left.height += right.height
}

func -= (left: inout CGSize, right: CGSize) {
    left.width -= right.width
    left.height -= right.height
}

func += (left: inout CGRect, right: CGRect) {
    left.origin += right.origin
    left.size += right.size
}

func -= (left: inout CGRect, right: CGRect) {
    left.origin -= right.origin
    left.size -= right.size
}

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(origin: center - CGPoint(size)/2, size: size)
    }
    
    var center: CGPoint{
        return self.origin + CGPoint(size)/2.0
    }
    
    mutating func union(_ points: [CGPoint]) {
        for point in points {
            if point.x > self.maxX {
                self.size.width += point.x - self.maxX
            } else if point.x < self.minX {
                self.size.width += self.minX - point.x
                self.origin.x = point.x
            }
            
            if point.y > self.maxY {
                self.size.height += point.y - self.maxY
            } else if point.y < self.minY {
                self.size.height += self.minY - point.y
                self.origin.y = point.y
            }
        }
    }
}

private var setKernel: Bool = true
extension UIView {
    func HMSizeToFit(margin: Any, plus buffer: [Any]? = nil) {
        self.bounds.origin = CGPoint()//初期化
        
        let stockOrigin = self.frame.origin
        self.frame.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)//一回広げないと幅が制限される
        sizeToFit()
        if self.frame.size != CGSize() {
            setKernel = false
        }//text用
        self.frame.origin = stockOrigin
        
        func check(with thing: Any) {
            switch thing {
            case let point as CGPoint:
                if setKernel {
                    self.frame.origin.x = point.x
                    self.frame.origin.y = point.y
                    setKernel = false
                } else {
                    if point.x > self.frame.maxX {
                        self.frame.size.width += point.x - self.frame.maxX
                    } else if point.x < self.frame.minX {
                        self.frame.size.width += self.frame.minX - point.x
                        self.frame.origin.x = point.x
                    }
                    if point.y > self.frame.maxX {
                        self.frame.size.height += point.y - self.frame.maxY
                    } else if point.y < self.frame.minY {
                        self.frame.size.height += self.frame.minY - point.y
                        self.frame.origin.y = point.y
                    }
                }
            case let rect as CGRect:
                if setKernel {
                    self.frame = rect
                    setKernel = false
                } else {
                    if rect.minX < self.frame.minX {
                        self.frame.size.width += self.frame.minX - rect.minX
                        self.frame.origin.x = rect.minX
                    }
                    if rect.maxX > self.frame.maxX {
                        self.frame.size.width = rect.maxX - self.frame.minX
                    }
                    if rect.minY < self.frame.minY {
                        self.frame.size.height += self.frame.minY - self.frame.minY
                        self.frame.origin.y = rect.minY
                    }
                    if rect.maxY > self.frame.maxY {
                        self.frame.size.height = rect.maxY - self.frame.minY
                    }
                    //self.frame.union(rect)//これだとserialNumberしか含まれない
                }
            default:
                assertionFailure()
            }
        }
        
        for subview in self.subviews {
            if subview is UIImageView && self is UITextView{//なんか知らんがlayerのbourderに色をつけても一向に現れない余計なものがついてる。_UITextContainerViewが本体
                subview.removeFromSuperview()
                continue
            }
            check(with: self.convert(subview.frame, to: self.superview!))//編集後のlocateでなぜかcovertでの変化が見られない
        }
        
        if let they = self.layer.sublayers {
            for sublayer in they {
                check(with: self.layer.convert(sublayer.frame, to: self.superview!.layer))
            }
        }
        
        if let they = buffer {
            for it in they {
                check(with: it)
            }
        }
        
        switch margin {
        case let value as CGFloat:
            self.frame.size += CGSize(width: value*2.0, height: value*2.0)
            
            self.bounds.origin -= CGPoint(x: value, y: value)
        case let (right,up,left,low) as (CGFloat,CGFloat,CGFloat,CGFloat):
            self.frame.size += CGSize(width: right + left, height: up + low)
            
            self.bounds.origin -= CGPoint(x: left, y: up)
        default:
            assertionFailure()
        }
        
        setKernel = true
    }
    
    func setVisible() {
        self.layer.borderWidth = 5.0
        self.layer.borderColor = UIColor.green.cgColor
    }
}

extension CALayer {
    func setCornerRadius () {
        self.masksToBounds = true
        self.cornerRadius = min(20.0,self.frame.width/4.0,self.frame.height/4.0)
    }
}

extension CGAffineTransform {//こいつのメソッドはmutatingしないくせに@discardableResultがついてるクソ
    enum CGAffineTransformElement {
        case translatedBy(x: CGFloat, y: CGFloat)
        case translated(from: CGPoint, to: CGPoint)
        case scaledBy(x: CGFloat, y: CGFloat)
        case scaled(by: CGFloat)
        case rotated(by: CGFloat)
        //case normalized
    }
    func translated(from initialPoint: CGPoint, to terminalPoint: CGPoint) -> CGAffineTransform {
         return self.translatedBy(x: terminalPoint.x-initialPoint.x, y: terminalPoint.y-initialPoint.y)
    }
    mutating func transform(at origin: CGPoint,with elements: CGAffineTransformElement...) {//逆順で作用する
        self = self.translated(from: CGPoint(), to: origin)
        let elementsReversed = elements.reversed()
        for element in elementsReversed {
            switch element {
            case let .translatedBy(x, y):
                self = self.translatedBy(x: x, y: y)
            case let .translated(from, to):
                self = self.translated(from: from, to: to)
            case let .scaledBy(x, y):
                self = self.scaledBy(x: x, y: y)
            case let .scaled(by):
                self = self.scaledBy(x: by, y: by)
            case let .rotated(by):
                self = self.rotated(by: by)
            /*default:
                assertionFailure()*/
            }
        }
        self = self.translated(from: origin, to: CGPoint())
    }
}

import UIKit.UIGestureRecognizerSubclass
class UILongPressAndPanGestureRecognizer: UIGestureRecognizer {
    
    //UILongPressGestureRecognizerのプロパティーのパクリ
    var minimumPressDuration: CFTimeInterval = 0.5
    //var numberOfTouchesRequired: Int = 1
    var numnerOfTapsRequired: Int = 0
    var allowableMovement: CGFloat = 10
    
    //UIPanGestureRecognizerのプロパティーのパクリ
    var maximumNumberOfTouches: Int = Int.max
    var minimumNumberOfTouches: Int = 1
    private var startPoints = [UIView:CGPoint]()
    func translation(in view: UIView) -> CGPoint? {
        if let startPoint = startPoints[view] {
            return location(in: view) - startPoint
        } else {
            return nil
        }
    }
    func setTranslation(_ translation: CGPoint, in masterView: UIView) {
        startPoints.removeAll()
        let startPointOfMasterView = location(in: masterView) - translation
        startPoints[masterView] = startPointOfMasterView
        func searchSubviews(of view: UIView) {
            for subview in view.subviews{
                startPoints[subview] = masterView.convert(startPointOfMasterView, to: view)
                searchSubviews(of: subview)
            }
        }
        searchSubviews(of: masterView)
        func searchSuperview(of view: UIView) {
            if let it = view.superview {
                startPoints[it] = masterView.convert(startPointOfMasterView, to: view)
                searchSuperview(of: it)
            }
        }
        searchSuperview(of: masterView)
    }
    private var previousTime = CFAbsoluteTime()
    func velocity(in view: UIView?) -> CGPoint {//location(in:)でいける？
        var nowLocation = CGPoint()
        var previousLocation = CGPoint()
        for touch in touches {
            nowLocation += touch.location(in: view)
            previousLocation += touch.previousLocation(in: view)
        }
        return (nowLocation - previousLocation)/(CFAbsoluteTimeGetCurrent() - previousTime)
    }
    
    //オリジナル
    private var touches = Set<UITouch>()
    private var startPoint = CGPoint()
    enum SequenceOfRecognize {
        case possible,longPress, pan
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if touches.count < minimumNumberOfTouches || maximumNumberOfTouches < touches.count {
            self.state = .failed
        }
        self.state = .began
        sequenceOfRecognize = .longPress
        self.touches = touches
        previousTime = CFAbsoluteTimeGetCurrent()
    }
    
    var sequenceOfRecognize = SequenceOfRecognize.possible
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        if self.state == .failed {
            return
        }
        self.state = .changed
        switch sequenceOfRecognize {
        case .possible:
            sequenceOfRecognize = .longPress
        case .longPress:
            if CFAbsoluteTimeGetCurrent() - previousTime >= minimumPressDuration {
                startPoint = self.location(in: view!)
                sequenceOfRecognize = .pan
            } else if velocity(in: view!).length() > allowableMovement {
                self.state = .failed
                sequenceOfRecognize = .possible
            }
        case .pan:
            break
        }
        previousTime = CFAbsoluteTimeGetCurrent()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if sequenceOfRecognize == .pan && touches.count == 0 {
            self.state = .ended
            sequenceOfRecognize = .possible
        }
        previousTime = CFAbsoluteTimeGetCurrent()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.state = .cancelled
        sequenceOfRecognize = .possible
        previousTime = CFAbsoluteTimeGetCurrent()
    }
    
    override func reset() {
        super.reset()
        startPoints.removeAll()
        previousTime = CFAbsoluteTimeGetCurrent()
        self.touches.removeAll()
        startPoint = CGPoint()
    }
}

extension UILabel {
    convenience init(text: String) {
        self.init()
        self.text = text
    }
}

extension UIButton {
    convenience init(text: String) {
        self.init()
        self.setTitle(text, for: .normal)
        self.setTitle(text, for: .highlighted)
    }
}

extension UIScrollView {
    func moveContentOffset(_ translation: CGPoint, animated: Bool) {
        self.setContentOffset(self.contentOffset + translation, animated: animated)
    }
}

