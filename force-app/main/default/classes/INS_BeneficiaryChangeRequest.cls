public with sharing class INS_BeneficiaryChangeRequest {
    public INS_BeneficiaryChangeRequest() {

    }

    public class Request {
        @InvocableVariable(label='Policy Id')
        public String policyId;
        @InvocableVariable(label='Beneficiaries')
        public String beneficaries;
    }


    @InvocableMethod(label='Beneficiary Change Request')
    public static List<String> beneficiaryChangeRequest(List<Request> requests) {
        List<String> policyIds = new List<String>();
        List<String> retvals = new List<String>();
        List<Insurance_Beneficary_Change_Request__c> changes = new List<Insurance_Beneficary_Change_Request__c>();

        for (Request p : requests) {
            retvals.add('Beneficiary Change Request successfully submitted to physical mail system.');
            Insurance_Beneficary_Change_Request__c change = new Insurance_Beneficary_Change_Request__c();
            Map<String,Object> formattedReqest = new Map<String,Object>();
            formattedReqest.put('policyId',p.policyId);
            formattedReqest.put('beneficiaries',JSON.deserializeUntyped(p.beneficaries));        
            change.Response__c = JSON.serialize(formattedReqest);
            changes.add(change);
        }
        insert changes;

        return retvals;
    }
}