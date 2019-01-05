//
//  PreferencesViewController.m
//  iCatalogo
//
//  Created by Albertomac on 01/10/13.
//  Copyright (c) 2013 Albertomac. All rights reserved.
//

#import "DatabaseViewController.h"

@interface DatabaseViewController ()
@end

@implementation DatabaseViewController

@synthesize segmented, servers, broadcaster, indexServer;
@synthesize ipField, updateButton, progressView, progressLabel;
@synthesize showSubproducts, goBackInsert, selectAutomatic;



#pragma -mark ServerMethods

- (void)resetSegmented
{
    for (int i = 0; i < indexServer; ++i) {
        [segmented setTitle:@"" forSegmentAtIndex:i];
        [segmented setEnabled:NO forSegmentAtIndex:i];
    }
    
    [segmented setSelectedSegmentIndex:0];
}

- (void)tcpBroadcaster:(YLTCPBroadcaster *)broadcaster didFoundHost:(NSString *)host
{
//    NSLog(@"Host found: %@", host);
    if ([host isEqualToString:@"192.168.1.1"] || [host isEqualToString:@"192.168.1.254"]) {
        return;
    }
    
    if(indexServer < 2) {
        [servers addObject:@{@"server" : host, @"ip" : host}];
        [segmented setTitle:host forSegmentAtIndex:indexServer];
        [segmented setEnabled:YES forSegmentAtIndex:indexServer];
        
        if(indexServer == 0)
            [self changeIndexServer:segmented];
        
        indexServer++;
    }
}

- (IBAction)searchServers:(id)sender
{
//    NSLog(@"button pressed");
    [updateButton setUserInteractionEnabled:NO];
    [self resetSegmented];
    [servers removeAllObjects];
    indexServer = 0;
    [broadcaster scanWithPort:80 timeoutInterval:4 completionHandler:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [updateButton setUserInteractionEnabled:YES];
    });
}

- (IBAction)changeIndexServer:(id)sender
{
    NSInteger index = [segmented selectedSegmentIndex];
    [ipField setText:[[servers objectAtIndex:index] valueForKey:@"ip"]];
}

#pragma -mark ButtonsMethods

- (IBAction)operationButtonClicked:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Attenzione!" message:@"Perderai tutti gli ordini se non li hai scaricati!" delegate:self cancelButtonTitle:@"Annulla" otherButtonTitles:@"Procedi" , nil];
	[alert setTag:[sender tag]];
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    [self setInteractionEnabled:NO];
    
    if(buttonIndex == 1){
        switch (alertView.tag) {
            case COMPLETE:
                [self updateCompleteFromNet];
                break;
            case NET:
                [self updateFromNet];
                break;
            case FILE:
                [self updateFromFile];
                break;
            case ORDERS:
                [self deleteOrders];
                break;
            case DATABASE:
                [self deleteDatabase];
                break;
        }
    } else {
        [self setInteractionEnabled:YES];
    }
}

- (void)updateCompleteFromNet
{
    NSString *stringUrl = [NSString stringWithFormat:@"http:/%@/getDatabaseComplete.php", [ipField text]];
    [progressView startDownloadFromUrl:stringUrl timeInterval:120];
}

- (void)updateFromNet
{
    NSString *stringUrl = [NSString stringWithFormat:@"http:/%@/getDatabase.php", [ipField text]];
    [progressView startDownloadFromUrl:stringUrl timeInterval:120];
}

- (void)progressviewDidFailDownload
{
    [self setInteractionEnabled:YES];
}

//Metodo delegato della progressview
- (void)progressViewDidSaveFile
{    
    [self updateFromFile];
}

- (void)updateFromFile
{
    if([self deleteDatabase]){
        [self setInteractionEnabled:NO];
        
        [self updateProgressLabelWithText:@"Decomprimo file..."];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths objectAtIndex:0];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:@"update.zip"];
        
        ZipArchive *zipArchive = [[ZipArchive alloc] init];
        [zipArchive UnzipOpenFile:filePath];
        [zipArchive UnzipFileTo:documentsPath overWrite:YES];
        [zipArchive UnzipCloseFile];

        [self updateProgressLabelWithText:@"Aggiornamento database..."];
        XMLParser *parser = [[XMLParser alloc] initWithProgressView:progressView];
        [self updateProgressLabelWithText:[parser parseFile:@"Database.xml"]];
        [self setInteractionEnabled:YES];
    }
}

- (void)deleteOrders
{
    [self updateProgressLabelWithText:@"Cancellazione ordini..."];
    
    NSArray *orders = [[AppDelegate sharedAppDelegate] searchEntity:@"Orders" withPredicate:nil sortedBy:nil];
    NSError *error;
    [[AppDelegate sharedAppDelegate] deleteObjects:orders error:&error];
    
    if(error)
        [self updateProgressLabelWithText:@"Problema cancellazione ordini!"];
    else [self updateProgressLabelWithText:@"Ordini cancellati."];
    
    [self setInteractionEnabled:YES];
}

- (BOOL)deleteDatabase
{
    [self updateProgressLabelWithText:@"Cancellazione database..."];
    
    NSUserDefaults *options = [NSUserDefaults standardUserDefaults];
    [options setBool:YES forKey:searchChanged];
    [options setValue:@"" forKey:searchText];
    [options setInteger:0 forKey:searchColumn];
    [options setInteger:0 forKey:searchSortAttribute];
    
    NSError *error;
    [[AppDelegate sharedAppDelegate] deleteDatabase:&error];
    
    if(error){
        [self updateProgressLabelWithText:@"Problema cancellazione database!"];
        [self setInteractionEnabled:YES];
        return NO;
    } else {
        [self updateProgressLabelWithText:@"Database cancellato."];
        [self setInteractionEnabled:YES];
        return YES;
    }
}

- (IBAction)createOrders:(id)sender
{
    XMLCreator *xmlCreator = [[XMLCreator alloc] init];
    [xmlCreator createXMLOrders];
    [xmlCreator saveWithFileName:@"DatiEsportati.xml"];
}

- (IBAction)sendOrders:(id)sender
{
    XMLCreator *xmlCreator = [[XMLCreator alloc] init];
    [xmlCreator createXMLOrders];
    [xmlCreator saveWithFileName:@"DatiEsportati.xml"];
    
    NSString *stringUrl = [NSString stringWithFormat:@"http:/%@/saveOrders.php", [ipField text]];
    NSURL *url = [NSURL URLWithString:stringUrl];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setTimeoutInterval:120];
    [request setValue:@"text/html; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[xmlCreator data]];
    
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
    
    if([returnString isEqualToString:@"Albertomac"]){
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Ordini esportati correttamente!" delegate:nil cancelButtonTitle:@"Grazie" otherButtonTitles:nil, nil];
        [alert show];
        
    } else {
        
        NSLog(@"%@", returnString);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Attenzione!" message:@"Problema nell'esportazione degli ordini!" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
    }
}


#pragma -mark UITextField DelegateMethods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [[NSUserDefaults standardUserDefaults] setObject:[textField text] forKey:@"ip"];
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [[NSUserDefaults standardUserDefaults] setObject:[textField text] forKey:@"ip"];
}


#pragma -mark SupportMethods

- (void)setInteractionEnabled:(BOOL)boolean
{
    [self.view setUserInteractionEnabled:boolean];
    [self.navigationController.navigationBar setUserInteractionEnabled:boolean];
}

- (void)updateProgressLabelWithText:(NSString *)string
{
    [progressLabel performSelectorInBackground:@selector(setText:) withObject:string];
}

#pragma -mark Application

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:@"Database"];
    
    servers = [[NSMutableArray alloc] init];
    NSString *ip = @"192.168.1.1";//[YLTCPUtils localIp];
    NSString *subnetMask = @"255.255.255.0";//[YLTCPUtils localSubnetMask];
    broadcaster = [[YLTCPBroadcaster alloc] initWithIp:ip subnetMask:subnetMask];
    [broadcaster setDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSUserDefaults *options = [NSUserDefaults standardUserDefaults];
    [ipField setText:[options stringForKey:ip]];
	[showSubproducts setOn:[options boolForKey:showSubproductsOption]];
	[goBackInsert setOn:[options boolForKey:goBackInsertOption]];
	[selectAutomatic setOn:[options boolForKey:selectAutomaticOption]];
    
    [progressView setDelegate:self];
    [progressView setLabel:progressLabel];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)showSubproductValueChanged:(id)sender {
	NSUserDefaults *options = [NSUserDefaults standardUserDefaults];
	[options setBool:[showSubproducts isOn] forKey:showSubproductsOption];
	[options synchronize];
}

- (IBAction)goBackInsertValueChanged:(id)sender
{
	NSUserDefaults *options = [NSUserDefaults standardUserDefaults];
	[options setBool:[goBackInsert isOn] forKey:goBackInsertOption];
	[options synchronize];
}

- (void)selectAutomaticValueChanged:(id)sender
{
	NSUserDefaults *options = [NSUserDefaults standardUserDefaults];
	[options setBool:[selectAutomatic isOn] forKey:selectAutomaticOption];
	[options synchronize];
}


@end
