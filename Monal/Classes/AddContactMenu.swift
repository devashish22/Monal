//
//  AddContactMenu.swift
//  Monal
//
//  Created by Jan on 27.10.22.
//  Copyright © 2022 monal-im.org. All rights reserved.
//

import MobileCoreServices
import UniformTypeIdentifiers
import SwiftUI
import monalxmpp


struct AddContactMenu: View {
    var delegate: SheetDismisserProtocol
    static private let jidFaultyPattern = "^([^@]+@)?.+\\..{2,}$"

    @State private var connectedAccounts: [xmpp]
    @State private var selectedAccount: Int
    @State private var scannedFingerprints: Dictionary<Int, String>? = nil
    @State private var importScannedFingerprints: Bool = false
    @State private var toAdd: String = ""

    @State private var showInvitationError = false
    @State private var showAlert = false
    // note: dismissLabel is not accessed but defined at the .alert() section
    @State private var alertPrompt = AlertPrompt(dismissLabel: Text("Close"))
    @State private var invitationResult: Dictionary<String, AnyObject>? = nil

    @ObservedObject private var overlay = LoadingOverlayState()

    @State private var showQRCodeScanner = false
    @State private var success = false
    @State private var newContact : MLContact?
    
    private let dismissWithNewContact: (MLContact) -> ()
    private let preauthToken: String?

    init(delegate: SheetDismisserProtocol, dismissWithNewContact: @escaping (MLContact) -> (), prefillJid: String = "", preauthToken:String? = nil) {
        self.delegate = delegate
        self.dismissWithNewContact = dismissWithNewContact
        //self.toAdd = State(wrappedValue: prefillJid)
        self.toAdd = prefillJid
        self.preauthToken = preauthToken
        
        let connectedAccounts = MLXMPPManager.sharedInstance().connectedXMPP as! [xmpp]
        self.connectedAccounts = connectedAccounts
        self.selectedAccount = connectedAccounts.first != nil ? 0 : -1;
    }
    
    // FIXME duplicate code from WelcomeLogIn.swift, maybe move to SwiftuiHelpers
    private var toAddEmptyAlert: Bool {
        alertPrompt.title = Text("No Empty Values!")
        alertPrompt.message = Text("Please make sure you have entered a valid jid.")
        return toAddEmpty
    }

    private var toAddInvalidAlert: Bool {
        alertPrompt.title = Text("Invalid Credentials!")
        alertPrompt.message = Text("The jid you want to add should be in in the format user@domain.tld.")
        return toAddInvalid
    }
    
    private func errorAlert(title: Text, message: Text = Text("")) {
        alertPrompt.title = title
        alertPrompt.message = message
        showAlert = true
    }
    
    private func successAlert(title: Text, message: Text) {
        alertPrompt.title = title
        alertPrompt.message = message
        self.success = true // < dismiss entire view on close
        showAlert = true
    }
    
    private var toAddEmpty: Bool {
        return toAdd.isEmpty
    }
    
    private var toAddInvalid: Bool {
        return toAdd.range(of: AddContactMenu.jidFaultyPattern, options:.regularExpression) == nil
    }

    private var buttonColor: Color {
        return toAddEmpty || toAddInvalid ? Color(UIColor.systemGray) : Color(UIColor.systemBlue)
    }

    func addJid(jid: String) {
        let account = self.connectedAccounts[selectedAccount]
        let contact = MLContact.createContact(fromJid: jid, andAccountNo: account.accountNo)
        if contact.isInRoster {
            self.newContact = contact
            if self.connectedAccounts.count > 1 {
                successAlert(title: Text("Already present"), message: Text("This contact is already in the contact list of the selected account"))
            } else {
                successAlert(title: Text("Already present"), message: Text("This contact is already in your contact list"))
            }
            return
        }
        showLoadingOverlay(overlay, headline: NSLocalizedString("Adding...", comment: ""))
        account.checkJidType(jid, withCompletion: { type, errorMsg in
            if(type == "account") {
                hideLoadingOverlay(overlay)
                let contact = MLContact.createContact(fromJid: jid, andAccountNo: account.accountNo)
                self.newContact = contact
                MLXMPPManager.sharedInstance().add(contact, withPreauthToken:preauthToken)
                successAlert(title: Text("Permission Requested"), message: Text("The new contact will be added to your contacts list when the person you've added has approved your request."))
            } else if(type == "muc") {
                showLoadingOverlay(overlay, headline: NSLocalizedString("Adding MUC...", comment: ""))
                account.mucProcessor.addUIHandler({data in
                    let success : Bool = (data as! NSDictionary)["success"] as! Bool;
                    hideLoadingOverlay(overlay)
                    if(success) {
                        self.newContact = MLContact.createContact(fromJid: jid, andAccountNo: account.accountNo)
                        successAlert(title: Text("Success!"), message: Text(String.localizedStringWithFormat("Successfully joined MUC %@!", jid)))
                    } else {
                        errorAlert(title: Text("Error entering MUC!"))
                    }
                }, forMuc: jid)
                account.joinMuc(jid)
            } else {
                hideLoadingOverlay(overlay)
                errorAlert(title: Text("Error"), message: Text(errorMsg ?? "Undefined error"))
            }
        })
    }

    var body: some View {
        let account = self.connectedAccounts[selectedAccount]
        let splitJid = HelperTools.splitJid(account.connectionProperties.identity.jid)
        Form {
            if(connectedAccounts.isEmpty) {
                Text("Please make sure at least one account has connected before trying to add a contact or channel.")
                    .foregroundColor(.secondary)
            }
            else
            {
                Section(header:Text("Contact and Group/Channel Jids are usually in the format: name@domain.tld")) {
                    if(connectedAccounts.count > 1) {
                        Picker("Use account", selection: $selectedAccount) {
                            ForEach(Array(self.connectedAccounts.enumerated()), id: \.element) { idx, account in
                                Text(account.connectionProperties.identity.jid).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField("Contact or Group/Channel Jid", text: $toAdd)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .disabled(scannedFingerprints != nil)
                        .foregroundColor(scannedFingerprints != nil ? .secondary : .primary)
                        .addClearButton(text:$toAdd)
                        //ios15: .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                }
                if(scannedFingerprints != nil && scannedFingerprints!.count > 0) {
                    Section(header: Text("A contact was scanned through the QR code scanner")) {
                        Toggle(isOn: $importScannedFingerprints, label: {
                            Text("Import and trust OMEMO fingerprints from QR code")
                        })
                    }
                }
                Section {
                    if(scannedFingerprints != nil) {
                        Button(action: {
                            toAdd = ""
                            importScannedFingerprints = true
                            scannedFingerprints = nil
                        }, label: {
                            Text("Clear scanned contact")
                                .foregroundColor(.red)
                        })
                    }
                    Button(action: {
                        showAlert = toAddEmptyAlert || toAddInvalidAlert

                        if(!showAlert) {
                            let jidComponents = HelperTools.splitJid(toAdd)
                            if(jidComponents["host"] == nil || jidComponents["host"]!.isEmpty) {
                                errorAlert(title: Text("Error"), message: Text("Something went wrong while parsing the string..."))
                                showAlert = true
                                return
                            }
                            // use the canonized jid from now on (lowercased, resource removed etc.)
                            addJid(jid: jidComponents["user"]!) // check if user entry exists in components?
                        }
                    }, label: {
                        scannedFingerprints == nil ? Text("Add Group/Channel or Contact") : Text("Add scanned Group/Channel or Contact")
                    })
                    .disabled(toAddEmpty || toAddInvalid)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: alertPrompt.title, message: alertPrompt.message, dismissButton:.default(Text("Close"), action: {
                showAlert = false
                if self.success == true {
                    if self.newContact != nil {
                        self.dismissWithNewContact(newContact!)
                    } else {
                        self.delegate.dismiss()
                    }
                }
            }))
        }
        .richAlert(isPresented: $invitationResult, title:Text("Invitation for \(splitJid["host"]!) created")) { data in
            VStack {
                Text("Direct your buddy to this webpage for instructions on how to setup an xmpp client. You will then automatically be added to their contact list.")
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Link(data["landing"] as! String, destination:URL(string:data["landing"] as! String)!)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                if let expires = data["expires"] as? Date {
                    HStack {
                        if #available(iOS 15, *) {
                            Text("This invitation will expire on \(expires.formatted(date:.numeric, time:.shortened))")
                        } else {
                            Text("This invitation will expire on \(expires)")
                        }
                    }
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } buttons: { data in 
            Button(action: {
                UIPasteboard.general.setValue(data["landing"] as! String, forPasteboardType:UTType.utf8PlainText.identifier as String)
                invitationResult = nil
            }) {
                Text("Copy link to clipboard")
                    .frame(maxWidth: .infinity)
            }
            Button(action: {
                invitationResult = nil
            }) {
                Text("Close")
                    .frame(maxWidth: .infinity)
            }
        }
        .addLoadingOverlay(overlay)
        .navigationBarTitle("Add Contact or Channel", displayMode: .inline)
        .navigationViewStyle(.stack)
        .toolbar(content: {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if account.connectionProperties.discoveredAdhocCommands["urn:xmpp:invite#invite"] != nil {
                    Button(action: {
                        DDLogVerbose("Trying to create invitation for: \(String(describing:splitJid["host"]!))")
                        showLoadingOverlay(overlay, headline: NSLocalizedString("Creating invitation...", comment: ""))
                        account.createInvitation(completion: {
                            let result = $0 as! Dictionary<String, AnyObject>
                            DispatchQueue.main.async {
                                hideLoadingOverlay(overlay)
                                DDLogVerbose("Got invitation result: \(String(describing:result))")
                                if result["success"] as! Bool == true {
                                    invitationResult = result
                                } else {
                                    errorAlert(title:Text("Failed to create invitation for \(splitJid["host"]!)"), message:Text(result["error"] as! String))
                                }
                            }
                        })
                    }, label: {
                        Image(systemName: "square.and.arrow.up").foregroundColor(monalGreen)
                    })
                }
                Button(action: {
                    self.showQRCodeScanner = true
                }, label: {
                    Image(systemName: "camera.fill").foregroundColor(monalGreen)
                })
            }
        })
        .sheet(isPresented: $showQRCodeScanner) {
            NavigationView {
                MLQRCodeScanner(
                    handleContact: { jid, fingerprints in
                        self.toAdd = jid
                        self.scannedFingerprints = fingerprints
                        self.importScannedFingerprints = true
                        self.showQRCodeScanner = false
                    }, handleClose: {
                        self.showQRCodeScanner = false
                    }
                )
                .navigationTitle("QR-Code Scanner")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading, content: {
                        Button(action: {
                            self.showQRCodeScanner = false
                        }, label: {
                            Text("Close")
                        })
                        .foregroundColor(monalGreen)
                    })
                })
            }
        }
    }
}

struct AddContactMenu_Previews: PreviewProvider {
    static var delegate = SheetDismisserProtocol()
    static var previews: some View {
        AddContactMenu(delegate: delegate, dismissWithNewContact: { c in
        })
    }
}
