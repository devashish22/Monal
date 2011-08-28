//
//  callScreen.m
//  Monal
//
//  Created by Anurodh Pokharel on 8/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "callScreen.h"

@implementation callScreen

-(void) init:(UINavigationController*) nav
{
   navigationController=nav;
    
	[self initWithNibName:@"callScreen" bundle:nil];
    
	//self.title=@" "; 
    
   
    
   
}

-(void) show
{
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
    
    [navigationController presentModalViewController:self animated:YES];
   
    
    //for ipad show differently 
    if([[tools machine] isEqualToString:@"iPad"])
    {
        self.modalPresentationStyle=UIModalPresentationFormSheet; 
    }
    
    
	[pool release];
     
}


-(IBAction) endPress
{
 debug_NSLog(@"end pressed"); 
    
      [navigationController dismissModalViewControllerAnimated:YES];
   //terminate voip call here too 
    
   
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    debug_NSLog(@"call screen did  appear");
}

- (void)viewDidUnload
{
 debug_NSLog(@"call screen did  disappear");
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return true;
}

@end
