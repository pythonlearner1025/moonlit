//
//  PageModel.swift
//  Moonlit
//
import Foundation

struct Page: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var description: String
    var imageUrl: String
    var tag: Int
    
    static var samplePage = Page(name: "Title Example", description: "This is a sample description for the purpose of debugging", imageUrl: "work", tag: 0)
    
    static var samplePages: [Page] = [
        Page(name: "Notice about picking", description: "Pick good photos", imageUrl: "website", tag: 0),
        Page(name: "Edit your face", description: "Don't like your face? Well then edit your face with our edit-face tool!", imageUrl: "website", tag: 1),
    ]
}
