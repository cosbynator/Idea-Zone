//
//  AIBIdeaZonesViewController.m
//  Idea Box
//
//  Created by Thomas Dimson on 12/25/13.
//  Copyright (c) 2013 Thomas Dimson. All rights reserved.
//

#import "AIBIdeaZonesViewController.h"
#import "AIBIdeaZoneManager.h"
#import "AIBIdeaZoneDescriptor.h"
#import "AIBIdeaZoneViewController.h"
#import "AIBAlerts.h"
#import "UIAlertView+Blocks.h"
#import "AIBIdeaZonesTableViewCell.h"
#import "UINavigationBar+AIBExtensions.h"
#import "AIBPathViewStates.h"
#import "MBProgressHUD.h"
#import <Dropbox/Dropbox.h>
#import <EXTScope.h>

@implementation AIBIdeaZonesViewController {
    NSMutableArray *_zones;
    BOOL _signingOut;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _signingOut = NO;
    }
    return self;
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    // HACK HACK HACK
    [[self tableView] reloadData];
}

- (void) viewDidLoad {
    [super viewDidLoad];
    if([[AIBIdeaZoneManager sharedInstance] completedInitialSync]) {
        [self loadRefreshControl];
    }
}

- (void) loadRefreshControl {
    if(self.refreshControl) {
        return;
    }
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl setAttributedTitle:[[NSAttributedString  alloc] initWithString:@"Refresh zones"]];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [self setRefreshControl:refreshControl];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _zones = [@[] mutableCopy];
    [[[self navigationController] navigationBar] resetTints];
    [self refresh];
}

- (void) refresh {
    __block BOOL loadingCancelled = NO;
    
    if(![[AIBIdeaZoneManager sharedInstance] completedInitialSync]) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:[[UIApplication sharedApplication] delegate].window
 animated:YES];
        hud.labelText = @"Initializing from Dropbox";
        hud.detailsLabelText = @"(may take a few minutes)";
    }
    
    @weakify(self)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @strongify(self)
        DBError *error;
        NSMutableArray *zones = [[[AIBIdeaZoneManager sharedInstance] zones:&error] mutableCopy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:[[UIApplication sharedApplication] delegate].window animated:YES];
            [self loadRefreshControl];
            if(error) {
                if(self && [self isViewLoaded] && [[self view] window] && [[self navigationController] topViewController] == self && !_signingOut) {
                    [AIBAlerts showErrorAlert:error];
                }
            } else {
                loadingCancelled = YES;
               
                self->_zones = zones;
                [[self refreshControl] setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Refresh zones"]];
                [[self tableView] reloadData];
                [[self refreshControl] endRefreshing];
                
              
            }
        });
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.6 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if(loadingCancelled) {
            return;
        }

        [[self tableView] setContentOffset:CGPointMake(0, -self.topLayoutGuide.length) animated:YES];
        [[self refreshControl] beginRefreshing];
    });

}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_zones count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if([indexPath row] >= [_zones count]) {
        NSLog(@"Bad state: asked for an idea zone beyond the index");
        return nil;
    }

    AIBIdeaZoneDescriptor *zone = _zones[(NSUInteger) [indexPath row]];
    AIBIdeaZonesTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdeaZoneCell"];
    [cell setIdeaZone:zone];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier:@"PushIdeaZone" sender:self];
}

- (IBAction)addButtonPressed:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Zone Name"
                                                    message:@"Enter your idea zone name" delegate:self
                                          cancelButtonTitle:@"Cancel" otherButtonTitles:@"Okay", nil];
    [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
    }else {
        NSString *zoneName = [[alertView textFieldAtIndex:0] text];
        DBError *error;
        [[AIBIdeaZoneManager sharedInstance] addZone:zoneName error:&error];
        if(error) {
            [AIBAlerts showErrorAlert:error];
        } else {
            [self refresh];
        }
    }
}

#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue identifier] isEqualToString:@"PushIdeaZone"]) {
        AIBIdeaZoneViewController *dst = [segue destinationViewController];
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        AIBIdeaZoneDescriptor *zone = _zones[(NSUInteger) [indexPath row]];
        [[[AIBIdeaZoneManager sharedInstance] pathViewStates] markViewed:[zone fileInfo] sync:YES];
        [dst setIdeaZone:zone];
    }
}

- (IBAction)signOutPressed:(id)sender {
    [UIAlertView showWithTitle:@"Sign Out?" message:@"Are you sure you want to sign out?" cancelButtonTitle:@"No"
             otherButtonTitles:@[@"Yes"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if(buttonIndex > 0) {
            _signingOut = YES;
            [self performSegueWithIdentifier:@"SignOutSegue" sender:self];
        }
    }];
}

@end
