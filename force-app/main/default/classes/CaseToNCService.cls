public with sharing class CaseToNCService {

    public static void processCasesForCreate(List<Case> cases) {
        if (cases == null || cases.isEmpty() || !PermissionService.currentUserHasPermissionSet(Label.Case_Permission_Set_Api_Name))
        {
            return;
        }
        
        List<Case> eligibleCases = new List<Case>();

        for (Case c : cases) {
            if (shouldCreateNC(c)) 
            {
                eligibleCases.add(c);
            }
        }

        if (!eligibleCases.isEmpty()) {
            createNCsAndLinkToCases(eligibleCases);
        }
    }

    public static void processCasesForUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        if (newCases == null || newCases.isEmpty() || !PermissionService.currentUserHasPermissionSet(Label.Case_Permission_Set_Api_Name)) {
            return;
        }
        
        List<Case> createList = new List<Case>();
        List<Case> updateList = new List<Case>();
        Set<Id> ncIdsToUpdate = new Set<Id>();

        for (Case c : newCases) {
            Case oldC = oldMap.get(c.Id);
            
            // Prevent trigger recursion caused by the update operation within the after update context
            if (oldC.SQX_NC_Reference__c == null && c.SQX_NC_Reference__c != null) {
                continue;
            }

            if (shouldCreateNC(c)) {
                createList.add(c);
            } else if (shouldUpdateExistingNC(c, oldC)) {
                updateList.add(c);
                ncIdsToUpdate.add(c.SQX_NC_Reference__c);
            }
        }

        if (!createList.isEmpty()) {
            createNCsAndLinkToCases(createList);
        }

        if (!updateList.isEmpty()) {
            updateExistingNCs(updateList, ncIdsToUpdate);
        }
    }


     // Creates new Nonconformance records and links them to the provided Cases
    private static void createNCsAndLinkToCases(List<Case> cases) {
        List<SQX_Nonconformance__c> ncsToInsert = new List<SQX_Nonconformance__c>();
        
        for (Case c : cases) {
            ncsToInsert.add(buildNCFromCase(c));
        }
        
        insert ncsToInsert;
        update buildCasesToLinkNC(cases, ncsToInsert);
    }
    

     // Updates existing Nonconformance records based on Case changes
    private static void updateExistingNCs(List<Case> casesToUpdate, Set<Id> ncIdsToUpdate) {
        Map<Id, SQX_Nonconformance__c> ncMap = new Map<Id, SQX_Nonconformance__c>(
            [SELECT Id, Title__c, Description__c, Priority__c 
             FROM SQX_Nonconformance__c 
             WHERE Id IN :ncIdsToUpdate LIMIT 10000]
        );

        List<SQX_Nonconformance__c> updatedNCs = new List<SQX_Nonconformance__c>();
        
        for (Case c : casesToUpdate) {
            SQX_Nonconformance__c nc = ncMap.get(c.SQX_NC_Reference__c);
            if (nc == null) {
                continue;
            }

            if (applyChangesIfDifferent(nc, c)) {
                updatedNCs.add(nc);
            }
        }

        if (!updatedNCs.isEmpty()) {
            update updatedNCs;
        }
    }


    private static Boolean shouldCreateNC(Case c) {
        return c.Type == 'Problem' && c.SQX_NC_Reference__c == null;
    }

    private static Boolean shouldUpdateExistingNC(Case c, Case oldC) {
        return c.Type == 'Problem' &&
               c.SQX_NC_Reference__c != null &&
               (
                   c.Subject != oldC.Subject ||
                   c.Description != oldC.Description ||
                   c.Priority != oldC.Priority
               );
    }

    private static SQX_Nonconformance__c buildNCFromCase(Case c) {
        return new SQX_Nonconformance__c(
            Priority__c = c.Priority,
            Title__c = c.Subject,
            Description__c = c.Description,
            QMS_Reference_Number__c = c.CaseNumber
        );
    }

    private static List<Case> buildCasesToLinkNC(List<Case> cases, List<SQX_Nonconformance__c> ncs) {
        List<Case> updates = new List<Case>();
        for (Integer i = 0; i < cases.size(); i++) {
            updates.add(new Case(
                Id = cases[i].Id,
                SQX_NC_Reference__c = ncs[i].Id
            ));
        }
        return updates;
    }

    private static Boolean applyChangesIfDifferent(SQX_Nonconformance__c nc, Case c) {
        Boolean changed = false;

        if (nc.Title__c != c.Subject) {
            nc.Title__c = c.Subject;
            changed = true;
        }
        if (nc.Description__c != c.Description) {
            nc.Description__c = c.Description;
            changed = true;
        }
        if (nc.Priority__c != c.Priority) {
            nc.Priority__c = c.Priority;
            changed = true;
        }
        return changed;
    }
}