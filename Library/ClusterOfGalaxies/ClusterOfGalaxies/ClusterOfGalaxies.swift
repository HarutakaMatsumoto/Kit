//
//  ClusterOfGalaxies.swift
//  MassProfiler
//
//  Created by HarutakaMatsumoto on 2019/02/02.
//  Copyright © 2019 HarutakaMatsumoto. All rights reserved.
//

import Foundation
import HMFoundation
import NumericalCalculation
import Science

let lightYearToParsec = Measurement(value: 1.0, unit: UnitLength.lightyears).converted(to: .parsecs).value

let arcminToRadian = Measurement(value: 1.0, unit: UnitAngle.arcMinutes).converted(to: .radians).value

let parsecToCm = Measurement(value: 1.0, unit: UnitLength.parsecs).converted(to: .centimeters).value

let parsecToM = Measurement(value: 1.0, unit: UnitLength.parsecs).converted(to: .meters).value

let mpcToM = Measurement(value: 1.0e6, unit: UnitLength.parsecs).converted(to: .meters).value

let keVToKelvin = Measurement<UnitElectricCharge>.electron.value*1.0e3/PhysicalConstant.k_B

extension String {
    func save(path: String) {
        do {
            try self.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        } catch {
            print(error)
        }
    }
}

extension Double {
    func calculateAverageStandardError(lower: Double, upper: Double) -> Double {
        return (upper - self - (lower - self))/2.0
    }
}

class ClusterOfGalaxies: NSObject {//TODO: PhysicalQuantity実装　誤差伝播偏微分化 DataMatrixのサブクラス化 行列の列ごと処理化
    
    enum Observatory {
        case suzaku, chandra
    }
    
    
    static var multiple = 1
    
    static var list = [ClusterOfGalaxies]()
    
    // MARK: Properties
    let z: Double
    let distance: Double//parsec
    let observatory: Observatory
    
    var radii: [Double]!//arcmin
    
    
    var sourceLogFile: (prefix: String, range: ClosedRange<Int>, suffix: String)!
    
    var electronDensity: ((_ arcmin: Double) -> Double)!//arcmin^-3//valueとerrorを分ける！
    
    var electronDensityError: ((_ arcmin: Double) -> Double)!//arcmin^-3 本来は中まで偏微分
    
    var temperature: ((_ arcmin: Double) -> Double)!//K
    
    var temperatureError: ((_ arcmin: Double) -> Double)!//K 本来は中まで偏微分
    
    var compressionFunction: ((_ arcmin: Double) -> Double)!//エラー入れる？
    
    var pressure: (_ arcmin: Double) -> Double {//Pa
        return { arcmin in
            return 7.0/6.0*self.electronDensity(arcmin)/PhysicalConstant.mu*PhysicalConstant.k_B*self.temperature(arcmin)/self.arcminToM**3.0
        }
    }
    
    var entropy: (_ arcmin: Double) -> Double {/*//e100 Jhttp://10.33.24.6/thesis/2017/ueda.pdf 単位おかしい
        let s_0 = 0.0
        return { arcmin in
            let v1 = self.electronDensity(arcmin)/self.arcminToM
            let v2 = self.temperature(arcmin)
            let k = PhysicalConstant.k_B
            
            return k*log((k*v1)**(3.0/2.0)/v1) + s_0
        }*/
        
        let s_0 = 0.0//J/K 統計力学 p.59 宇宙平均分子の単一成分のミクロカノニカルn分布を考える
        return { arcmin in
            let n = 7.0*self.electronDensity(arcmin)/(self.arcminToM**3.0*6.0*PhysicalConstant.mu)//m^-3
            let T = self.temperature(arcmin)//K
            let k = PhysicalConstant.k_B//J K^-1
            let m = PhysicalConstant.mu*Measurement<UnitMass>.proton.value//kg
            let h = PhysicalConstant.h//J s
            let N = self.number(arcmin)
            
            return k*N*(5.0/2.0+log((2.0*Double.pi*m*k*T/h**2.0)**(3.0/2.0)/n)) + s_0
        }
    }
    
    var number: (_ arcmin: Double) -> Double {//1 サードステップ
        return { arcmin in
            let v1 = self.electronDensity(arcmin)/self.arcminToM**3.0//m^-3
            
            return 14.0*v1*Double.pi*(arcmin*self.arcminToM)**3.0/(9.0*PhysicalConstant.mu)
        }
    }
    
    var chemicalPotential: (_ arcmin: Double) -> Double {//J or J K 統計力学テキストp.60
        return { arcmin in
            let v2 = self.temperature(arcmin)//K
            
            let value = -v2*(self.entropy(arcmin)/self.number(arcmin) + 5.0*PhysicalConstant.k_B/2.0)
            
            return value
        }
    }
    
    var arcminToCm: Double {
        return arcminToRadian*distance*parsecToCm
    }
    
    var arcminToM: Double {
        return arcminToCm*1.0e-2
    }
    
    var arcminToMpc: Double {
        return arcminToRadian*distance*1.0e-6
    }
    
    var arcminToKpc: Double {
        return arcminToRadian*distance*1.0e-3
    }
    
    let calculationNumber: UInt = 10000//計算の際の分割数
    
    // MARK: Initilezer
    
    init(z: Double, distance: Double, observatory: Observatory) {
        self.z = z
        self.distance = distance
        self.observatory = observatory
        
        super.init()
    }
    
    
    func calculateR(_ multiple: Double, data: ClusterOfGalaxies.DataMatrix) -> Double? {
        
        var totalMassDensity = 0.0
        let criterion = multiple*PhysicalConstant.rho_critical
        let compairOperator: (Double, Double) -> Bool
        if data.valueMatrix.rows[0].scalars[2].element > multiple*PhysicalConstant.rho_critical {
            compairOperator = { $0 <= $1 }
        } else {
            compairOperator = { $0 >= $1 }
        }
        for (index, row) in data.valueMatrix.rows.enumerated() {
            totalMassDensity += row.scalars[2].element
            
            if compairOperator(totalMassDensity/Double(index + 1), criterion) {
                return row.scalars[0].element
            }
        }
        
        return nil
    }
    
}

