//
//  PaymentCheck.swift
//  Moonlit
//
//  Created by minjune Song on 3/23/24.
//

import Foundation

extension RequestManager {
    func checkInAppPurchaseStatus(completion: @escaping (Bool) -> Void) {
    // Implement the logic to check the in-app purchase status on the device
    // You can use StoreKit or any other relevant framework to verify the purchase status
    // Call the completion handler with the result (true if purchased, false otherwise)
        completion(true)
    }

    func checkPurchaseStatusInSupabase(completion: @escaping (Bool) -> Void) {
        // Implement the logic to check if the user exists and has purchased in Supabase
        // You can use the Supabase SDK to query the database and check the user's purchase status
        // Call the completion handler with the result (true if purchased in Supabase, false otherwise)
        completion(true)
    }
}

