public class CaseTriggerHandler {
    
    public static void handleAfterInsert(List<Case> newCases) {
        CaseToNCService.processCasesForCreate(newCases);
    }
    
    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        CaseToNCService.processCasesForUpdate(newCases, oldMap);
    }
}