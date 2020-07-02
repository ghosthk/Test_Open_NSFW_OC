//
//  ViewController.m
//  TestTensorflow
//
//  Created by Ghost on 2020/7/1.
//  Copyright © 2020 Ghost. All rights reserved.
//

#import "NXTFModelDataHandler.h"
#import "CameraLiveVC.h"
#import "FUOpenGLView.h"
#import "FuCamera.h"

@interface CameraLiveVC () <FUCameraDelegate>

@property(nonatomic, weak) IBOutlet FUOpenGLView *openGLView;
@property(nonatomic, weak) IBOutlet UITextView   *textView;

@property(nonatomic, strong) FUCamera *fuCamera;
@property(nonatomic, assign) BOOL isFront;

@property(nonatomic, assign) BOOL isChecking;

@end

@implementation CameraLiveVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.fuCamera = [[FUCamera alloc] init];
    [self.fuCamera changeCameraInputDeviceisFront:self.isFront];
    self.fuCamera.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.fuCamera startCapture];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.fuCamera stopCapture];
}

#pragma mark - Btn
- (IBAction)_changeCameraClick:(id)sender {
    self.isFront = !self.isFront;
    [self.fuCamera changeCameraInputDeviceisFront:self.isFront];
}

#pragma mark - FUCameraDelegate
- (void)didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self.openGLView displayPixelBuffer:pixelBuffer];
    if (self.isChecking) {
        return;
    }
    self.isChecking = true;
    [self _dealWithSampleBuffer:sampleBuffer completion:^{
        
        self.isChecking = false;
    }];
}

- (void)_dealWithSampleBuffer:(CMSampleBufferRef)sampleBuffer completion:(void(^)(void))completion {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [NXTFModelDataHandler classifyCVPixelBuffer:pixelBuffer completion:^(NSArray * _Nullable array, NSError * _Nullable error, CFAbsoluteTime timeInterval) {
        if (error) {
            self.textView.text = [NSString stringWithFormat:@"Error: %@",error.localizedDescription];
        }else {
            NSMutableString *str = [NSMutableString stringWithFormat:@""];
            for (int i = 0; i < array.count; i ++) {
                [str appendFormat:@"%@: %@\n", i == 0?@"SFW":@"NSFW",array[i]];
            }
            
            [str appendFormat:@"\nDuration: %f\n",timeInterval*1000];
            self.textView.text = str;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (completion) {
                completion();
            }
        });
    }];
}

@end
