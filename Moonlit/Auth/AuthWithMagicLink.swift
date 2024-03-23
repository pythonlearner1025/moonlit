//
//  AuthWithMagicLink.swift
//  Examples
//
//  Created by Guilherme Souza on 15/12/23.
//

import SwiftUI
import Supabase
import PhoneNumberKit

struct AuthWithMagicLink: View {
  @State var num = ""
  @State var actionState: ActionState<Void, Error> = .idle
    
  //let phoneNumberKit = PhoneNumberKit()
    
  var body: some View {
    Form {
      Section {
        TextField("Email", text: $num)
              .keyboardType(.emailAddress)
              .textContentType(.emailAddress)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)
      }

      Section {
        Button("Sign in with magic link") {
          Task {
            await signInWithMagicLinkTapped()
          }
        }
      }

      switch actionState {
      case .idle, .result(.success):
        EmptyView()
      case .inFlight:
        ProgressView()
      case let .result(.failure(error)):
        ErrorText(error)
      }
    }
    .onOpenURL { url in
      Task { await onOpenURL(url) }
    }
  }

  private func signInWithMagicLinkTapped() async {
    actionState = .inFlight

    actionState = await .result(
      Result {
          /*
          let phoneNumber = try phoneNumberKit.parse(num)
          print("NUMBA:")
          print("+\(phoneNumber.countryCode)\(phoneNumber.nationalNumber)")
          try await supabase.auth.signInWithOTP(phone: "+\(phoneNumber.countryCode)\(phoneNumber.nationalNumber)")
          */
            try await supabase.auth.signInWithOTP(
              email: num,
              redirectTo: Constants.redirectToURL
            )
      }
    )
  }

  private func onOpenURL(_ url: URL) async {
    debug("received url: \(url)")

    actionState = .inFlight
    actionState = await .result(
      Result {
        try await supabase.auth.session(from: url)
      }
    )
  }
}

