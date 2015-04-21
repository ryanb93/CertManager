//
//  DDFileReader.h
//  PBX2OPML
//
//  Created by michael isbell on 11/6/11.
//  Copyright (c) 2011 BlueSwitch. All rights reserved.
//
// Source: http://stackoverflow.com/questions/3707427/how-to-read-data-from-nsfilehandle-line-by-line#3711079

#import <Foundation/Foundation.h>

@interface DDFileReader : NSObject {
    NSString * filePath;
    
    NSFileHandle * fileHandle;
    unsigned long long currentOffset;
    unsigned long long totalFileLength;
    
    NSString * lineDelimiter;
    NSUInteger chunkSize;
}

@property (nonatomic, copy) NSString * lineDelimiter;
@property (nonatomic) NSUInteger chunkSize;

- (id) initWithFilePath:(NSString *)aPath;

- (NSString *) readLine;
- (NSString *) readTrimmedLine;

#if NS_BLOCKS_AVAILABLE
- (void) enumerateLinesUsingBlock:(void(^)(NSString*, BOOL *))block;
#endif

@end