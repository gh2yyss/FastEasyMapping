//
// Created by zen on 15/06/14.
// Copyright (c) 2014 Yalantis. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import <MagicalRecord/CoreData+MagicalRecord.h>
#import <CMFactory/CMFixture.h>

#import "Person.h"
#import "FEMManagedObjectMapping.h"
#import "FEMCache.h"
#import "MappingProvider.h"
#import "Car.h"
#import "FEMManagedObjectDeserializer.h"
#import "FEMRelationship.h"


SPEC_BEGIN(FEMCacheSpec)
    __block NSManagedObjectContext *context = nil;


    beforeEach(^{
        [MagicalRecord setDefaultModelFromClass:[self class]];
        [MagicalRecord setupCoreDataStackWithInMemoryStore];

        context = [NSManagedObjectContext MR_rootSavingContext];
    });

    afterEach(^{
        context = nil;
        [MagicalRecord cleanUp];
    });

    describe(@"init", ^{
        it(@"should store NSManagedObjectContext", ^{
            id representation = [CMFixture buildUsingFixture:@"Car"];
            id mapping = [MappingProvider carMapping];

            FEMCache *cache = [[FEMCache alloc] initWithMapping:mapping
                                         externalRepresentation:representation
                                                        context:context];

            [[cache.context should] equal:context];
        });
    });

    describe(@"object retrieval", ^{
        __block NSDictionary *representation = nil;
        __block FEMManagedObjectMapping *mapping = nil;
        __block FEMCache *cache = nil;
        beforeEach(^{
            representation = @{
                @"id": @1,
                @"model": @"i30",
                @"year": @"2013"
            };
            mapping = [MappingProvider carMappingWithPrimaryKey];

            cache = [[FEMCache alloc] initWithMapping:mapping externalRepresentation:representation context:context];
        });
        afterEach(^{
            mapping = nil;
            representation = nil;
            cache = nil;
        });

        it(@"should return nil for missing object", ^{
            [[@([Car MR_countOfEntitiesWithContext:context]) should] beZero];
            [[[cache existingObjectForRepresentation:representation mapping:mapping] should] beNil];

            id missingRepresentation = @{
                @"id": @1,
                @"model": @"i30",
                @"year": @"2013"
            };

            [[[cache existingObjectForRepresentation:missingRepresentation mapping:mapping] should] beNil];
        });

        it(@"should add objects", ^{
            [[@([Car MR_countOfEntitiesWithContext:context]) should] beZero];
            [[[cache existingObjectForRepresentation:representation mapping:mapping] should] beNil];
            
            Car *car = [FEMManagedObjectDeserializer deserializeObjectExternalRepresentation:representation
                                                                                usingMapping:mapping
                                                                                     context:context];

            [cache addExistingObject:car usingMapping:mapping];
            [[[cache existingObjectForRepresentation:representation mapping:mapping] should] equal:car];
        });

        it(@"should return registered object", ^{
            [[@([Car MR_countOfEntitiesWithContext:context]) should] beZero];

            Car *car = [FEMManagedObjectDeserializer deserializeObjectExternalRepresentation:representation
                                                                                usingMapping:mapping
                                                                                     context:context];

            [[@(car.objectID.isTemporaryID) should] beTrue];
            [[[context objectRegisteredForID:car.objectID] should] equal:car];

            [[[cache existingObjectForRepresentation:representation mapping:mapping] should] equal:car];
        });

        it(@"should return saved object", ^{
            [[@([Car MR_countOfEntitiesWithContext:context]) should] beZero];

            Car *car = [FEMManagedObjectDeserializer deserializeObjectExternalRepresentation:representation
                                                                                usingMapping:mapping
                                                                                     context:context];
            [[@(car.objectID.isTemporaryID) should] beTrue];
            [context MR_saveToPersistentStoreAndWait];
            [[@([Car MR_countOfEntitiesWithContext:context]) should] equal:@1];

            [context reset];

            [[[context objectRegisteredForID:car.objectID] should] beNil];

            car = [Car MR_findFirstInContext:context];
            [[[cache existingObjectForRepresentation:representation mapping:mapping] should] equal:car];
        });
    });

    describe(@"nested object retrieval", ^{
        __block FEMCache *cache = nil;
        __block NSDictionary *representation = nil;
        __block FEMManagedObjectMapping *mapping = nil;
        __block FEMManagedObjectMapping *carMapping = nil;

        beforeEach(^{
            representation = [CMFixture buildUsingFixture:@"PersonWithCar_1"];
            mapping = [MappingProvider personWithCarMapping];

            cache = [[FEMCache alloc] initWithMapping:mapping externalRepresentation:representation context:context];
            carMapping = (id) [mapping relationshipForProperty:@"car"].objectMapping;
        });

        afterEach(^{
            cache = nil;
            representation = nil;
            mapping = nil;
            carMapping = nil;
        });

        it(@"should return nil for missing nested object", ^{
            [FEMManagedObjectDeserializer deserializeObjectExternalRepresentation:representation
                                                                     usingMapping:mapping
                                                                          context:context];
            id missingObjectRepresentation = @{@"id": @2};

            [[[cache existingObjectForRepresentation:missingObjectRepresentation mapping:carMapping] should] beNil];
        });

        it(@"should return existing nested object", ^{
            Person *person = [FEMManagedObjectDeserializer deserializeObjectExternalRepresentation:representation
                                                                                      usingMapping:mapping
                                                                                           context:context];
            [[[cache existingObjectForRepresentation:representation[@"car"] mapping:carMapping] should] equal:person.car];
        });
    });

SPEC_END
