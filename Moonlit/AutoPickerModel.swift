//
//  AutoPickerModel.swift
//  Moonlit
//
//  Created by minjune Song on 3/20/24.
//


import SwiftUI

class AutoPickerModel: ObservableObject {
    @Published var presentedItems: NavigationPath = NavigationPath()
}
