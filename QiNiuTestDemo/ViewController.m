//
//  ViewController.m
//  QiNiuTestDemo
//
//  Created by Martin.liu on 17/5/15.
//  Copyright © 2017年 MXR. All rights reserved.
//

#import "ViewController.h"
#import <QiniuSDK.h>
#import "NSObject+MXRModel.h"
#import "GTMBase64.h"
#include <CommonCrypto/CommonCrypto.h>

@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (strong, nonatomic) IBOutlet UILabel *tipLabel;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UIImageView *testImageView;


- (IBAction)clickChooseButtonAction:(id)sender;
- (IBAction)clickUploadButtonAction:(id)sender;

@end

@implementation ViewController
{
    UIImage *chooseImage;
    QNUploadManager *uploadManager;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    uploadManager = [[QNUploadManager alloc] init];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)clickChooseButtonAction:(id)sender {
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    
    imagePickerController.delegate = self;
    
//    imagePickerController.allowsEditing = YES;
    
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self presentViewController:imagePickerController animated:YES completion:^{
        
    }];
    
}

- (IBAction)clickUploadButtonAction:(id)sender {
    [self testUpload];
}



#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info

{
    
    [self dismissViewControllerAnimated:YES completion:^{
        
        
        
    }];
    
    chooseImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    self.imageView.image = chooseImage;
}



- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker

{
    
    [self dismissViewControllerAnimated:YES completion:^{
        
        
        
    }];
}


- (void)testUpload
{
    NSData *imageData = UIImagePNGRepresentation(chooseImage);
    if (!imageData) imageData = UIImageJPEGRepresentation(chooseImage, 1.0f);
    if (!imageData)
    {
        NSLog(@"no image data");
        return ;
    }

    NSString *dnsPath = @"http://opzkfp9iw.bkt.clouddn.com/";
    
    NSString *key = [NSString stringWithFormat:@"testimage%d", arc4random()];
//    QNUploadOption *op = [[QNUploadOption alloc]initWithMime:nil progressHandler:nil params:nil checkCrc:NO cancellationSignal:nil];
    NSString *token = [self tokeyWithKey:key];
    __weak __typeof(self) weakSelf = self;
    [uploadManager putData:imageData key:key token:token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        if (info.ok) {
            NSLog(@"upload image success !");
            NSString *imageUrl = [dnsPath stringByAppendingPathComponent:key];
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageUrl]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.tipLabel.text = imageUrl;
                    weakSelf.testImageView.image = [UIImage imageWithData:data];
                });
            });
        }
        else
        {
            weakSelf.tipLabel.text = [info.error localizedDescription];
            NSLog(@"upload image error : %@", [info.error localizedDescription]);
        }
    } option:nil];
}

- (NSString *)tokeyWithKey:(NSString *)key
{
    NSString *dirName = @"qiniudatabase-testuploadimage";
    time_t deadline;
    time(&deadline);//返回当前系统时间
    //@property (nonatomic , assign) int expires; 怎么定义随你...
    deadline += 3600; // +3600秒,即默认token保存1小时.
    
    NSNumber *deadlineNumber = [NSNumber numberWithLongLong:deadline];
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    //users是我开辟的公共空间名（即bucket），aaa是文件的key，
    //按七牛“上传策略”的描述：    <bucket>:<key>，表示只允许用户上传指定key的文件。在这种格式下文件默认允许“修改”，若已存在同名资源则会被覆盖。如果只希望上传指定key的文件，并且不允许修改，那么可以将下面的 insertOnly 属性值设为 1。
    //所以如果参数只传users的话，下次上传key还是aaa的文件会提示存在同名文件，不能上传。
    //传users:aaa的话，可以覆盖更新，但实测延迟较长，我上传同名新文件上去，下载下来的还是老文件。
    NSString *scope = [NSString stringWithFormat:@"%@:%@", dirName, key];
    [dic setObject:scope forKey:@"scope"];//根据
    
    [dic setObject:deadlineNumber forKey:@"deadline"];
    NSString *json = [dic mxr_modelToJSONString];
    NSString *policy = json;
    NSString *ak = @"mLga6crN2fig3wowP2q8yxFc7UgK2eM4kimy9CyC";
    NSString *sk = @"f090_rWsVuEPYoFMK-TTLiJqW7vnMqKDkF69v-cA";
    
    const char *secretKeyStr = [sk UTF8String];
    
    NSData *policyData = [policy dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *encodedPolicy = [GTMBase64 stringByWebSafeEncodingData:policyData padded:TRUE];
    const char *encodedPolicyStr = [encodedPolicy cStringUsingEncoding:NSUTF8StringEncoding];
    
    char digestStr[CC_SHA1_DIGEST_LENGTH];
    bzero(digestStr, 0);
    
    CCHmac(kCCHmacAlgSHA1, secretKeyStr, strlen(secretKeyStr), encodedPolicyStr, strlen(encodedPolicyStr), digestStr);
    
    NSString *encodedDigest = [GTMBase64 stringByWebSafeEncodingBytes:digestStr length:CC_SHA1_DIGEST_LENGTH padded:TRUE];
    
    NSString *token = [NSString stringWithFormat:@"%@:%@:%@",  ak, encodedDigest, encodedPolicy];
    
    return token;//得到了token

    
}


@end
