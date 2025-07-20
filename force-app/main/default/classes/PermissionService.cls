public class PermissionService {
    public static Boolean currentUserHasPermissionSet(String permissionSetName) {
        List<PermissionSetAssignment> psaList = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.Name = :permissionSetName
            LIMIT 1
        ];
        return !psaList.isEmpty();
    }
}