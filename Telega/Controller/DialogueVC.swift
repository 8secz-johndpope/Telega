//
//  DialogueVC.swift
//  Telega
//
//  Created by Roman Kyslyy on 2/7/19.
//  Copyright © 2019 Roman Kyslyy. All rights reserved.
//

import UIKit
import SwiftyRSA
import AVFoundation
import Gifu

class DialogueVC: UIViewController {
    
    // Outlets
    @IBOutlet weak var messagesTable: UITableView!
    @IBOutlet weak var messageContentView: UIView!
    @IBOutlet weak var messageInputView: MessageInputView!
    @IBOutlet weak var messageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var sendBtn: UIButton!
    
    // Variables
    var companion: User!
    var companionPublicKey: PublicKey?
    var oldCount: Int!
    var messageSound: AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        messagesTable.delegate = self
        messagesTable.dataSource = self
        messagesTable.transform = CGAffineTransform(rotationAngle: (-.pi))
        
        navigationItem.title = companion.username
        messageInputView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(messagesUpdated(notification:)), name: MESSAGES_UPDATED, object: nil)
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard(tap:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        view.bindToKeyboard()
    }
    
    @objc func hideKeyboard(tap: UITapGestureRecognizer) {
        let tapLocation = tap.location(in: sendBtn)
        if sendBtn.layer.contains(tapLocation) {
            return
        }
        view.endEditing(true)
    }
    
    @objc private func messagesUpdated(notification: Notification) {
        if let idToUpdate = notification.userInfo?["companionID"] as? String {
            if idToUpdate == companion.id {
//                playSound()
                messagesTable.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
                oldCount = DataService.instance.userMessages[companion.id]!.count
            }
        }
    }
    
    private func playSound() {
        guard let path = Bundle.main.path(forResource: "light", ofType:"mp3") else { print("COULD NOT GET RESOURCE"); return }
        print("WE GOT PATH")
        let url = URL(fileURLWithPath: path)
        do {
            self.messageSound = try AVAudioPlayer(contentsOf: url)
            messageSound?.play()
        } catch { print("COULD NOT GET FILE") }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if companionPublicKey == nil {
            let alert = UIAlertController(title: "Error", message: "We got a problem with this contact's public key", preferredStyle: .alert)
            let sad = UIAlertAction(title: "That's sad", style: .default) { (_) in
                self.navigationController?.popViewController(animated: true)
            }
            alert.addAction(sad)
            present(alert, animated: true, completion: nil)
        }
        oldCount = DataService.instance.userMessages[companion.id]?.count ?? 0
    }
    
    @IBAction func sendBtnPressed() {
        sendBtn.isEnabled = false
        sendBtn.isHidden = true
        let gif = GIFImageView(frame: sendBtn.frame)
        gif.animate(withGIFNamed: "ripple")
        messageContentView.addSubview(gif)
        if messageInputView.text == nil || messageInputView.text == "" {
            return
        }
        do {
            let clear = try ClearMessage(string: messageInputView.text!.trimmingCharacters(in: .whitespacesAndNewlines), using: .utf8)
            let encryptedForCompanion = try clear.encrypted(with: self.companionPublicKey!, padding: .PKCS1)
            let myPublicKey = try PublicKey(pemEncoded: DataService.instance.publicPem!)
            let encryptedForMe = try clear.encrypted(with: myPublicKey, padding: .PKCS1)
            TelegaAPI.instanse.send(message: encryptedForCompanion.base64String, toUserWithID: companion.id, andStoreCopyForMe: encryptedForMe.base64String) {time in
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.timeZone = TimeZone(abbreviation: "EET")
                let time = dateFormatter.date(from:time.components(separatedBy: ".")[0] + "-0200")!
                let newMessage = Message(text:self.messageInputView.text, time: time, mine: true)
                if DataService.instance.userMessages[self.companion.id] == nil {
                    DataService.instance.userMessages[self.companion.id] = [Message]()
                }
                DataService.instance.userMessages[self.companion.id]!.append(newMessage)
                self.messagesTable.insertRows(at: [IndexPath(row: 0, section: 0)], with: .top)
                self.messageInputView.text = ""
                self.messageViewHeightConstraint.constant = 58.0
                self.sendBtn.isEnabled = true
                self.sendBtn.isHidden = false
                gif.removeFromSuperview()
            }
        } catch {
            print("COULD NOT SEND MESSAGE")
            self.sendBtn.isEnabled = true
            self.sendBtn.isHidden = false
            gif.removeFromSuperview()
        }
    }
    
}

extension DialogueVC: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        let fixedWidth = textView.frame.size.width
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        messageViewHeightConstraint.constant = newSize.height + 20
    }
}

extension DialogueVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return DataService.instance.userMessages[companion.id]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "messageCell") as! MessageCell
        cell.transform = CGAffineTransform(rotationAngle: (-.pi))
        if let messages = DataService.instance.userMessages[companion.id] {
            let message = messages.reversed()[indexPath.row]
            var text = message.text
            if text.count <= 5 {
                for _ in 0..<10 - text.count {
                    text += " "
                }
            }
            cell.messageText.text = text
            cell.lanchor = cell.leftCon
            cell.ranchor = cell.rightCon
            cell.infoView.clipsToBounds = true
            cell.infoView.layer.cornerRadius = 10
            cell.infoView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
            let timi = message.time.description.components(separatedBy: " ")[1]
            let hours = timi.components(separatedBy: ":")[0]
            let minutes = timi.components(separatedBy: ":")[1]
            cell.timeLbl.text = hours + ":" + minutes
            if messages.reversed()[indexPath.row].mine {
                cell.lanchor.isActive = false
                cell.ranchor.isActive = true
                if cell.messageText.text?.count ?? 0 >= 35 {
                    cell.lanchor.isActive = true
                }
                cell.mine = true
            } else {
                cell.lanchor.isActive = true
                cell.ranchor.isActive = false
                if cell.messageText.text?.count ?? 0 >= 35 {
                    cell.ranchor.isActive = true
                }
                cell.mine = false
            }
            return cell
        } else {
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "messageCell") as? MessageCell {
            cell.tail?.removeFromSuperview()
        }
    }
}

extension UIView {
    
    func bindToKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    @objc func keyboardWillChangeFrame(_ notification: NSNotification) {
        let duration = notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        let curve = notification.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey] as! UInt
        let beginningFrame = notification.userInfo![UIResponder.keyboardFrameBeginUserInfoKey] as! CGRect
        let endingFrame = notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        let deltaY = beginningFrame.origin.y - endingFrame.origin.y
        
        UIView.animateKeyframes(withDuration: duration,
                                delay: 0.0,
                                options: UIView.KeyframeAnimationOptions(rawValue: curve),
                                animations: {
                                    self.frame.size.height -= deltaY
        }, completion: nil)
    }
    
    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
}

extension Date {
    
    func isToday() -> Bool {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd"
        let result = formatter.string(from: date)
        let todayStr = result.components(separatedBy: " ")[0]
        let target = formatter.string(from: self)
        let targetStr = target.components(separatedBy: " ")[0]
        return todayStr == targetStr
    }
    
}
