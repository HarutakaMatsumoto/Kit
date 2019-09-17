//
//  Mesurement.swift
//  Science
//
//  Created by HarutakaMatsumoto on 2019/02/02.
//  Copyright © 2019 松本青空. All rights reserved.
//
//  出展: 2018理科年表
//

import Foundation
import HMFoundation

public extension Measurement where UnitType == UnitMass {
    static let sun = Measurement(value: 1.988e30, unit: UnitMass.kilograms)
    
    static let proton = Measurement(value: 1.672621898e-27, unit: UnitMass.kilograms)
    
}

public extension Measurement where UnitType == UnitElectricCharge {
    static let electron = Measurement(value: 1.6021766208e-19, unit: UnitElectricCharge.coulombs)
    
}

public extension UnitEnergy {
    class var kiloeElectronVolts: UnitEnergy {
        let converter = UnitConverterLinear(coefficient: 1.0/(Measurement<UnitElectricCharge>.electron.value*1.0e3))
        
        return UnitEnergy.init(symbol: "keV", converter: converter)
        
    }
    
    class var kelvin: UnitEnergy {
        let converter = UnitConverterLinear(coefficient: 1.0/PhysicalConstant.k_B)
        
        return UnitEnergy.init(symbol: "keV", converter: converter)
        
    }
}

public extension Measurement {
    static func *(angle: Measurement<UnitAngle>, radius: Measurement<UnitLength>) -> Measurement<UnitLength> {
        return angle.converted(to: .radians).value*radius
    }
}

public class PhysicalConstant {
    public static let G = 6.67408e-11//N m^2 kg^-2 = J m kg^-2
    public static let mu = 0.61//要出典，独自算出では14/11
    public static let k_B = 1.38064852e-23//J K^-1
    public static let h = 6.626_070_040e-34//J s
    public static let H = 67.74 //km /s /Mpc Planck2015
    public static let omega_lambda = 0.3089 // Planck2015
    public static let c = 2.997_924_58e8 //m /s
    public static let rho_critical = 3.0*(PhysicalConstant.H*Measurement(value: 1.0, unit: UnitLength.kilometers).converted(to: .parsecs).value*1.0e-6)**2.0/(8.0*Double.pi*PhysicalConstant.G)//kg /m^3
}

/*
class UnitNone: Unit {
    private override init(symbol: String) {
        super.init(symbol: symbol)
    }
    
    convenience init(workaround _: Void = ()) {
        self.init(symbol: "")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DerivedUnit: Dimension {//Playgroundにて編纂中
    var numeratorUnits: [Dimension]
    var denominatorUnits: [Dimension]
    
    init(numerator: [Dimension], denominator: [Dimension]) {
        numeratorUnits = numerator
        denominatorUnits = denominator
        let unitConverter = UnitConverter()
        super.init(symbol: "", converter: unitConverter)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var symbol: String {
        let numeratorSymbol = numeratorUnits.map { $0.symbol }.joined(separator: " ")
        let denominatorSymbol = denominatorUnits.map { $0.symbol }.joined(separator: " ")
        return numeratorSymbol + "/" + denominatorSymbol
    }
    
    override var converter: UnitConverter {
        
    }
}*/

/*
class UnitForce: DerivedUnit {
    static let newton = DerivedUnit(numerator: [UnitMass.kilograms, UnitAcceleration.metersPerSecondSquared], denominator: [])
}

class PhysicalConstant {
    static let gravitational = Measurement(value: 6.67408e-11, unit: DerivedUnit(numerator: [UnitForce.newton, UnitLength.meters, UnitLength.meters], denominator: [UnitMass.kilograms, UnitMass.kilograms]))
    static let boltzmann = Measurement(value: 1.38064852e-23, unit: DerivedUnit(numerator: [UnitEnergy.joules], denominator: [UnitTemperature.kelvin]))
}


extension Measurement where UnitType == UnitArea {/*
     func convertedToBaseUnit() -> Measurement {
     let dimension = self.unit.self as! Dimension
     return self.converted(to: dimension.baseUnit())
     }*/
    /*
     static func * (lhs: Measurement<UnitLength>, rhs: Measurement<UnitAngle>) -> Measurement<UnitLength> {
     let lengthByM = lhs.converted(to: UnitLength.baseUnit()).value * rhs.converted(to: UnitAngle.baseUnit()).value
     return Measurement(value: lengthByM, unit: lhs.unit as! UnitType) as! Measurement<UnitLength>
     }
     static func * (lhs: Measurement<UnitAngle>, rhs: Measurement<UnitLength>) -> Measurement<UnitLength> {
     return rhs * lhs
     }*/
    
    static func * (lhs: Measurement<UnitLength>, rhs: Measurement<UnitLength>) -> Measurement<UnitArea> {
        let areaByM2 = lhs.converted(to: UnitLength.baseUnit()).value * rhs.converted(to: UnitLength.baseUnit()).value
        let area = Measurement(value: areaByM2, unit: UnitArea.squareMeters)
        return area
    }
}

extension Measurement {
    static func *(lhs: Measurement<UnitNone>, rhs: Measurement<UnitType>) -> Measurement<UnitType> {
        let value = lhs.value * rhs.value
        return Measurement(value: value, unit: rhs.unit)
    }
}

 */
