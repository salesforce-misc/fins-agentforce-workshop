public with sharing class INS_GetBeneficiariesByPolicy {
    public INS_GetBeneficiariesByPolicy() {

    }

    public class Request {
        @InvocableVariable(label='Policy Id')
        public String policyId;
    }


    @InvocableMethod(label='Get Beneficiaries')
    public static List<String> getBeneficiaries(List<Request> requests) {
        List<String> policyIds = new List<String>();
        for (Request p : requests) {
            policyIds.add(p.policyId);
        }
        List<InsurancePolicyParticipant> beneficiaries = new List<InsurancePolicyParticipant>();
        Map<String, List<InsurancePolicyParticipant>>  policyParticipantsMap = new Map<String, List<InsurancePolicyParticipant>>();
        beneficiaries = [
            SELECT Id, Name, PrimaryParticipantAccount.Name, Role, BeneficiarySharePercentage, InsurancePolicyId
            FROM InsurancePolicyParticipant 
            WHERE InsurancePolicyId in :policyIds AND Role = 'Beneficiary'
        ];
        for (InsurancePolicyParticipant beneficiary : beneficiaries) {
            String policyId = beneficiary.InsurancePolicyId;
            List<InsurancePolicyParticipant> beneficiariesForPolicy = policyParticipantsMap.get(policyId);
            if (beneficiariesForPolicy == null) {
                beneficiariesForPolicy = new List<InsurancePolicyParticipant>();
                beneficiariesForPolicy.add(beneficiary);
                policyParticipantsMap.put(policyId, beneficiariesForPolicy);
            } else {
                beneficiariesForPolicy.add(beneficiary);
            }
        }
        List<String> retvals = new List<String>();
        for (String policyId : policyIds) {
            List<InsurancePolicyParticipant> participants = policyParticipantsMap.get(policyId);
            String participantsJSON = JSON.serialize(participants);
            retvals.add(participantsJSON);

        }

        return retvals;
    }
}