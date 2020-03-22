//
//  ClusterOfGalaxies.DataMatrix.swift
//  MassProfiler
//
//  Created by HarutakaMatsumoto on 2019/03/20.
//  Copyright © 2019 HarutakaMatsumoto. All rights reserved.
//

import Foundation
import HMFoundation
import NumericalCalculation
import Science

extension ClusterOfGalaxies {
    class DataMatrix: NumericalCalculation.DataMatrix {
        enum ElectronDensityKind: Int {
            case norm, modifiedNorm, deprojectedNorm, electronDensity
        }
        enum Style {
            case qdp, gnuplot
        }
        
        let clusterOfGalaxies: ClusterOfGalaxies
        var style: Style {
            didSet {
                renewStyle()
            }
        }
        private func renewStyle() {
            
            if style == .qdp {
                keyMatrix = Matrix(rows: [["read", "serror", "1", "2"], ["!normarization", "", "", ""], ["", "", "", ""]])
            } else {
                keyMatrix = Matrix<String>()
            }
        }
        init(of clusterOfGalaxies: ClusterOfGalaxies, in style: Style) {
            self.clusterOfGalaxies = clusterOfGalaxies
            self.style = style
            super.init()
            
            renewStyle()
        }
        
        
        // MARK: Extract Parameters
        
        private func readValue(filePath: String, model: String, parameterNumber: Int) -> (Double, Double) {
            let string: String
            
            do {
                string = try String(contentsOfFile: filePath)
            } catch {
                fatalError(error.localizedDescription)
            }
            
            
            let scanner = Scanner(string: string)
            
            var value = 0.0
            if scanner.scanUpTo("\n#Model \(model)", into: nil) {
                
                scanner.scanUpTo("\n#" + String(format: "%4d", parameterNumber), into: nil)
                scanner.scanLocation += 43
                
                precondition(scanner.scanDouble(&value))
                
                scanner.scanString("+/-  ", into: nil)
                var error = 0.0
                precondition(scanner.scanDouble(&error))
                return (value, error)
            }
            
            if scanner.scanUpTo("\n!XSPEC12> error source:\(parameterNumber)", into: nil) {
                
                scanner.scanUpTo("\n#" + String(format: "%6d", parameterNumber), into: nil)
                scanner.scanLocation += 8
                var lower = 0.0
                precondition(scanner.scanDouble(&lower))
                var upper = 0.0
                precondition(scanner.scanDouble(&upper))
                
                let error = value.calculateAverageStandardError(lower: lower, upper: upper)
                return (value, error)
            }
            
            fatalError("No.\(parameterNumber) parameter of \(model) model is not found!")
        }
        
        private func readValues(model: String, parameterNumber: Int) -> Matrix<Double> {
            
            let result = Matrix<Double>()
            
            guard let sourceLogFile = clusterOfGalaxies.sourceLogFile else {
                fatalError("The source log file property is nil!")
            }
            
            for number in sourceLogFile.range {
                let filePath = sourceLogFile.prefix + String(number) + sourceLogFile.suffix
                
                let value = readValue(filePath: filePath, model: model, parameterNumber: parameterNumber)
                
                result.rows.append(Vector([value.0, value.1]))
                
            }
            
            return result
        }
        
        func initialize(of kind: ElectronDensityKind) {
            execute(from: nil, to: kind)
        }
        
        func execute(from startOptionalKind: ElectronDensityKind?, to endKind: ElectronDensityKind) {
            
            if startOptionalKind == nil {
                extractParameters(model: "source", parameterNumber: 5)
            }
            
            let startKind = startOptionalKind ?? .norm
            
            guard startKind.rawValue < endKind.rawValue else {
                fatalError("The process go backward from \(startKind) to \(endKind)!")
            }
            
            switch startKind {
            case .norm:
                if clusterOfGalaxies.observatory != .chandra {
                    modify()
                }
                if endKind != .modifiedNorm {
                    fallthrough
                }
                
            case .modifiedNorm:
                deproject()
                if endKind != .modifiedNorm {
                    fallthrough
                }
                
            case .deprojectedNorm:
                calculateElectronDensity()
                
            case .electronDensity:
                break
            }
        }
        
        func extractParameters(model: String, parameterNumber: Int) {
            
            valueMatrix = self.readValues(model: model, parameterNumber: parameterNumber)
            
            var read = [Double]()
            var serror = [Double]()
            for index in 0..<clusterOfGalaxies.radii.count - 1 {
                read.append((clusterOfGalaxies.radii[index] + clusterOfGalaxies.radii[index + 1])/2.0)
                serror.append((clusterOfGalaxies.radii[index + 1] - clusterOfGalaxies.radii[index])/2.0)
            }
            
            valueMatrix.columns.insert(Vector(read), at: 0)
            valueMatrix.columns.insert(Vector(serror), at: 1)
        }
        
        func modify() {//specextractを使った場合は要らない
            
            for column in self.valueMatrix.columns.dropFirst(2) {
                
                for (index, scalar) in column.scalars.enumerated() {
                    
                    scalar.element /= (20.0**2.0*Double.pi)//arcmin^-2
                    scalar.element *= Double.pi*(clusterOfGalaxies.radii[index + 1]**2.0 - clusterOfGalaxies.radii[index]**2.0)
                }
            }
        }
        
        
        func deproject() {//cm^-5
            
            let volume = Matrix(repeating: 0.0, rowCount: valueMatrix.rowCount, columnCount: valueMatrix.rowCount)
            
            for N in 0..<volume.rowCount {
                func shellVolume(_ range: CountableClosedRange<Int>) -> Double {
                    return 4.0/3.0*Double.pi*(clusterOfGalaxies.radii[range.upperBound]**2.0 - clusterOfGalaxies.radii[range.lowerBound]**2.0)**1.5
                }
                func partialVolume(N: Int, m: Int) -> Double {
                    return shellVolume(m...N + 1) - shellVolume(m + 1...N + 1) - shellVolume(m...N) + shellVolume(m + 1...N)
                }
                
                volume.rows[N].scalars[N].element = shellVolume(N...N + 1)
                for m in 0..<N {
                    volume.rows[N].scalars[m].element = partialVolume(N: N, m: m)
                }
            }
            let errorOfFlux = valueMatrix.columns[3].scalars
            for m in stride(from: errorOfFlux.count - 1, through: 0, by: -1) {
                
                errorOfFlux[m].element **= 2.0
                for N in (m + 1)..<errorOfFlux.count {
                    errorOfFlux[m].element += (volume.rows[N].scalars[m].element/volume.rows[N].scalars[N].element*errorOfFlux[N].element)**2.0
                }
                errorOfFlux[m].element **= 0.5
            }
            
            func convertTo3D(_ value: Scalar<Double>, m: Int) {
                var result = clusterOfGalaxies.radii[m + 1]**3.0 - clusterOfGalaxies.radii[m]**3.0
                result /= (clusterOfGalaxies.radii[m + 1]**2.0 - clusterOfGalaxies.radii[m]**2.0)**1.5
                value.element *= result
                
            }
            
            for m in stride(from: valueMatrix.rowCount - 1, through: 0, by: -1) {
                
                let flux = valueMatrix.columns[2].scalars[m]
                for N in (m + 1)..<valueMatrix.rowCount {
                    flux.element -= volume.rows[N].scalars[m].element/volume.rows[N].scalars[N].element*valueMatrix.columns[2].scalars[N].element
                }
                
                convertTo3D(flux, m: m)
            }
        }
        
        func calculateElectronDensity() {//cm^-3
            
            for (index, row) in valueMatrix.rows.enumerated() {
                let insideDiameter = clusterOfGalaxies.radii[index]*clusterOfGalaxies.arcminToCm//cm
                let outsideDiameter = clusterOfGalaxies.radii[index + 1]*clusterOfGalaxies.arcminToCm//cm
                let D_A = clusterOfGalaxies.distance*parsecToCm//cm
                
                let volume = 4.0*Double.pi/3.0*(outsideDiameter**3.0 - insideDiameter**3.0)//cm^3
                
                let norm = row.scalars[2].element//cm^-5
                let err_norm = row.scalars[3].element//cm^-3
                
                row.scalars[2].element = 1.0e7*4.0*D_A*(1.0 + clusterOfGalaxies.z)//cm
                row.scalars[2].element *= sqrt(3.0*Double.pi/10.0/volume*norm)//cm^-3
                
                row.scalars[3].element = 1.0/2.0*err_norm/norm*row.scalars[2].element//cm^-3
                
            }
            
        }
        
        func initializeOfDescreteTemperature() {//keV
            extractParameters(model: "source", parameterNumber: 2)//keV
        }
        
        func initializeOfGasMass() {
            
            func f(arcmin: Double) -> Double {//solarmass /arcmin
                return 4.0*Double.pi*arcmin**2.0*1.95e-27/*kg/1*/ * clusterOfGalaxies.electronDensity(arcmin)/Measurement<UnitMass>.sun.value
            }
            
            func errorF(arcmin: Double) -> Double {//solarmass /arcmin
                return 4.0*Double.pi*arcmin**2.0*1.95e-27/*kg/1*/ * clusterOfGalaxies.electronDensityError(arcmin)/Measurement<UnitMass>.sun.value
            }
            
            let F = indefiniteIntegrate(withInitialCondition: Point(x: clusterOfGalaxies.radii.first!, y: 0.0), dx: (clusterOfGalaxies.radii.last! - clusterOfGalaxies.radii.first!)/Double(clusterOfGalaxies.calculationNumber), function: f)//solarmass
            
            let ErrorF = indefiniteIntegrate(withInitialCondition: Point(x: clusterOfGalaxies.radii.first!, y: 0.0), dx: (clusterOfGalaxies.radii.last! - clusterOfGalaxies.radii.first!)/Double(clusterOfGalaxies.calculationNumber), function: errorF)//solarmass
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, { _ in 0 }, F, ErrorF)
            
        }
        
        func initializeOfGravitationalMass() {
            
            func f2(arcmin: Double) -> Double {//arcmin^-3 K
                return clusterOfGalaxies.electronDensity(arcmin)*clusterOfGalaxies.temperature(arcmin)
            }
            
            let df2 = differentiate(ofEffectiveRange: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber + 1, function: f2)//arcmin^-4 K
            
            let dElectronDensity = differentiate(ofEffectiveRange: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber + 1, function: clusterOfGalaxies.electronDensity)
            
            let dTemperature = differentiate(ofEffectiveRange: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber + 1, function: clusterOfGalaxies.temperature)
            
            let ddElectronDensity = differentiate(ofEffectiveRange: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber + 1, function: dElectronDensity)
            
            let ddTemperature = differentiate(ofEffectiveRange: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber + 1, function: dTemperature)
            
            func f(arcmin: Double) -> Double {
                let first = -PhysicalConstant.k_B/(PhysicalConstant.mu*Measurement<UnitMass>.proton.value*PhysicalConstant.G)*clusterOfGalaxies.arcminToM//kg /K /arcmin
                let second = (arcmin)**2.0/clusterOfGalaxies.electronDensity(arcmin)//arcmin^5
                let third = df2(arcmin)//K /arcmin^4
                
                return first*second*third/Measurement<UnitMass>.sun.value//solarmass
            }
            
            func errorF(arcmin: Double) -> Double {
                let v1 = clusterOfGalaxies.electronDensity(arcmin)//arcmin^-3
                let d1 = dElectronDensity(arcmin)//arcmin^-4
                let dd1 = ddElectronDensity(arcmin)//arcmin^-5
                let e1 = clusterOfGalaxies.electronDensityError(arcmin)//arcmin^-3
                let v2 = clusterOfGalaxies.temperature(arcmin)//K
                let d2 = dTemperature(arcmin)//K arcmin^-1
                let dd2 = ddTemperature(arcmin)//K arcmin^-2
                let e2 = clusterOfGalaxies.temperatureError(arcmin)//K
                let r = arcmin//arcmin
                
                let initial = PhysicalConstant.k_B/(PhysicalConstant.mu*Measurement<UnitMass>.proton.value*PhysicalConstant.G)*clusterOfGalaxies.arcminToM*r//kg /K
                let part1 = r*v2/v1*(-d1/v1 + dd1/d1) + 2.0*(v2/v1 + d2/d1)//K arcmin^3
                let part2 = r*(d1/v1 + dd2/d2)//1
                
                let value = initial*sqrt((part1*e1)**2.0 + (part2*e2)**2.0)/Measurement<UnitMass>.sun.value//solarmass
                
                return value
            }
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber + 1, functions: { $0 }, { _ in (self.clusterOfGalaxies.radii.last! - self.clusterOfGalaxies.radii.first!)/Double((self.clusterOfGalaxies.calculationNumber + 1)/5) }, f, errorF)//多めにやってる
            
        }
        
        func dencitialize() {//誤差伝播について，自己同一性を加味して引いてる
            
            valueMatrix.rows.removeLast()
            
            let columns = valueMatrix.columns
            for index in 0..<valueMatrix.rowCount - 1 {//データ数が１少なくなる
                func sphereVolume(arcmin: Double) -> Double/*Mpc^3 */ {
                    return 4.0/3.0*Double.pi*(arcmin*clusterOfGalaxies.arcminToMpc)**3.0
                }
                
                let volume = sphereVolume(arcmin: columns[0].scalars[index + 1].element) - sphereVolume(arcmin: columns[0].scalars[index].element)
                
                columns[2].scalars[index].element = (columns[2].scalars[index + 1].element - columns[2].scalars[index].element)/volume/*Mpc^-3 solarmass*/
                
                columns[3].scalars[index].element = (columns[3].scalars[index + 1].element - columns[3].scalars[index].element)/volume/*Mpc^-3 solarmass*/
                
            }
            
        }
        
        func initializeOfGravitationalMassDensity() {
            initializeOfGravitationalMass()
            dencitialize()
            thinOut(per: 10)
        }
        
        
        func initializeOfGasMassDensity() {
            
            func f(arcmin: Double) -> Double {//solarmass /Mpc^3
                return 1.95e-27 * clusterOfGalaxies.electronDensity(arcmin)/(Measurement<UnitMass>.sun.value*clusterOfGalaxies.arcminToMpc**3.0)
            }
            
            func errorF(arcmin: Double) -> Double {//solarmass /Mpc^3
                return 1.95e-27 * clusterOfGalaxies.electronDensityError(arcmin)/(Measurement<UnitMass>.sun.value*clusterOfGalaxies.arcminToMpc**3.0)
            }
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, { _ in 0 }, f, errorF)
            
        }
        
        func initializeOfDarkMatterDensity() {
            let gravitationalMassDensity = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
            gravitationalMassDensity.initializeOfGravitationalMassDensity()
            let gasMassDensity = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
            gasMassDensity.initializeOfGasMassDensity()
            
            self.valueMatrix = (gravitationalMassDensity - gasMassDensity).valueMatrix
        }
        
        func convert(x: Double? = nil, y: Double? = nil) {
            let converters = [x, x, y, y]
            for (index, converter) in converters.enumerated() {
                if let it = converter {
                    for scalar in valueMatrix.columns[index].scalars {
                        scalar.element *= it
                    }
                }
            }
        }
        
        func initializeOfKpc_DarkMatterDensity() {//W-VAR=  Infinityが出ていずれもフィッティングできない
            initializeOfDarkMatterDensity()
            
            convert(x: clusterOfGalaxies.arcminToKpc, y: Measurement<UnitMass>.sun.value/mpcToM**3.0)
            
        }
        
        func initializeOfPressure() {
            
            func f(arcmin: Double) -> Double {//Pa
                return clusterOfGalaxies.pressure(arcmin)
            }
            
            func errorF(arcmin: Double) -> Double {//Pa
                let value = clusterOfGalaxies.pressure(arcmin)
                let v1 = clusterOfGalaxies.electronDensity(arcmin)
                let e1 = clusterOfGalaxies.electronDensityError(arcmin)
                let v2 = clusterOfGalaxies.temperature(arcmin)
                let e2 = clusterOfGalaxies.temperatureError(arcmin)
                
                return value*sqrt((e1/v1)**2.0 + (e2/v2)**2.0)
            }
            
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, { _ in 0 }, f, errorF)
            
        }
        
        
        func initializeOfCompression() {
            
            let gravitationalMassDensity = self.copy() as! ClusterOfGalaxies.DataMatrix
            gravitationalMassDensity.initializeOfGravitationalMassDensity()
            let gasMassDensity = self.copy() as! ClusterOfGalaxies.DataMatrix
            gasMassDensity.initializeOfGasMassDensity()
            
            let compression = gravitationalMassDensity/gasMassDensity
            
            self.valueMatrix = compression.valueMatrix
        }
        
        
        func initializeOfTemperature() {
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, { _ in 0 }, clusterOfGalaxies.temperature, clusterOfGalaxies.temperatureError)//K
            
        }
        
        func initializeOfReducedGravitaionalMass() {
            
            func f2(arcmin: Double) -> Double {//arcmin^-3 K
                return clusterOfGalaxies.electronDensity(arcmin)*clusterOfGalaxies.temperature(arcmin)/clusterOfGalaxies.compressionFunction(clusterOfGalaxies.pressure(arcmin))
            }
            
            let df2 = differentiate(ofEffectiveRange: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber, function: f2)//arcmin^-4 K
            
            func f(arcmin: Double) -> Double {
                let first = -PhysicalConstant.k_B/(PhysicalConstant.mu*Measurement<UnitMass>.proton.value*PhysicalConstant.G)*clusterOfGalaxies.arcminToM//kg /K /arcmin
                let second = (arcmin)**2.0/clusterOfGalaxies.electronDensity(arcmin)//arcmin^5
                let third = df2(arcmin)//K /arcmin^4
                
                return first*second*third/Measurement<UnitMass>.sun.value//solarmass
            }
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber, functions: { $0 }, f)
            
        }
        
        func initializeOfCompressionFunction() {
            valueMatrix = Matrix<Double>.plot(between: 8...50, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, clusterOfGalaxies.compressionFunction)
            
        }
        
        func initializeOfGravitationalMassUsedTOV() {
            
            func kneT(arcmin: Double) -> Double {//arcmin^-3 J
                return PhysicalConstant.k_B*clusterOfGalaxies.electronDensity(arcmin)*clusterOfGalaxies.temperature(arcmin)
            }
            
            let dkneT = differentiate(ofEffectiveRange: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber + 1, function: kneT)//arcmin^-4 J
            
            func f(arcmin: Double) -> Double {
                let knT = kneT(arcmin: arcmin)//arcmin^-3 J
                var x = PhysicalConstant.mu*Measurement<UnitMass>.proton.value*PhysicalConstant.c**2.0*clusterOfGalaxies.electronDensity(arcmin) + knT//arcmin^-3 J
                x /= dkneT(arcmin)//arcmin
                let first = PhysicalConstant.c**2.0*arcmin/(2.0*PhysicalConstant.G)*clusterOfGalaxies.arcminToM//kg
                var second = 7.0*Double.pi*arcmin**2.0*knT*x//J
                second /= 3.0*PhysicalConstant.mu*PhysicalConstant.c**2.0//kg
                let denominator = 1 - x/(2.0*arcmin)
                
                return (first + second)/denominator/Measurement<UnitMass>.sun.value//solarmass
            }
            
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, { _ in 0 }, f, { _ in 0 })
            
        }
        
        func initializeOfEntropy() {
            
            func f(arcmin: Double) -> Double {//J K^-1
                return clusterOfGalaxies.entropy(arcmin)
            }
            
            func errorF(arcmin: Double) -> Double {// 上田先輩の古いやつ
                let v1 = clusterOfGalaxies.electronDensity(arcmin)
                let v2 = clusterOfGalaxies.temperature(arcmin)
                
                let part1 = PhysicalConstant.k_B*log((PhysicalConstant.k_B*v2)**(1.5)/v1) + 1.5
                let part2 = -PhysicalConstant.k_B*v2/v1
                return sqrt((part1*v1)**2.0 + (part2*v2)**2.0)
            }
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, f)//J K^-1
            
        }
        
        func initializeOfInternalEnergyDensity() {// TODO: 誤差伝播計算
            
            let dS = indefiniteIntegrate(withInitialCondition: Point(x: clusterOfGalaxies.radii.first!, y: 0.0), dx: (clusterOfGalaxies.radii.last! - clusterOfGalaxies.radii.first!)/Double(clusterOfGalaxies.calculationNumber), function: { self.clusterOfGalaxies.entropy($0) })//J K^-1 /arcmin
            
            func f(arcmin: Double) -> Double {// J m^-3
                
                let area = 4.0*Double.pi*(arcmin*clusterOfGalaxies.arcminToM)**2.0
                let first = clusterOfGalaxies.temperature(arcmin)*dS(arcmin)/clusterOfGalaxies.arcminToM/area//J m^-3
                let second = -clusterOfGalaxies.pressure(arcmin)//Pa
                let third = clusterOfGalaxies.chemicalPotential(arcmin)*7.0*clusterOfGalaxies.electronDensity(arcmin)/clusterOfGalaxies.arcminToM**3.0/(6.0*PhysicalConstant.mu)//Pa 有意
                
                return -(first + second + third)//無限遠基準
            }
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, { _ in 0 }, f, { _ in 0 })//J m^-3
            
        }
        
        func initializeOfGasNumberDensity() {
            
            func f(arcmin: Double) -> Double {
                return 7.0*clusterOfGalaxies.electronDensity(arcmin)/(clusterOfGalaxies.arcminToM**3.0*6.0*PhysicalConstant.mu)//m^-3
            }
            
            func errorF(arcmin: Double) -> Double {
                return 7.0*clusterOfGalaxies.electronDensityError(arcmin)/(clusterOfGalaxies.arcminToM**3.0*6.0*PhysicalConstant.mu)//m^-3
            }
            
            valueMatrix = Matrix<Double>.plot(between: clusterOfGalaxies.radii.first!...clusterOfGalaxies.radii.last!, by: clusterOfGalaxies.calculationNumber/10, functions: { $0 }, { _ in 0 }, f, errorF)//m^-3
            
        }
        
        func initializeOfTest() {
            
            let grav = self.copy() as! ClusterOfGalaxies.DataMatrix
            grav.initializeOfGravitationalMassDensity()
            let n = self.copy() as! ClusterOfGalaxies.DataMatrix
            n.initializeOfGasNumberDensity()
            
            let y = grav / n
            
            self.valueMatrix = y.valueMatrix
        }
    }
}


extension ClusterOfGalaxies.DataMatrix {
    static func /(left: ClusterOfGalaxies.DataMatrix, right: ClusterOfGalaxies.DataMatrix) -> ClusterOfGalaxies.DataMatrix {
        let result = ClusterOfGalaxies.DataMatrix(of: left.clusterOfGalaxies, in: left.style)
        result.keyMatrix = left.keyMatrix.copy() as! Matrix<String>
        result.valueMatrix.columns.append(left.valueMatrix.columns[0])
        result.valueMatrix.columns.append(left.valueMatrix.columns[1])
        result.valueMatrix.columns.append(Vector(zip(left.valueMatrix.columns[2].scalars, right.valueMatrix.columns[2].scalars).map{ $0.0.element/$0.1.element }))
        
        for index in 0..<result.valueMatrix.rows.count {//簡易エラー計算
            let v1 = left.valueMatrix.rows[index].scalars[2].element
            let e1 = left.valueMatrix.rows[index].scalars[3].element
            let v2 = right.valueMatrix.rows[index].scalars[2].element
            let e2 = right.valueMatrix.rows[index].scalars[3].element
            let value = result.valueMatrix.rows[index].scalars[2].element
            result.valueMatrix.rows[index].scalars.append(Scalar(value*sqrt((e1/v1)**2.0 + (e2/v2)**2.0)))
        }
        
        return result
    }
    
    static func -(left: ClusterOfGalaxies.DataMatrix, right: ClusterOfGalaxies.DataMatrix) -> ClusterOfGalaxies.DataMatrix {
        let result = ClusterOfGalaxies.DataMatrix(of: left.clusterOfGalaxies, in: left.style)
        result.keyMatrix = left.keyMatrix.copy() as! Matrix<String>
        result.valueMatrix.columns.append(left.valueMatrix.columns[0])
        result.valueMatrix.columns.append(left.valueMatrix.columns[1])
        result.valueMatrix.columns.append(Vector(zip(left.valueMatrix.columns[2].scalars, right.valueMatrix.columns[2].scalars).map{ $0.0.element-$0.1.element }))
        
        for index in 0..<result.valueMatrix.rows.count {//簡易エラー計算
            let e1 = left.valueMatrix.rows[index].scalars[3].element
            let e2 = right.valueMatrix.rows[index].scalars[3].element
            result.valueMatrix.rows[index].scalars.append(Scalar(sqrt(e1**2.0 + e2**2.0)))
        }
        
        return result
    }
    
    func thinOut(per n: Int) {
        
        let result = Matrix<Double>()
        for i in 0..<self.valueMatrix.rows.count/n {
            result.rows.append(self.valueMatrix.rows[i*n])
        }
        
        self.valueMatrix = result
    }
    
    func linerizedSerror() -> [ClusterOfGalaxies.DataMatrix] {
        
        let mean = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
        
        mean.keyMatrix.columns.append(self.keyMatrix.columns[0].copy() as! Vector<String>)
        mean.keyMatrix.columns.append(self.keyMatrix.columns[2].copy() as! Vector<String>)
        
        mean.valueMatrix.columns.append(self.valueMatrix.columns[0].copy() as! Vector<Double>)
        mean.valueMatrix.columns.append(self.valueMatrix.columns[2].copy() as! Vector<Double>)
        
        let lower = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
        let upper = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
        
        lower.keyMatrix = mean.keyMatrix.copy() as! Matrix<String>
        upper.keyMatrix = mean.keyMatrix.copy() as! Matrix<String>
        
        let lowerVector = Vector<Double>()
        let upperVector = Vector<Double>()
        
        for row in self.valueMatrix.rows {
            lowerVector.scalars.append(Scalar((row.scalars[0].element - row.scalars[1].element)))
            upperVector.scalars.append(Scalar((row.scalars[0].element + row.scalars[1].element)))
        }
        lower.valueMatrix.columns.append(lowerVector)
        upper.valueMatrix.columns.append(upperVector)
        
        lower.valueMatrix.columns.append(mean.valueMatrix.columns[1].copy() as! Vector<Double>)
        upper.valueMatrix.columns.append(mean.valueMatrix.columns[1].copy() as! Vector<Double>)
        
        return [mean, lower, upper]
    }
    
    func linerizedYerror() -> [ClusterOfGalaxies.DataMatrix] {
        
        let mean = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
        
        mean.keyMatrix.columns.append(self.keyMatrix.columns[0].copy() as! Vector<String>)
        mean.keyMatrix.columns.append(self.keyMatrix.columns[2].copy() as! Vector<String>)
        
        mean.valueMatrix.columns.append(self.valueMatrix.columns[0].copy() as! Vector<Double>)
        mean.valueMatrix.columns.append(self.valueMatrix.columns[2].copy() as! Vector<Double>)
        
        let lower = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
        let upper = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
        
        lower.keyMatrix = mean.keyMatrix.copy() as! Matrix<String>
        upper.keyMatrix = mean.keyMatrix.copy() as! Matrix<String>
        
        lower.valueMatrix.columns.append(mean.valueMatrix.columns[0].copy() as! Vector<Double>)
        upper.valueMatrix.columns.append(mean.valueMatrix.columns[0].copy() as! Vector<Double>)
        
        let lowerVector = Vector<Double>()
        let upperVector = Vector<Double>()
        
        for row in self.valueMatrix.rows {
            lowerVector.scalars.append(Scalar((row.scalars[2].element - row.scalars[3].element)))
            upperVector.scalars.append(Scalar((row.scalars[2].element + row.scalars[3].element)))
        }
        
        lower.valueMatrix.columns.append(lowerVector)
        upper.valueMatrix.columns.append(upperVector)
        
        return [mean, lower, upper]
    }
    
    /*
     func separateError() -> (value: DataMatrix, upperError: DataMatrix, lowerError: DataMatrix) {
     let value = self.copy() as! DataMatrix
     value.keyMatrix.columns.removeLast()
     value.valueMatrix.columns.removeLast()
     
     let upperError = value.copy() as! DataMatrix
     upperError.valueMatrix.columns[2] = Vector(zip(self.valueMatrix.columns[2], self.valueMatrix))
     }*/
    
    override func copy() -> Any {
        let result = ClusterOfGalaxies.DataMatrix(of: clusterOfGalaxies, in: style)
        
        result.keyMatrix = self.keyMatrix.copy() as! Matrix<String>
        result.valueMatrix = self.valueMatrix.copy() as! Matrix<Double>
        
        return result
    }
}
