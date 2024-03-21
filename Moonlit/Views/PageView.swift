//
//  File.swift
//  Moonlit
//
//  Created by minjune Song on 3/20/24.
//

import Foundation
//
//  PageView.swift
//  SlidingIntroScreen
//
//  Created by Federico on 18/03/2022.
//

import SwiftUI

struct PageView: View {
    var page: Page
    
    var body: some View {
        VStack(spacing: 10) {
            Image("\(page.imageUrl)")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .background(.gray.opacity(0.10))
                .cornerRadius(10)
                .padding()
            
            Text(page.name)
                .font(.title)
            Text(page.description)
                .font(.subheadline)
                .frame(width: 300)
        }
    }
}

