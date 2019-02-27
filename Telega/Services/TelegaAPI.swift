//
//  File.swift
//  Telega
//
//  Created by Roman Kyslyy on 1/28/19.
//  Copyright © 2019 Roman Kyslyy. All rights reserved.
//

class TelegaAPI {
  
  class func establishConnection() {
    SocketService.instance.establishConnection()
  }
  
  class func emitSettingsChanged(username: String, avatar: String) {
    SocketService.instance.manager.defaultSocket.emit(
      "settings_changed",
      DataService.instance.id!,
      username,
      avatar)
  }
  
  class func emitReadMessagesFrom(id: String) {
    SocketService.instance.manager.defaultSocket.emit(
      "messages_read",
      id,
      DataService.instance.id!)
  }
  
  class func disconnect() {
    SocketService.instance.manager.defaultSocket.disconnect()
  }
}
