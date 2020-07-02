//
//  PhotoVC.m
//  TestTensorflow
//
//  Created by Ghost on 2020/7/1.
//  Copyright © 2020 Ghost. All rights reserved.
//

#import "NXTFModelDataHandler.h"
#import "PhotoVC.h"

@interface PhotoVC ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property(nonatomic, weak) IBOutlet UIImageView *imageView;
@property(nonatomic, weak) IBOutlet UITextView *textView;

@end

@implementation PhotoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

#pragma mark - Private
- (void)_dealWithImage:(UIImage*)_image {
    self.imageView.image = _image;
    [NXTFModelDataHandler classifyImage:_image completion:^(NSArray * _Nullable array, NSError * _Nullable error, CFTimeInterval timeInterval) {
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
    }];
}

#pragma mark - Btn Clicks
- (IBAction)_albumBtnClick:(id)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.modalPresentationStyle = UIModalPresentationFullScreen;
    imagePicker.delegate = self;
    imagePicker.allowsEditing = NO;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:imagePicker animated:YES completion:^{
        
    }];
}

- (IBAction)_cameraBtnClick:(id)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.modalPresentationStyle = UIModalPresentationFullScreen;
    imagePicker.delegate = self;
    imagePicker.allowsEditing = NO;
    imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear]) {
        imagePicker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
    } else {
        imagePicker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    }
    [self presentViewController:imagePicker animated:YES completion:^{
        
    }];
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = nil;
    if (picker.allowsEditing) {
        image = info[UIImagePickerControllerEditedImage];
    } else {
        image = info[UIImagePickerControllerOriginalImage];
    }
    [self _dealWithImage:image];
    [picker dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
        
    }];
}

@end

