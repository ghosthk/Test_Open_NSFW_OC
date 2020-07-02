//
//  RootVC.m
//  TestTensorflow
//
//  Created by Ghost on 2020/7/1.
//  Copyright © 2020 Ghost. All rights reserved.
//

#import "NXTFModelDataHandler.h"
#import "RootVC.h"
@interface RootVC ()

@end

@implementation RootVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [NXTFModelDataHandler setupModelPath:[[NSBundle mainBundle] pathForResource:@"nsfw" ofType:@"tflite"]];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
