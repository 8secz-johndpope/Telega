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

let months = [
	0: "Jan",
	1: "Feb",
	2: "Mar",
	3: "Apr",
	4: "May",
	5: "Jun",
	6: "Jul",
	7: "Aug",
	8: "Sep",
	9: "Oct",
	10: "Nov",
	11: "Dec"
]

class DialogueVC: UIViewController {

	// Outlets
	@IBOutlet weak var messagesTable: UITableView!
	@IBOutlet weak var messageContentView: UIView!
	@IBOutlet weak var messageInputView: MessageInputView!
	@IBOutlet weak var messageViewHeightConstraint: NSLayoutConstraint!
	@IBOutlet weak var sendBtn: UIButton!
	@IBOutlet weak var noMessagesLbl: UILabel!


	// Variables
	var companion: User!
	var companionPublicKey: PublicKey?
	var oldCount: Int!
	var messageSound: AVAudioPlayer?
	var avatarBtn: UIButton!
	var avatarMask: UIView?
	var avatarImgView: UIImageView?
	var requestPending = false
	var backupText: String!

	@objc private func settingsChanged(notification: Notification) {
		guard let userinfo = notification.userInfo,
					let id = userinfo["id"] as? String,
					id == companion.id
		else { return }
		for contact in DataService.instance.contacts! where contact.id == id {
			companion = contact
		}
		self.navigationItem.title = self.companion.username
		self.avatarBtn = UIButton(type: .custom)
		self.avatarBtn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
		self.avatarBtn.contentMode = .scaleAspectFit
		self.avatarBtn.clipsToBounds = true
		self.avatarBtn.layer.cornerRadius = 15
		let image = UIImage(data: Data(base64Encoded: self.companion.avatar)!)
		if image!.size.width <= 512 {
			self.avatarBtn.setImage(
				image!.resizedImageWithinRect(rectSize: CGSize(width: 40, height: 40)),
				for: .normal)
			self.avatarBtn.backgroundColor = .darkGray
			self.avatarBtn.layer.cornerRadius = 20
		} else {
			self.avatarBtn.setImage(
				image!.resizedImageWithinRect(rectSize: CGSize(width: 50, height: 50))
					.crop(rect: CGRect(x: 5, y: 5, width: 30, height: 30)),
				for: .normal)
		}
		self.avatarBtn.addTarget(self,
														 action: #selector(self.showAvatar),
														 for: .touchUpInside)
		let barButton = UIBarButtonItem(customView: self.avatarBtn)
		self.navigationItem.rightBarButtonItem = barButton
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		messagesTable.delegate = self
		messagesTable.dataSource = self
		messagesTable.transform = CGAffineTransform(rotationAngle: (-.pi))
		navigationItem.title = companion.username
		messageInputView.delegate = self
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(messagesUpdated(notification:)),
			name: MESSAGES_UPDATED,
			object: nil)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(settingsChanged(notification:)),
			name: SETTINGS_CHANGED,
			object: nil)

		let tap = UITapGestureRecognizer(
			target: self,
			action: #selector(hideKeyboard(tap:)))
		tap.cancelsTouchesInView = false
		view.addGestureRecognizer(tap)
		messageInputView.text = "Type something"
		messageInputView.textColor = UIColor.darkGray
		view.bindToKeyboard()
		avatarBtn = UIButton(type: .custom)
		avatarBtn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
		avatarBtn.contentMode = .scaleAspectFit
		avatarBtn.clipsToBounds = true
		avatarBtn.layer.cornerRadius = 15
		let image = UIImage(data: Data(base64Encoded: companion.avatar)!)
		if image!.size.width <= 512 {
			avatarBtn.setImage(
				image!.resizedImageWithinRect(rectSize: CGSize(width: 40, height: 40)),
				for: .normal)
			avatarBtn.backgroundColor = .darkGray
			avatarBtn.layer.cornerRadius = 20
		} else {
			avatarBtn.setImage(
				image!.resizedImageWithinRect(rectSize: CGSize(width: 50, height: 50))
					.crop(rect: CGRect(x: 5, y: 5, width: 30, height: 30)),
				for: .normal)
		}
		avatarBtn.addTarget(self,
												action: #selector(showAvatar),
												for: .touchUpInside)
		let barButton = UIBarButtonItem(customView: avatarBtn)
		self.navigationItem.rightBarButtonItem = barButton
	}

	@objc private func showAvatar() {
		if avatarMask != nil || avatarImgView != nil {
			return
		}
		avatarMask = UIView(frame: view.frame)
		avatarMask!.alpha = 0
		avatarMask!.backgroundColor = UIColor(white: 0, alpha: 0.7)
		view.addSubview(avatarMask!)
		avatarImgView = UIImageView(
			frame: CGRect(
				x: view.frame.width - 30,
				y: avatarBtn.frame.origin.y + 10,
				width: 1,
				height: 1))
		avatarImgView!.image = UIImage(data: Data(base64Encoded: companion.avatar)!)
		avatarImgView!.contentMode = .scaleAspectFit
		view.addSubview(avatarImgView!)
		UIView.animate(withDuration: 0.2, animations: {
			self.avatarMask!.alpha = 1
			self.avatarImgView!.frame = self.view.frame
		}, completion: { (_) in
			let tap = UITapGestureRecognizer(
				target: self,
				action: #selector(self.hideAvatar))
			self.avatarMask!.addGestureRecognizer(tap)
		})
	}

	@objc private func hideAvatar() {
		UIView.animate(withDuration: 0.2, animations: {
			self.avatarImgView?.frame = CGRect(
				x: self.view.frame.width - 30,
				y: self.avatarBtn.frame.origin.y + 10,
				width: 1,
				height: 1)
			self.avatarMask?.alpha = 0
		}, completion: { (_) in
			self.avatarImgView?.removeFromSuperview()
			self.avatarMask?.removeFromSuperview()
			self.avatarMask = nil
			self.avatarImgView = nil
		})
	}

	@objc func hideKeyboard(tap: UITapGestureRecognizer) {
		let tapLocation = tap.location(in: sendBtn)
		if sendBtn.layer.contains(tapLocation) {
			return
		}
		view.endEditing(true)
	}

	@objc private func messagesUpdated(notification: Notification) {
		noMessagesLbl.isHidden = true
		TelegaAPI.emitReadMessagesFrom(id: companion.id)
		if let result = notification.userInfo?["storing_result"] as? StoringResult,
			 let id = notification.userInfo?["id"] as? String,
					 id == companion.id {
			switch result {
			case .freshContact, .freshDate: do { self.messagesTable.reloadData() }
			case .freshMessage: do {
				self.messagesTable.insertRows(
					at: [IndexPath(row: 0, section: 0)],
					with: .top)
				}
			}
			for (index, contact) in DataService.instance.contacts!.enumerated() {
				if contact.id == companion.id {
					DataService.instance.contacts![index].unread = false
				}
			}
		}
	}

	private func playSound() {
		guard let path = Bundle.main.path(forResource: "light", ofType:"mp3")
		else { return print("COULD NOT GET RESOURCE") }
		let url = URL(fileURLWithPath: path)
		do {
			self.messageSound = try AVAudioPlayer(contentsOf: url)
			messageSound?.play()
		} catch { print("COULD NOT GET FILE") }
	}

	override func viewWillAppear(_ animated: Bool) {
		noMessagesLbl.isHidden = MessagesStorage.messagesExistWith(id: companion.id)
	}

	override func viewDidAppear(_ animated: Bool) {
		if companionPublicKey == nil {
			let alert = UIAlertController(
				title: "Error",
				message: "We got a problem with this contact's public key",
				preferredStyle: .alert)
			let sad = UIAlertAction( title: "That's sad", style: .default) { (_) in
				self.navigationController?.popViewController(animated: true)
			}
			alert.addAction(sad)
			present(alert, animated: true, completion: nil)
		}
		for (index, contact) in DataService.instance.contacts!.enumerated() {
			if contact.id == companion.id {
				DataService.instance.contacts![index].unread = false
			}
		}
		TelegaAPI.emitReadMessagesFrom(id: companion.id)
	}

	@IBAction func sendBtnPressed() {
		sendBtn.isEnabled = false
		sendBtn.isHidden = true
		requestPending = true
		let gif = GIFImageView(frame: sendBtn.frame)
		gif.animate(withGIFNamed: "ripple")
		messageContentView.addSubview(gif)
		if messageInputView.text == nil || messageInputView.text == "" {
			return
		}
		do {
			let trimmedText = messageInputView.text!.trimmingCharacters(
				in: .whitespacesAndNewlines)
			let clear = try ClearMessage(string: trimmedText, using: .utf8)
			let encryptedForCompanion = try clear.encrypted(
				with: self.companionPublicKey!,
				padding: .PKCS1)
			let myPublicKey = try PublicKey(
				pemEncoded: DataService.instance.publicPem!)
			let encryptedForMe = try clear.encrypted(
				with: myPublicKey,
				padding: .PKCS1)
			TelegaAPI.send(
				message: encryptedForCompanion.base64String,
				toUserWithID: companion.id,
				andStoreCopyForMe: encryptedForMe.base64String,
				completion: { timeStr in
					self.noMessagesLbl.isHidden = true
					let dateFormatter = ISO8601DateFormatter()
					dateFormatter.timeZone = TimeZone(abbreviation: "EET")
					let time = dateFormatter.date(
						from:timeStr.components(separatedBy: ".")[0] + "-0200")!
					let newMessage = Message(text:trimmedText, time: time, mine: true)
					MessagesStorage.storeNew(
						message: newMessage,
						storeID: self.companion.id,
						timeStr: timeStr,
						completion: { (result) in
							switch result {
							case .freshContact, .freshDate:
								do { self.messagesTable.reloadData() }
							case .freshMessage: do { self.messagesTable.insertRows(
								at: [IndexPath(row: 0, section: 0)],
								with: .top) }
							}
					})
					self.requestPending = false
					self.messageInputView.text = ""
					self.messageViewHeightConstraint.constant = 58.0
					self.sendBtn.isEnabled = true
					self.sendBtn.isHidden = false
					gif.removeFromSuperview()
			})
		} catch {
			self.sendBtn.isEnabled = true
			self.sendBtn.isHidden = false
			self.requestPending = false
			gif.removeFromSuperview()
		}
	}
}

extension DialogueVC: UITextViewDelegate {

	func textViewDidBeginEditing(_ textView: UITextView) {
		if textView.textColor == UIColor.darkGray {
			textView.text = nil
			textView.textColor = UIColor.white
		}
	}

	func textViewDidEndEditing(_ textView: UITextView) {
		if textView.text.isEmpty {
			textView.text = "Type something"
			textView.textColor = UIColor.darkGray
		}
	}

	func textViewDidChange(_ textView: UITextView) {
		if requestPending
		{ return textView.text = backupText }
		let fixedWidth = textView.frame.size.width
		let newSize = textView.sizeThatFits(CGSize(
			width: fixedWidth,
			height: CGFloat.greatestFiniteMagnitude))
		messageViewHeightConstraint.constant = newSize.height + 20
		backupText = textView.text
	}
}

extension DialogueVC: UITableViewDelegate, UITableViewDataSource {

	func numberOfSections(in tableView: UITableView) -> Int {
		return MessagesStorage.numberOfDatesBy(user: companion.id)
	}

	func tableView(
		_ tableView: UITableView,
		numberOfRowsInSection section: Int
		) -> Int {
		return MessagesStorage.numberOfMessagesBy(
			dateIndex: section,
			andContact: companion.id)
	}

	func tableView(
		_ tableView: UITableView,
		cellForRowAt indexPath: IndexPath
		) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(
			withIdentifier: "messageCell") as! MessageCell
		cell.transform = CGAffineTransform(rotationAngle: (-.pi))
		if let messages = MessagesStorage.messagesOfContactWith(
			id: companion.id,
			andOfDateIndex: indexPath.section) {
			let message = messages[indexPath.row]
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
			cell.infoView.layer.maskedCorners = [.layerMaxXMaxYCorner,
																					 .layerMinXMaxYCorner]
			let timi = message.time.description.components(separatedBy: " ")[1]
			let hours = timi.components(separatedBy: ":")[0]
			let minutes = timi.components(separatedBy: ":")[1]
			cell.timeLbl.text = hours + ":" + minutes
			if messages[indexPath.row].mine {
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

	func tableView(
		_ tableView: UITableView,
		didEndDisplaying cell: UITableViewCell,
		forRowAt indexPath: IndexPath
		) {
		if let cell = tableView.dequeueReusableCell(
			withIdentifier: "messageCell") as? MessageCell {
			cell.tail?.removeFromSuperview()
			cell.tail = nil
		}
	}

	func tableView(_ tableView: UITableView,
								 viewForFooterInSection section: Int) -> UIView? {
		let label = UILabel(frame: CGRect(
			x: 0,
			y: 0,
			width: tableView.frame.width,
			height: 20))
		let attributes = [NSAttributedString.Key.foregroundColor: UIColor.darkGray,
											NSAttributedString.Key.font: UIFont(
												name: "Avenir Next",
												size: 14)!
		]
		guard var sectionDateStr = MessagesStorage.dateStringForIndex(
			section,
			forID: companion.id)
			else { return nil }
		let date = Date()
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy:MM:dd"
		let result = formatter.string(from: date)
		let todayStr = result.components(separatedBy: " ")[0]
		if sectionDateStr == todayStr.replacingOccurrences(of: ":", with: "-") {
			sectionDateStr = "Today"
		} else {
			let year = sectionDateStr.components(separatedBy: "-")[0]
			var monthStr = sectionDateStr.components(separatedBy: "-")[1]
			if monthStr.first == "0" {
				monthStr.removeFirst()
			}
			let month = months[Int(monthStr)! - 1]!
			let day = sectionDateStr.components(separatedBy: "-")[2]
			sectionDateStr = "\(day) \(month), \(year)"
		}
		let text = NSMutableAttributedString(
			string: sectionDateStr,
			attributes: attributes)
		label.attributedText = text
		label.textAlignment = .center
		label.textColor = .darkGray
		label.transform = CGAffineTransform(scaleX: -1, y: -1)
		return label
	}
}
