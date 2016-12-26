//
//  ViewController.m
//  iOS10NanoFreeCrashFixDemo
//
//  Created by ChengJianFeng on 2016/12/26.
//  Copyright © 2016年 ChengJianFeng. All rights reserved.
//

#import "ViewController.h"
#import <vector>

@interface ViewController ()

@end

@implementation ViewController
{
    std::vector<uintptr_t>ptrs;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
#define NANO_MAX (256)
    while(1){
        uintptr_t ptr= (uintptr_t)malloc(NANO_MAX+1);
        ptrs.push_back(ptr);
        if(ptr>>28 == 0x17)
        {
            break;
        }
    }
#undef NANO_MAX
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
