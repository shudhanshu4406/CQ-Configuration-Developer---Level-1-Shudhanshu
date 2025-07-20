@isTest
public class CaseTriggerTest {
        
    @TestSetup
    static void setupTestData() {
        User adminUser = TestDataFactory.createAdminUser();
        insert adminUser;
        User standardUser = TestDataFactory.createStandardUser();
        insert standardUser;
        System.runAs(adminUser) {
            TestDataFactory.assignPermissionSet(adminUser, TestDataFactory.getCasePermissionSetName());
        }
    }
    
    // ========== ADMIN USER TESTS ==========
    
    @isTest
    static void testAdminUser_InsertProblemCase_CreatesNC() {
        User adminUser = [SELECT Id FROM User WHERE LastName = 'AdminUser' LIMIT 1];
        
        Test.startTest();
        System.runAs(adminUser) {
            Case problemCase = TestDataFactory.createProblemCase('Admin Problem Case');
            insert problemCase;
            Case insertedCase = [SELECT Id, Subject, SQX_NC_Reference__c FROM Case WHERE Id = :problemCase.Id];
            Assert.isNotNull(insertedCase.SQX_NC_Reference__c, 'Admin user should create NC for Problem case');
            
            SQX_Nonconformance__c nc = [SELECT Id, Title__c, Description__c, Priority__c, QMS_Reference_Number__c 
                                       FROM SQX_Nonconformance__c 
                                       WHERE Id = :insertedCase.SQX_NC_Reference__c];
            
            Assert.areEqual(problemCase.Subject, nc.Title__c, 'NC Title should match Case Subject');
            Assert.areEqual(problemCase.Description, nc.Description__c, 'NC Description should match Case Description');
            Assert.areEqual(problemCase.Priority, nc.Priority__c, 'NC Priority should match Case Priority');
            Assert.isNotNull(nc.QMS_Reference_Number__c, 'QMS Reference should be populated');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testAdminUser_UpdateProblemCase_UpdatesNC() {
        User adminUser = [SELECT Id FROM User WHERE LastName = 'AdminUser' LIMIT 1];
        Case problemCase;
        
        System.runAs(adminUser) {
            problemCase = TestDataFactory.createProblemCase('Original Problem');
            insert problemCase;
        }
        
        Case caseWithNC = [SELECT Id, SQX_NC_Reference__c FROM Case WHERE Id = :problemCase.Id];
        Assert.isNotNull(caseWithNC.SQX_NC_Reference__c, 'NC should be created initially');
        
        Test.startTest();
        System.runAs(adminUser) {
            problemCase.Subject = 'Updated Problem Title';
            problemCase.Description = 'Updated Description';
            problemCase.Priority = 'High';
            update problemCase;
            
            SQX_Nonconformance__c updatedNC = [SELECT Id, Title__c, Description__c, Priority__c 
                                              FROM SQX_Nonconformance__c 
                                              WHERE Id = :caseWithNC.SQX_NC_Reference__c];
            
            Assert.areEqual('Updated Problem Title', updatedNC.Title__c, 'Admin should be able to update NC Title');
            Assert.areEqual('Updated Description', updatedNC.Description__c, 'Admin should be able to update NC Description');
            Assert.areEqual('High', updatedNC.Priority__c, 'Admin should be able to update NC Priority');
        }
        Test.stopTest();
    }
    
    
    // ========== STANDARD USER TESTS ==========
    
    @isTest
    static void testStandardUser_WithoutPermission_DoesNotCreateNC() {
        User standardUser = [SELECT Id FROM User WHERE LastName = 'StandardUser' LIMIT 1];
        
        Test.startTest();
        System.runAs(standardUser) {
            Case problemCase = TestDataFactory.createProblemCase('Standard User Problem');
            insert problemCase;
            Case insertedCase = [SELECT Id, SQX_NC_Reference__c FROM Case WHERE Id = :problemCase.Id];
            Assert.isNull(insertedCase.SQX_NC_Reference__c, 'Standard user without permission should not create NC');
        }
        Test.stopTest();
        
        List<SQX_Nonconformance__c> ncs = [SELECT Id FROM SQX_Nonconformance__c];
        Assert.areEqual(0, ncs.size(), 'No NC should be created without permission');
    }
    
    @isTest
    static void testStandardUser_WithPermission_CreatesNC() {
        User standardUser = [SELECT Id FROM User WHERE LastName = 'StandardUser' LIMIT 1];
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            TestDataFactory.assignPermissionSet(standardUser, TestDataFactory.getCasePermissionSetName());
        }
        
        Test.startTest();
        System.runAs(standardUser) {
            Case problemCase = TestDataFactory.createProblemCase('Standard User With Permission');
            insert problemCase;
            Case insertedCase = [SELECT Id, SQX_NC_Reference__c FROM Case WHERE Id = :problemCase.Id];
            Assert.isNotNull(insertedCase.SQX_NC_Reference__c, 'Standard user with permission should create NC');
            
            SQX_Nonconformance__c nc = [SELECT Id, Title__c FROM SQX_Nonconformance__c WHERE Id = :insertedCase.SQX_NC_Reference__c];
            Assert.areEqual(problemCase.Subject, nc.Title__c, 'NC should be created correctly');
        }
        Test.stopTest();
    }
        
    // ========== RECURSION PREVENTION TESTS ==========
    
    @isTest
    static void testRecursionPrevention_InternalUpdate_DoesNotTriggerLoop() {
        User adminUser = [SELECT Id FROM User WHERE LastName = 'AdminUser' LIMIT 1];
        Case problemCase;
        
        System.runAs(adminUser) {
            problemCase = TestDataFactory.createProblemCase('Recursion Test');
            insert problemCase;
        }
        
        Test.startTest();
        System.runAs(adminUser) {
            Integer initialNCCount = [SELECT COUNT() FROM SQX_Nonconformance__c];
            problemCase.Subject = 'Recursion Test'; 
            update problemCase;
            Integer finalNCCount = [SELECT COUNT() FROM SQX_Nonconformance__c];
            Assert.areEqual(initialNCCount, finalNCCount, 'Internal updates should not create additional NCs');
        }
        Test.stopTest();
    }
    
    // ========== NEGATIVE TEST CASES ==========
    
    @isTest
    static void testNegative_NullOrEmptyInput_HandledGracefully() {
        Test.startTest();
        
        CaseToNCService.processCasesForCreate(null);
        CaseToNCService.processCasesForCreate(new List<Case>());
        CaseToNCService.processCasesForUpdate(null, new Map<Id, Case>());
        CaseToNCService.processCasesForUpdate(new List<Case>(), null);
        
        Test.stopTest();
        
        List<SQX_Nonconformance__c> ncs = [SELECT Id FROM SQX_Nonconformance__c];
        Assert.areEqual(0, ncs.size(), 'No NCs should be created from null inputs');
    }
    
  
}