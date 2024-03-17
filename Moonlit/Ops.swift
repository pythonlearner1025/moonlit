//
//  Ops.swift
//  Moonlit
//
//  Created by minjune Song on 3/17/24.
//

import Foundation
import CoreML

extension FaceDetectionGalleryView {
    func mat_mul(_ a: MLMultiArray, _ b: MLMultiArray) -> MLMultiArray {
        guard a.count == b.count else {
            fatalError("Matrices must have the same dimensions for element-wise multiplication")
        }
        
        let result = try! MLMultiArray(shape: a.shape, dataType: a.dataType)
        for i in 0..<a.count {
            result[i] = NSNumber(floatLiteral: Double(a[i].floatValue * b[i].floatValue))
        }
        
        return result
    }
    
    func mat_add(_ a: MLMultiArray, _ b: MLMultiArray) -> MLMultiArray {
        guard a.count == b.count else {
            fatalError("Matrices must have the same dimensions for element-wise addition")
        }
        
        let result = try! MLMultiArray(shape: a.shape, dataType: a.dataType)
        for i in 0..<a.count {
            result[i] = NSNumber(floatLiteral: Double(a[i].floatValue + b[i].floatValue))
        }
        
        return result
    }
    
    func mat_sub(_ a: MLMultiArray, _ b: MLMultiArray) -> MLMultiArray {
        guard a.count == b.count else {
            fatalError("Matrices must have the same dimensions for element-wise subtraction")
        }
        
        let result = try! MLMultiArray(shape: a.shape, dataType: a.dataType)
        for i in 0..<a.count {
            result[i] = NSNumber(floatLiteral: Double(a[i].floatValue - b[i].floatValue))
        }
        
        return result
    }
    
    func mat_sum(_ a: MLMultiArray) -> Float {
        var sum: Float = 0.0
        for i in 0..<a.count {
            sum += a[i].floatValue
        }
        return sum
    }
}
