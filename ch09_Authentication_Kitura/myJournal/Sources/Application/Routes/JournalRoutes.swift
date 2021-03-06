//
//  JournalRoutes.swift
//  Application
//
//  Created by Angus yeung on 7/16/18.
//

import Foundation
import Kitura
import KituraStencil
import SwiftKueryORM
import SwiftKueryPostgreSQL
import LoggerAPI
import Credentials
import CredentialsHTTP

func initializeJournalRoutes(app: App) {
  
    let mainPage = "/journal/all"
    
    let title = "My Journal"
    let author = "Angus"

    let poolOptions = ConnectionPoolOptions(initialCapacity: 1,
                                                maxCapacity: 5,
                                                timeout: 10000)
        
    // Set up database connection
    let psqlPool = PostgreSQLConnection.createPool(host: "localhost",
                                               port: 5432,
                                               options: [.databaseName("journalbook")],
                                               poolOptions: poolOptions)
    Database.default = Database(psqlPool)

    do {
        try JournalItem.createTableSync()
    } catch let error {
        Log.error("Failed to create table in database: \(error)")
    }

    do {
        try Admin.createTableSync()
    } catch let error {
        Log.error("Failed to create table in database: \(error)")
    }

    let cred = Credentials()
    cred.register(plugin: app.rawAuth)
    app.router.all("/journal", middleware: cred)
    

    app.router.get("/journal/all") { _, response, _ in
        JournalItem.findAll { (result: [(Int, JournalItem)]?, error: RequestError?) in
            guard let items = result else { return }
            var entries: [[String: Any]] = []
            for (index, entry) in items {
              let id = String(index)
              let title : String = entry.title
              let content : String = entry.content
              let map = ["id": id, "title": title, "content": content]
              entries.append(map)
            }
            do {              
                try response.render("main", context: ["title": title,
                                                      "author": author,
                                                      "count": "\(items.count)",
                                                      "entries": entries])
            } catch let error {
                response.send(error.localizedDescription)
            }
        }
    }

    app.router.get("/journal/create") { request, response, next in
        response.headers["Content-Type"] = "text/html; charset=utf-8"
        try response.render("new", context: ["title": title, "author": author])
    }
    
    app.router.post("/journal/new") { request, response, next in
        guard let entry = try? request.read(as: JournalItem.self)
            else { return try response.status(.unprocessableEntity).end() }
        let item = JournalItem(title: entry.title, content: entry.content)
        item.save { item, error in 
        do {
             try response.redirect(mainPage)
            } catch let error {
                response.send(error.localizedDescription)
            } 
        } 
    }
    
    app.router.get("/journal/get/:index?") { request, response, next in
        if let index = request.parameters["index"] {
            if let idx = Int(index) {
              JournalItem.find(id: idx) { result, error in
                guard let item = result else { return }
                let id = String(idx)
                let title : String = item.title
                let content : String = item.content
                let entry = ["id": id, "title": title, "content": content]
                do {
                  try response.render("entry", 
                                      context: ["title": title, 
                                                "author": author, 
                                                "entry": entry])
                } catch let error {
                    response.send(error.localizedDescription)
                }
                
              }

            }
        }
    }
    
    app.router.get("/journal/remove/:index?") { request, response, next in
        if let index = request.parameters["index"] {
            if let idx = Int(index) {
               JournalItem.delete(id: idx) { error in
                    do {
                        try response.redirect(mainPage)
                    } catch let error {
                        response.send(error.localizedDescription)
                    } 
                }
            }
        }
    }
}

extension App {
    var rawAuth: CredentialsHTTPBasic {
        let cred = CredentialsHTTPBasic(verifyPassword: { login, password, callback in
            if Admin.checkPassword(username: login, password: password) {
                callback(UserProfile(id: login, displayName: login, provider: "HTTPBasic"))
            } else {
                callback(nil)
            }
        })
        cred.realm = "HTTP Basic authentication: Username = username, Password = password"
        return cred
    }
}
