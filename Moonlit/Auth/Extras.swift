//
//  Extras.swift
//  Moonlit
//
//  Created by minjune Song on 3/21/24.
//

import Foundation

//
//  ErrorText.swift
//  Examples
//
//  Created by Guilherme Souza on 23/12/22.
//

import SwiftUI

struct ErrorText: View {
  let error: Error

  init(_ error: Error) {
    self.error = error
  }

  var body: some View {
    Text(error.localizedDescription)
      .foregroundColor(.red)
      .font(.footnote)
  }
}

struct ErrorText_Previews: PreviewProvider {
  static var previews: some View {
    ErrorText(NSError())
  }
}

// TODO fil this!
enum Constants {
  static let redirectToURL = URL(string: "io.supabase.user-management://login-callback")!
}

func debug(
  _ message: @autoclosure () -> String,
  function: String = #function,
  file: String = #file,
  line: UInt = #line
) {
  assert(
    {
      let fileHandle = FileHandle.standardError

      let logLine = "[\(function) \(file.split(separator: "/").last!):\(line)] \(message())\n"
      fileHandle.write(Data(logLine.utf8))

      return true
    }()
  )
}
