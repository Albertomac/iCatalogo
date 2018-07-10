//
//  XMLParser.h
//  iCatalogo
//
//  Created by Albertomac on 23/12/13.
//  Copyright (c) 2013 Albertomac. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"
#import "AProgressView.h"
#import "TBXML.h"

@interface XMLParser : NSObject

@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) AProgressView *progressView;

- (id)initWithProgressView:(AProgressView *)progress;
- (NSString *)parseFile:(NSString *)fileName;

@end
