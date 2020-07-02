//
//  NXTFModelDataHandler.h
//  TestTensorflow
//
//  Created by Ghost on 2020/7/1.
//  Copyright © 2020 Ghost. All rights reserved.
//

#import <UIKit/UIImage.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^NXTFModelDataBlock) (NSArray *__nullable array, NSError *__nullable error, CFAbsoluteTime timeInterval);

@interface NXTFModelDataHandler : NSObject

+ (void)setupModelPath:(NSString*)modelPath;

+ (void)classifyImage:(UIImage*)image completion:(NXTFModelDataBlock)completion;

+ (void)classifyCVPixelBuffer:(CVPixelBufferRef)pixelBuffer completion:(NXTFModelDataBlock)completion;

@end

NS_ASSUME_NONNULL_END
