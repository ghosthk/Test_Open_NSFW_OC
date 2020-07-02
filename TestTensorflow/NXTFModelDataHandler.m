//
//  NXTFModelDataHandler.m
//  TestTensorflow
//
//  Created by Ghost on 2020/7/1.
//  Copyright © 2020 Ghost. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#import <TFLTensorFlowLite.h>
#import <UIKit/UIGraphics.h>
#import "TFLInterpreter+Internal.h"
#import "NXTFModelDataHandler.h"

@interface NSData (TFModel)

- (NSArray*)tf_toFloatArray;

@end

@interface UIImage (TFModel)

- (UIImage*)tf_resizeImage:(CGSize)size;
- (NSData*)tf_rgbData;

@end

@interface NXTFModelDataTool : NSObject

+ (CVPixelBufferRef)tf_resizePixelBuffer:(CVPixelBufferRef)pixelBuffer toSize:(CGSize)toSize;
+ (NSData*)tf_rgbDataFromPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

@interface NXTFModelDataHandler ()

@property(class, nonatomic, readonly) NXTFModelDataHandler *shareInstance;
@property(nonatomic, strong) TFLInterpreter *interpreter;
@property(nonatomic, assign) NSInteger limitWidth;
@property(nonatomic, assign) NSInteger limitHeight;

@end

@implementation NXTFModelDataHandler

+ (void)setupModelPath:(NSString*)modelPath {
    [NXTFModelDataHandler.shareInstance _setupModelPath:modelPath];
}

+ (void)classifyImage:(UIImage*)image completion:(NXTFModelDataBlock)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NXTFModelDataHandler.shareInstance _classifyImage:image completion:completion];
    });
}

+ (void)classifyCVPixelBuffer:(CVPixelBufferRef)pixelBuffer completion:(NXTFModelDataBlock)completion {
    [NXTFModelDataHandler.shareInstance _classifyCVPixelBuffer:pixelBuffer completion:completion];
}

+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    static NXTFModelDataHandler *__staticTFModelDataHandler = nil;
    dispatch_once(&onceToken, ^{
        __staticTFModelDataHandler = [[NXTFModelDataHandler alloc] init];
    });
    return __staticTFModelDataHandler;
}

- (NSError*)_setupModelPath:(NSString*)modelPath {
    TFLInterpreterOptions *options = [[TFLInterpreterOptions alloc] init];
    options.numberOfThreads = 0;
    NSError *error = nil;
    TFLInterpreter *interpreter = [[TFLInterpreter alloc] initWithModelPath:modelPath options:options error:&error];
    if (error) {
        NSLog(@"NXTFModelDataHandler: init Interpreter fails %@",error);
        return error;
    }
    self.interpreter = interpreter;
    BOOL result = [interpreter allocateTensorsWithError:&error];
    if (!result || error) {
        NSLog(@"NXTFModelDataHandler: allocate tensors fails %@",error);
        return error;
    }
    TFLTensor *tensor = [interpreter inputTensorAtIndex:0 error:&error];
    if (!tensor || error) {
        NSLog(@"NXTFModelDataHandler: get default tensor fails %@",error);
        return error;
    }
    NSArray *numbers = [tensor shapeWithError:&error];
    if (numbers.count != 4 || error) {
        NSLog(@"NXTFModelDataHandler: get limit size fails %@",error);
        return error;
    }
    self.limitWidth = [numbers[1] integerValue];
    self.limitHeight = [numbers[2] integerValue];
    NSLog(@"NXTFModelDataHandler: Limit Size (%@,%@)",@(self.limitWidth),@(self.limitHeight));
    return nil;
}

- (void)_classifyImage:(UIImage*)image completion:(NXTFModelDataBlock)completion {
    CFTimeInterval beginTimeInterval = CACurrentMediaTime();
    
    if (!self.interpreter) {
        [self _ayncMainQueueError:@"Please First Runing setupModelPath method" code:100 beginTime:beginTimeInterval completion:completion];
        return;
    }
    if (image == nil) {
        [self _ayncMainQueueError:@"Input Image is nil" code:101 beginTime:beginTimeInterval completion:completion];
        return;
    }
    
    image = [image tf_resizeImage:CGSizeMake(self.limitWidth, self.limitHeight)];
    
    NSData *inputData = [image tf_rgbData];

    [self _classifyInputData:inputData beginTime:beginTimeInterval completion:completion];
}

- (void)_classifyCVPixelBuffer:(CVPixelBufferRef)pixelBuffer completion:(NXTFModelDataBlock)completion {
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CFTimeInterval beginTimeInterval = CACurrentMediaTime();
        
        if (!self.interpreter) {
            [self _ayncMainQueueError:@"Please First Runing setupModelPath method" code:100 beginTime:beginTimeInterval completion:completion];
            CVPixelBufferRelease(pixelBuffer);
            return;
        }
        
        OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        if (!(sourcePixelFormat == kCVPixelFormatType_32ARGB || sourcePixelFormat == kCVPixelFormatType_32BGRA || sourcePixelFormat == kCVPixelFormatType_32RGBA)) {
            [self _ayncMainQueueError:[NSString stringWithFormat:@"pixelBuffer type not support type=%@",@(sourcePixelFormat)] code:107 beginTime:beginTimeInterval completion:completion];
            CVPixelBufferRelease(pixelBuffer);
            return;
        }
        
        CVPixelBufferRef newPixelBuffer = [NXTFModelDataTool tf_resizePixelBuffer:pixelBuffer toSize:CGSizeMake(self.limitWidth, self.limitHeight)];
        CVPixelBufferRelease(pixelBuffer);
        
        if (newPixelBuffer == NULL) {
            [self _ayncMainQueueError:@"Resize pixel buffer fails" code:107 beginTime:beginTimeInterval completion:completion];
            return;
        }
        
        NSData *inputData = [NXTFModelDataTool tf_rgbDataFromPixelBuffer:newPixelBuffer];
        CVPixelBufferRelease(newPixelBuffer);
        
        [self _classifyInputData:inputData beginTime:beginTimeInterval completion:completion];
    });
}

- (void)_ayncMainQueueError:(NSString*)errorLog code:(NSInteger)code beginTime:(CFAbsoluteTime)beginTime completion:(NXTFModelDataBlock)completion {
    NSLog(@"NXTFModelDataHandler: %@",errorLog);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"NXTFModelDataHandlerErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:errorLog}], CACurrentMediaTime() - beginTime);
        }
    });
}

- (void)_classifyInputData:(NSData*)inputData beginTime:(CFAbsoluteTime)beginTime completion:(NXTFModelDataBlock)completion {
    NSError *error = nil;
    BOOL result = [self.interpreter allocateTensorsWithError:&error];
    if (!result || error) {
        [self _ayncMainQueueError:[NSString stringWithFormat:@"Alloc memory error %@",error] code:102 beginTime:beginTime completion:completion];
        return;
    }
    
    result = [self.interpreter copyData:inputData toInputTensorAtIndex:0 error:&error];
    if (!result || error) {
        [self _ayncMainQueueError:[NSString stringWithFormat:@"setup inputdata error %@",error] code:103 beginTime:beginTime completion:completion];
        return;
    }
    
    result = [self.interpreter invokeWithError:&error];
    if (!result || error) {
        [self _ayncMainQueueError:[NSString stringWithFormat:@"invoke interpreter error %@",error] code:104 beginTime:beginTime completion:completion];
        return;
    }
    
    TFLTensor *tensor = [self.interpreter outputTensorAtIndex:0 error:&error];
    if (!tensor || error) {
        [self _ayncMainQueueError:[NSString stringWithFormat:@"output tensor error %@",error] code:105 beginTime:beginTime completion:completion];
        return;
    }
    
    NSData *data = [tensor dataWithError:&error];
    if (!data || error) {
        [self _ayncMainQueueError:[NSString stringWithFormat:@"parse data fails %@",error] code:106 beginTime:beginTime completion:completion];
        return;
    }
    NSArray *array = [data tf_toFloatArray];
    NSLog(@"NXTFModelDataHandler: Completion %@",array);
    CFTimeInterval duration = CACurrentMediaTime() - beginTime;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(array, nil, duration);
        }
    });
}

@end

@implementation NSData (TFModel)

- (NSArray*)tf_toFloatArray {
    float *bytePtr = (float*)[self bytes];
    NSInteger totalData = [self length] / sizeof(float);

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:totalData];
    for (int i = 0; i < totalData; i++) {
        [array addObject:@(bytePtr[i])];
    }
    return [NSArray arrayWithArray:array];
}

@end


@implementation UIImage (TFModel)

- (UIImage*)tf_resizeImage:(CGSize)toSize {
    return [self tf_resizeImage:toSize fill:false];
}
- (UIImage*)tf_resizeImage:(CGSize)toSize fill:(BOOL)fill {
    CGSize size = self.size;
    float widthRatio  = toSize.width  / size.width;
    float heightRatio = toSize.height / size.height;
    CGFloat ratio = 1.0f;
    if (fill) {
        ratio = MIN(widthRatio, heightRatio);
    }else {
        ratio = MAX(widthRatio, heightRatio);
    }
    float xDiff = 0.0f;
    float yDiff = 0.0f;
    CGSize scaleSize = CGSizeMake(size.width * ratio,  size.height * ratio);
    CGSize resultSize = scaleSize;
    if (fill) {
        
    }else {
        resultSize = toSize;
        if (widthRatio > heightRatio) {
            yDiff = (resultSize.height - scaleSize.height)/2;
        }else {
            xDiff = (resultSize.width - scaleSize.width)/2;
        }
    }
    // This is the rect that we've calculated out and this is what is actually used below
    CGRect rect = CGRectMake(xDiff, yDiff, scaleSize.width, scaleSize.height);
    
    // Actually do the resizing to the rect using the ImageContext stuff
    UIGraphicsBeginImageContextWithOptions(resultSize, false, 1.0f);
    [self drawInRect:rect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (NSData*)tf_rgbData {
    NSInteger width = self.size.width;
    NSInteger height = self.size.width;
    
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nil, width, height, 8, width*4, colorSpace, bitmapInfo);
    CGRect rect = CGRectMake(0.0f, 0.0f, width, height);
    rect.origin.x = (width - rect.size.width)/2;
    rect.origin.y = (height - rect.size.height)/2;
    CGContextDrawImage(context, rect, self.CGImage);
    
    UInt8 *imageData = CGBitmapContextGetData(context);
    
    NSMutableData *inputData = [[NSMutableData alloc] initWithCapacity:0];
    for (int row = 0; row < width; row++) {
        for (int col = 0; col < height; col++) {
            long offset = 4 * (col * width + row);
            
            //            Float32 alph = imageData[offset];
            Float32 red = imageData[offset+1];
            Float32 green = imageData[offset+2];
            Float32 blue = imageData[offset+3];
            
            Float32 red1 = red - 123;
            Float32 green1 = green - 117;
            Float32 blue1 = blue - 104;
            
            [inputData appendBytes:&blue1 length:sizeof(blue1)];
            [inputData appendBytes:&green1 length:sizeof(green1)];
            [inputData appendBytes:&red1 length:sizeof(red1)];
        }
    }
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    return inputData;
}

@end

@implementation NXTFModelDataTool

void freePixelBufferDataAfterRelease(void *releaseRefCon, const void *baseAddress) {
    // Free the memory we malloced for the vImage rotation
    free((void *)baseAddress);
}

+ (CVPixelBufferRef)tf_resizePixelBuffer:(CVPixelBufferRef)pixelBuffer toSize:(CGSize)toSize {
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    NSInteger imageWidth = CVPixelBufferGetWidth(pixelBuffer);
    NSInteger imageHeight = CVPixelBufferGetHeight(pixelBuffer);
    NSInteger imageRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
    OSType formatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
    NSInteger imageChannel = 4;

    NSInteger originX = 0, originY = 0;
    float widthRatio  = imageWidth / toSize.width;
    float heightRatio = imageHeight / toSize.height;
    CGFloat ratio = MIN(widthRatio, heightRatio);
    CGSize scaleSize = CGSizeMake(toSize.width * ratio,  toSize.height * ratio);
    if (heightRatio > widthRatio) {
        originY = (imageHeight - scaleSize.height)/2;
    }else {
        originX = (imageWidth - scaleSize.width)/2;
    }
    
    NSInteger thumbnailRowBytes = toSize.width * imageChannel;

    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    uint8_t *thumbAddress = malloc(toSize.height * thumbnailRowBytes);
    
    vImage_Buffer inputImageBuffer = { baseAddress + originY*imageRowBytes + originX*imageChannel, scaleSize.width, scaleSize.height, imageRowBytes};
    vImage_Buffer thumbImageBuffer = { thumbAddress, toSize.width, toSize.height, toSize.width*imageChannel};
    
    vImage_Error imageScaleError = vImageScale_ARGB8888(&inputImageBuffer, &thumbImageBuffer, nil, kvImageNoFlags);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (imageScaleError != kvImageNoError) {
        free(thumbAddress);
        return NULL;
    }
    
    CVPixelBufferRef newPixelBuffer = nil;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, toSize.width, toSize.height, formatType, thumbAddress, thumbnailRowBytes, freePixelBufferDataAfterRelease, NULL, NULL, &newPixelBuffer);
    
    return newPixelBuffer;
}

+ (NSData*)tf_rgbDataFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    NSInteger imageChannel = 4;
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    OSType formatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
    UInt8 *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    NSInteger count = CVPixelBufferGetDataSize(pixelBuffer);
    
    NSArray *rgbChannelMap = @[@0, @1, @2];
    switch (formatType) {
        case kCVPixelFormatType_32BGRA:
            rgbChannelMap = @[@2, @1, @0];
            break;
        case kCVPixelFormatType_32RGBA:
            rgbChannelMap = @[@0, @1, @2];
            break;
        case kCVPixelFormatType_32ABGR:
            rgbChannelMap = @[@3, @2, @1];
            break;
        case kCVPixelFormatType_32ARGB:
            rgbChannelMap = @[@1, @2, @3];
            break;
        default:
            break;
    }
    NSMutableData *inputData = [[NSMutableData alloc] initWithCapacity:count];
    for (int pixelIndex = 0; pixelIndex < count/imageChannel; pixelIndex++) {
        NSInteger offset = pixelIndex * imageChannel;
        
        Float32 red = baseAddress[offset+[rgbChannelMap[0] intValue]];
        Float32 green = baseAddress[offset+[rgbChannelMap[1] intValue]];
        Float32 blue = baseAddress[offset+[rgbChannelMap[2] intValue]];
        
        Float32 red1 = red - 123;
        Float32 green1 = green - 117;
        Float32 blue1 = blue - 104;

        [inputData appendBytes:&blue1 length:sizeof(blue1)];
        [inputData appendBytes:&green1 length:sizeof(green1)];
        [inputData appendBytes:&red1 length:sizeof(red1)];
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return inputData;
}

@end
