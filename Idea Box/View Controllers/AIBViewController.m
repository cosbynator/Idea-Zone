//
//  AIBViewController.m
//  Idea Box
//
//  Created by Thomas Dimson on 12/24/13.
//  Copyright (c) 2013 Thomas Dimson. All rights reserved.
//

#import "AIBViewController.h"
#import "AIBAnimation.h"
#import "AIBIdeaZoneManager.h"
#import "AIBConstants.h"
#import "UIImage+AIBExtensions.h"
#import <Dropbox/Dropbox.h>
#import <EXTScope.h>

@interface AIBViewController ()
- (IBAction)connectDropboxButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIButton *connectDropboxButton;
@property (weak, nonatomic) IBOutlet UIButton *splashButton;

@end

@implementation AIBViewController {
    BOOL _expectConnect;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _expectConnect = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(performSignIn) name:kAIBDropboxOpenURLOccurred object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [_splashButton setImage:[UIImage launchImage] forState:UIControlStateNormal];
    _connectDropboxButton.alpha = 0.0;
    _errorLabel.hidden = YES;


}

- (void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    _connectDropboxButton.translatesAutoresizingMaskIntoConstraints = YES;
    
    CGFloat regionStart = ([UIScreen mainScreen].bounds.size.height / 2 + 175);
    _connectDropboxButton.frame = CGRectMake(0, regionStart + ([UIScreen mainScreen].bounds.size.height - regionStart - 30) / 2,
                                             [UIScreen mainScreen].bounds.size.width, 30);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self performSignIn];
    [UIView animateWithDuration:0.3 delay:0.5 options:0 animations:^{
        _connectDropboxButton.alpha = 1.0;
    } completion:nil];
}


- (BOOL)shouldAutorotate {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}


- (void) performSignIn {
    if (![self isViewLoaded ]|| ![[self view] window]) {
        return;
    }

    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    if(account) {
        NSError *error = [[AIBIdeaZoneManager sharedInstance] handleAuthorized];
        if(error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription]
                                       delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil] show];
        }
        if(_expectConnect) {
            [self performSegueWithIdentifier:@"PresentMainTableView" sender:self];
        } else {
            [self performSegueWithIdentifier:@"PresentMainTableViewNoAnimate" sender:self];
        }
    } else if (_expectConnect) {
        _errorLabel.text = @"Unauthorized - please reconnect";
        _errorLabel.hidden = NO;
        [AIBAnimation shakeAnimation:self.view.layer];
    }

    _expectConnect = NO;
    [[DBAccountManager sharedManager] removeObserver:self];
}


- (IBAction)connectDropboxButtonPressed:(id)sender {
    [[[DBAccountManager sharedManager] linkedAccount] unlink];
    [[DBAccountManager sharedManager] linkFromController:self];
    _expectConnect = YES;
}

-(IBAction)signOut:(UIStoryboardSegue *)segue {
    [[[DBAccountManager sharedManager] linkedAccount] unlink];
}
@end
