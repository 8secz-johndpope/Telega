//
//  MeRoute.swift
//  Telega
//
//  Created by Roman Kyslyy on 2/20/19.
//  Copyright © 2019 Roman Kyslyy. All rights reserved.
//

import Alamofire

extension TelegaAPI {
    class func getInfoAboutSelf(completion: @escaping () -> ()) {
        if DataService.instance.token != nil {
            DispatchQueue.global().async {
                Alamofire.request(ME_URL,
                                  method: .get,
                                  parameters: nil,
                                  encoding: JSONEncoding.default,
                                  headers: AUTH_HEADER).responseJSON(completionHandler: { (response) in
                    guard let dict = response.value as? [String : Any]
                        else { print("bad value"); return }
                    if let error = dict["error"] {
                        return print(error)
                    }
                    getDataFrom(dict)
                    completion()
                })
            }
        }
    }
    
    class private func getDataFrom(_ dict: [String: Any]) {
        guard let user = dict["user"] as? [String : Any] else { return }
        guard let id = user["_id"] as? String,
              let email = user["email"] as? String,
              let username = user["username"] as? String,
              let avatar = user["avatar"] as? String,
              let publicPem = user["publicPem"] as? String,
              let contactsData = user["contacts"] as? [[String : Any]],
              let contacts = contactsFrom(contactsData),
              let messagesData = user["messages"] as? [[String:Any]],
              let messages = MessagesParser.buildMessagesFrom(messagesData)
              else { return }
        DataService.instance.id = id
        DataService.instance.email = email
        DataService.instance.username = username
        DataService.instance.userAvatar = avatar
        DataService.instance.publicPem = publicPem
        DataService.instance.contacts = contacts
        DataService.instance.messages = messages
    }
    
    class private func contactsFrom(_ contactsData: [[String:Any]]) -> [User]? {
        let contacts = contactsData.compactMap({ (contact) -> User? in
            guard   let _id = contact["_id"] as? String,
                    let email = contact["email"] as? String,
                    let username = contact["username"] as? String,
                    let avatar = contact["avatar"] as? String,
                    let confirmed = contact["confirmed"] as? Bool,
                    let requestIsMine = contact["requestIsMine"] as? Bool,
                    let publicPem = contact["publicPem"] as? String,
                    let online = contact["online"] as? Bool,
                    let unread = contact["unread"] as? Bool
                    else { return nil }
            return User(id: _id,
                        email: email,
                        username: username,
                        avatar: avatar,
                        publicPem: publicPem,
                        confirmed: confirmed,
                        requestIsMine: requestIsMine,
                        online: online,
                        unread: unread)
        })
        return contacts.count == contactsData.count ? contacts : nil
    }
}

class MessagesParser {
    
    class func buildMessagesFrom(_ messages: [[String:Any]]) -> [String:[(date: String, messages: [Message])]]? {
        var structuredMessagesDict = [String:[(date: String, messages: [Message])]]()
        for message in messages {
            guard let storeID = message["storeID"] as? String
                else { return nil }
            if storeID == DataService.instance.id! {
                continue
            }
            if structuredMessagesDict[storeID] == nil {
                structuredMessagesDict[storeID] = [(date: String,
                                                    messages: [Message])]()
            }
        }
        for message in messages {
            guard let storeID = message["storeID"] as? String
                else { return nil }
            if structuredMessagesDict[storeID] == nil {
                continue
            }
            guard var date = (message["time"] as? String)
                else { return nil }
            date = date.components(separatedBy: "T")[0]
            if !does(date: date, existIn: structuredMessagesDict[storeID]!) {
                structuredMessagesDict[storeID]!.append((date: date, messages: [Message]()))
            }
        }
        for message in messages {
            guard let storeID = message["storeID"] as? String
                else { return nil }
            if structuredMessagesDict[storeID] == nil {
                continue
            }
            guard var date = (message["time"] as? String)
                else { return nil }
            date = date.components(separatedBy: "T")[0]
            for (index, tuple) in structuredMessagesDict[storeID]!.enumerated() {
                if tuple.date == date {
                    guard var text = message["message"] as? String
                        else { return nil }
                    guard let mine = message["mine"] as? Bool
                        else { return nil }
                    text = EncryptionService.decryptedMessage(text)
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.timeZone = TimeZone(abbreviation: "EET")
                    let time = dateFormatter.date(from:date.components(separatedBy: ".")[0] + "-0200")!
                    let messageToSave = Message(text: text, time: time, mine: mine)
                    structuredMessagesDict[storeID]![index].messages.append(messageToSave)
                }
            }
        }
        return structuredMessagesDict
    }
    
    class func does(date: String,
                    existIn tuples: [(date: String, messages: [Message])]) -> Bool {
        for tuple in tuples {
            if tuple.date == date {
                return true
            }
        }
        return false
    }
}

