//
//  INSOGameEditViewController.m
//  ScorebookLite
//
//  Created by James Dabrowski on 9/26/15.
//  Copyright © 2015 Intangible Software. All rights reserved.
//

#import "UIColor+INSOScorebookColor.h"

#import "MensLacrosseStatsAppDelegate.h"

#import "INSOGameEditViewController.h"
#import "INSOPlayerCollectionViewCell.h"
#import "INSOStatCollectionViewCell.h"
#import "INSOMensLacrosseStatsConstants.h"
#import "INSOEventArrayFactory.h"
#import "INSOEventTranslator.h"
#import "INSOHeaderCollectionReusableView.h"

#import "Game.h"
#import "RosterPlayer.h"


typedef NS_ENUM(NSUInteger, INSOPlayerStatSegment) {
    INSOPlayerStatSegmentPlayer,
    INSOPlayerStatSegmentStats
};

static NSString * const INSOPlayerCellIdentifier = @"PlayerCell";
static NSString * const INSOStatCellIdentifier = @"StatCell";
static NSString * const INSOHeaderViewIdentifier = @"HeaderView";

@interface INSOGameEditViewController () <UINavigationBarDelegate, UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
// IBOutlet
@property (nonatomic, weak) IBOutlet UIBarButtonItem* cancelButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem* doneButton;

@property (nonatomic, weak) IBOutlet UITextField* gameDateTimeField;
@property (nonatomic, weak) IBOutlet UITextField* homeTeamField;
@property (nonatomic, weak) IBOutlet UITextField* visitingTeamField;
@property (nonatomic, weak) IBOutlet UITextField* locationField;

@property (nonatomic, weak) IBOutlet UISegmentedControl* playerStatSegmentedControl;

@property (nonatomic, weak) IBOutlet UICollectionView* playerStatCollectionView; 

// IBActions
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
- (IBAction)switchPlayerStatSegment:(id)sender;

// Private Properties
@property (nonatomic) UIToolbar* datePickerToolbar;
@property (nonatomic) UIDatePicker* datePicker;
@property (nonatomic) NSManagedObjectContext* managedObjectContext;
@property (nonatomic) NSArray* playersArray;
@property (nonatomic) NSArray* statsArray;
@property (nonatomic) INSOEventArrayFactory* eventArrayFactory;
@property (nonatomic) INSOEventTranslator* eventTranslator;

// Private Methods
- (void)configureView;

- (void)configurePlayerCell:(INSOPlayerCollectionViewCell*)cell atIndexPath:(NSIndexPath*)indexPath;
- (void)configureStatCell:(INSOStatCollectionViewCell*)cell atIndexPath:(NSIndexPath*)indexPath;

- (BOOL)shouldEnableDoneButton;
- (void)dateChanged;
- (void)doneSettingDate;

- (NSString*)gameDateAsString;

- (void)addPlayerToGameWithNumber:(NSNumber*)number;
- (void)removePlayerFromGameWithNumber:(NSNumber*)number;


@end

@implementation INSOGameEditViewController
#pragma mark - Lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.playerStatCollectionView.allowsMultipleSelection = YES;
    
    [self configureView]; 
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - IBActions
- (void)cancel:(id)sender
{
    // Discard any changes that may have been made.
    if ([self.game hasChanges]) {
        [self.managedObjectContext rollback];
    }
    
    // And go away.
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)done:(id)sender
{
    // Just save the changes that have already been made.
    NSError* error = nil;
    if (![self.managedObjectContext save:&error]) {
        NSLog(@"Error saving changes to game: %@", error.localizedDescription);
    }

    // Now dismiss
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)switchPlayerStatSegment:(id)sender
{
    [self.playerStatCollectionView reloadData]; 
}

#pragma mark - Private Properties
- (UIToolbar*)datePickerToolbar
{
    if (!_datePickerToolbar) {
        _datePickerToolbar = [[UIToolbar alloc] init];
        
        UIBarButtonItem* spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem* doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSettingDate)];
        
        _datePickerToolbar.items = @[spacer, doneButton];
        _datePickerToolbar.tintColor = [UIColor scorebookBlue];
        [_datePickerToolbar sizeToFit];
    }
    return _datePickerToolbar;
}
- (UIDatePicker*)datePicker
{
    if (!_datePicker) {
        _datePicker = [[UIDatePicker alloc] init];
        _datePicker.datePickerMode = UIDatePickerModeDateAndTime;
        _datePicker.minuteInterval = 15;
        _datePicker.date = self.game.gameDateTime;
        [_datePicker addTarget:self action:@selector(dateChanged) forControlEvents:UIControlEventValueChanged];
    }
    return _datePicker;
}

- (NSManagedObjectContext*)managedObjectContext
{
    if (!_managedObjectContext) {
        MensLacrosseStatsAppDelegate* appDelegate = [[UIApplication sharedApplication] delegate];
        _managedObjectContext = appDelegate.managedObjectContext;
    }
    return _managedObjectContext;
}

- (NSArray*)playersArray
{
    if (!_playersArray) {
        NSMutableArray* tempArray = [NSMutableArray new];
        for (NSInteger playerNumber = 0; playerNumber < 100; playerNumber++) {
            [tempArray addObject:[NSNumber numberWithInteger:playerNumber]];
        }
        _playersArray = tempArray;
    }
    return _playersArray; 
}

- (NSArray*)statsArray
{
    if (!_statsArray) {
        _statsArray = [self.eventArrayFactory allEvents];
    }
    return _statsArray;
}

- (INSOEventArrayFactory*)eventArrayFactory
{
    if (!_eventArrayFactory) {
        _eventArrayFactory = [[INSOEventArrayFactory alloc] init];
    }
    return _eventArrayFactory;
}

- (INSOEventTranslator*)eventTranslator
{
    if (!_eventTranslator) {
        _eventTranslator = [[INSOEventTranslator alloc] init];
    }
    return _eventTranslator;
}

#pragma mark - Private Methods
- (void)configureView
{
    self.gameDateTimeField.text = [self gameDateAsString];
    self.gameDateTimeField.inputView = self.datePicker;
    self.gameDateTimeField.inputAccessoryView = self.datePickerToolbar;
    
    self.homeTeamField.text = self.game.homeTeam;
    self.visitingTeamField.text = self.game.visitingTeam;
    self.locationField.text = self.game.location;
    
    self.doneButton.enabled = [self shouldEnableDoneButton]; 
}

- (void)configurePlayerCell:(INSOPlayerCollectionViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSNumber* playerNumber = self.playersArray[indexPath.row];
    
    cell.playerNumberLabel.text = [NSString stringWithFormat:@"%@", playerNumber];

    if ([self.game rosterContainsPlayerWithNumber:playerNumber]) {
        RosterPlayer* player = [self.game playerWithNumber:playerNumber];
        if (!player.isDeleted) {
            cell.selected = YES;
            [self.playerStatCollectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
        }
    }
}

- (void)configureStatCell:(INSOStatCollectionViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSNumber* eventCode = self.statsArray[indexPath.section][indexPath.row];
    cell.statNameLabel.text = [self.eventTranslator titleForEventCode:eventCode]; 
}

- (BOOL)shouldEnableDoneButton
{
    NSString* homeString = [self.homeTeamField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString* visitingString = [self.visitingTeamField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    return ([homeString length] > 0) && ([visitingString length] > 0);
}

- (void)dateChanged
{
    // Update the label and the game
    self.game.gameDateTime = self.datePicker.date;
    self.gameDateTimeField.text = [self gameDateAsString];
}

- (NSString*)gameDateAsString
{
    NSString* dateFormat = [NSDateFormatter dateFormatFromTemplate:@"Mdyy" options:0 locale:[NSLocale currentLocale]];
    NSString* timeFormat = [NSDateFormatter dateFormatFromTemplate:@"hmma" options:0 locale:[NSLocale currentLocale]];
    NSString* dateTimeFormat = [NSString stringWithFormat:@"%@' at '%@", dateFormat, timeFormat];
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:dateTimeFormat];
    return [formatter stringFromDate:self.game.gameDateTime];
}

- (void)doneSettingDate
{
    [self.homeTeamField becomeFirstResponder]; 
}

- (void)addPlayerToGameWithNumber:(NSNumber *)number
{
    RosterPlayer* rosterPlayer = [RosterPlayer rosterPlayerWithNumber:number inManagedObjectContext:self.managedObjectContext];
    [self.game addPlayersObject:rosterPlayer];
}

- (void)removePlayerFromGameWithNumber:(NSNumber *)number
{
    // Gotta be a bit more careful here.
    RosterPlayer* playerToDelete = [self.game playerWithNumber:number];
    [self.game.teamPlayer addEvents:playerToDelete.events];
    
    [self.managedObjectContext deleteObject:playerToDelete];
}

#pragma mark - Delegate Methods
- (UIBarPosition)positionForBar:(id<UIBarPositioning>)bar
{
    return UIBarPositionTopAttached; 
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField endEditing:YES];
    
    self.doneButton.enabled = [self shouldEnableDoneButton];
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if ([textField isEqual:self.gameDateTimeField]) {
        // Set in object when picker changed.
        [self.homeTeamField becomeFirstResponder];
    } else if ([textField isEqual:self.homeTeamField]) {
        self.game.homeTeam = [self.homeTeamField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self.visitingTeamField becomeFirstResponder];
    } else if ([textField isEqual:self.visitingTeamField]) {
        self.game.visitingTeam = [self.visitingTeamField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self.locationField becomeFirstResponder];
    } else if ([textField isEqual:self.locationField]) {
        self.game.location = [self.locationField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [textField resignFirstResponder];
    }
}

#pragma mark - UICollectionViewDelegate
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [self.statsArray count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.playerStatSegmentedControl.selectedSegmentIndex == INSOPlayerStatSegmentPlayer) {
        return [self.playersArray count];
    } else {
        return [self.statsArray[section] count];
    }
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.playerStatSegmentedControl.selectedSegmentIndex == INSOPlayerStatSegmentPlayer) {
        INSOPlayerCollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:INSOPlayerCellIdentifier forIndexPath:indexPath];
        [self configurePlayerCell:cell atIndexPath:indexPath];
        return cell;
    } else {
        INSOStatCollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:INSOStatCellIdentifier forIndexPath:indexPath];
        [self configureStatCell:cell atIndexPath:indexPath];
        return cell;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.playerStatSegmentedControl.selectedSegmentIndex == INSOPlayerStatSegmentPlayer) {
        NSNumber* number = self.playersArray[indexPath.row];
        
        if (![self.game rosterContainsPlayerWithNumber:number]) {
            [self addPlayerToGameWithNumber:number];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.playerStatSegmentedControl.selectedSegmentIndex == INSOPlayerStatSegmentPlayer) {
        NSNumber* number = self.playersArray[indexPath.row];
        
        if ([self.game rosterContainsPlayerWithNumber:number]) {
            [self removePlayerFromGameWithNumber:number];
        }
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.playerStatSegmentedControl.selectedSegmentIndex == INSOPlayerStatSegmentPlayer) {
        return CGSizeMake(50.0, 50.0);
    } else {
        CGFloat collectionWidth = collectionView.frame.size.width;
        UICollectionViewFlowLayout* flowLayout = (UICollectionViewFlowLayout*)collectionViewLayout;
        collectionWidth -= (flowLayout.sectionInset.left + flowLayout.sectionInset.right);
        return CGSizeMake(collectionWidth, 50.0); 
    }
}

- (UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    INSOHeaderCollectionReusableView* header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:INSOHeaderViewIdentifier forIndexPath:indexPath];
    
    // Configure the header
    header.leftTitleLabel.text = [self.eventTranslator titleForCategoryAtIndex:indexPath.section];
    
    return header;
}

@end
