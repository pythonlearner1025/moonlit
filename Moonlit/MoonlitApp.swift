//
//  MoonlitApp.swift
//  Moonlit
//
//  Created by minjune Song on 3/13/24.
//

import SwiftUI
import Supabase

@main
struct MoonlitApp: App {
    @StateObject private var coreDataStack = LocalData.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AuthController())
                .environment(\.managedObjectContext,
                                             coreDataStack.persistentContainer.viewContext)
        }
    }
}

let supabase = SupabaseClient(
  supabaseURL: Secrets.supabaseURL,
  supabaseKey: Secrets.supabaseAnonKey,
  options: .init(global: .init(logger: ConsoleLogger()))
)

struct ConsoleLogger: SupabaseLogger {
  func log(message: SupabaseLogMessage) {
    print(message)
  }
}
