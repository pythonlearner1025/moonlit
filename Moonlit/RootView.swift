//
//  RootView.swift
//  Moonlit
//
//  Created by minjune Song on 3/21/24.
//

import Auth
import SwiftUI

struct RootView: View {
  @Environment(AuthController.self) var auth

  var body: some View {
    if auth.session == nil {
      //AuthView()
        ContentView(id: UUID())
    } else {
        ContentView(id: auth.currentUserID)
    }
  }
}

