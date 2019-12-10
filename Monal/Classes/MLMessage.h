//
//  MLMessage.h
//  Monal
//
//  Created by Anurodh Pokharel on 11/27/19.
//  Copyright © 2019 Monal.im. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 message object intended to be passed around and eventually used to render
 */
@interface MLMessage : NSObject


/**
 account number in the database should be an integer
 */
@property (nonatomic, copy) NSString *accountId;

/**
 The message's local  unique identifier
 */
@property (nonatomic, copy) NSString *messageId;

/**
 The id for the message as provided by the xmpp server
 */
@property (nonatomic, copy) NSString *stanzaId;

/**
The of the message in the DB , should be int
 */
@property (nonatomic, copy) NSNumber *messageDBId;

/**
 Actual sender will differ from the "from" when in a group chat
 */
@property (nonatomic, copy) NSString *actualFrom;
@property (nonatomic, copy) NSString *from;
@property (nonatomic, copy) NSString *to;

@property (nonatomic, copy) NSString* messageType;

@property (nonatomic, copy) NSString *messageText;

/**
 If the text was parsed into a URL. For message type url
 */
@property (nonatomic, copy) NSURL *url;

/**
 path to preview image for image type
 */
@property (nonatomic, copy) NSURL *previewImage;
@property (nonatomic, copy) NSString *previewText;

/**
 for message type status. The MUC subeject
 */
@property (nonatomic, copy) NSString *groupSubject;



@property (nonatomic, copy) NSDate *delayTimeStamp;
@property (nonatomic, copy) NSDate *timestamp;

/*
 usually used to indicate if the message was  encrypted on the wire, not in this payload
 */
@property (nonatomic, assign) BOOL encrypted;

/*
 whether the text was sent out on the wire not if it was delivered to the recipient
 */
@property (nonatomic, assign) BOOL hasBeenSent;

/*
 Whether a message was recieved by the device on the other end
 */
@property (nonatomic, assign) BOOL hasBeenReceived;

@property (nonatomic, assign) BOOL shouldShowAlert;

/*
 the message has not been marked as read in the db
 */
@property (nonatomic, assign) BOOL unread;

/**
 Converts a dictonary to a message object Provide a formatter for the format the dates will be in
 */
+(MLMessage *) messageFromDictionary:(NSDictionary *) dic withDateFormatter:(NSDateFormatter *) formatter;

-(BOOL) shouldForceRefresh;

@end

NS_ASSUME_NONNULL_END
