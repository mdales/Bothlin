//
//  ModelCoordinatorDelegate.h
//  Bothlin
//
//  Created by Michael Dales on 30/11/2023.
//

#ifndef ModelCoordinatorDelegate_h
#define ModelCoordinatorDelegate_h

NS_ASSUME_NONNULL_BEGIN

@protocol ModelCoordinatorDelegate <NSObject>

- (void)modelCoordinator:(id)modelCoordinator
               didUpdate:(NSDictionary *)changeNotificationData;

@end

NS_ASSUME_NONNULL_END

#endif /* ModelCoordinatorDelegate_h */
