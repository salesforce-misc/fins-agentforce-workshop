public without sharing class InsurancePolicyDetailsService {
    
    // Inner class to represent a payment
    public class ClaimDetail {
        @InvocableVariable public String Id;
        @InvocableVariable public String ClaimNumber;
        @InvocableVariable public Decimal ActualAmount;
        @InvocableVariable public Decimal ApprovedAmount;
        @InvocableVariable public Decimal EstimatedAmount;
        @InvocableVariable public String AccountId;
        @InvocableVariable public String PolicyNumberId;
        @InvocableVariable public String LossType;
        @InvocableVariable public Datetime lossDate;
        @InvocableVariable public String Severity;
        @InvocableVariable public String Status;
        @InvocableVariable public String FnolChannel;
        @InvocableVariable public String ClaimReason;
    }
    
    // Inner class to represent a payment
    public class PaymentDetail {
        @InvocableVariable public String Id;
        @InvocableVariable public String name;
        @InvocableVariable public Decimal fee;
        @InvocableVariable public String institution;
        @InvocableVariable public String insurancePolicyId;
        @InvocableVariable public String owner;
        @InvocableVariable public Decimal paymentAmount;
        @InvocableVariable public Date paymentDate;
        @InvocableVariable public String paymentMethod;
        @InvocableVariable public String paymentStatus;
        @InvocableVariable public String payor;
        @InvocableVariable public Decimal totalPayment;
    }
    
    // Inner class to represent a Coverage
    public class CoverageDetail {
        @InvocableVariable public String Id;
        @InvocableVariable public String CoverageName;
        @InvocableVariable public Decimal PremiumAmount;
        @InvocableVariable public Decimal LimitAmount;
        @InvocableVariable public String InsurancePolicyId;
    }
    
    // Inner class to represent the response for each Insurance Policy
    public class PolicyDetail {
        @InvocableVariable public String Id;
        @InvocableVariable public String Name;
        @InvocableVariable public String policyName;
        @InvocableVariable public String PolicyType;
        @InvocableVariable public String PolicyTerm;
        @InvocableVariable public String status;
        @InvocableVariable public Datetime EffectiveDate;
        @InvocableVariable public Datetime ExpirationDate;
        @InvocableVariable public Datetime RenewalDate;
        @InvocableVariable public Decimal PremiumAmount;
        @InvocableVariable public Decimal TaxAmount;
        @InvocableVariable public Decimal FeeAmount;  
        @InvocableVariable public String BillingFrequency;  
        @InvocableVariable public String PaymentMethod;  
        @InvocableVariable public List<ClaimDetail> claims;
        @InvocableVariable public List<PaymentDetail> payments;
        @InvocableVariable public List<CoverageDetail> coverages;
    }
    
    // Invocable method to expose this service to flows
    @InvocableMethod(label='Get Active Insurance Policy Details' description='Returns claim and payment details for given insurance policies')
    public static List<String> getInsurancePolicyClaims(List<List<String>> listOfPolicyIds) {
        
        // Get the first list from the List<List<String>> input
        List<String> policyIds = listOfPolicyIds.size() > 0 ? listOfPolicyIds[0] : new List<String>();
        
        // List to hold results
        List<PolicyDetail> policyDetails = new List<PolicyDetail>();
        
        if (policyIds.isEmpty()) {
            return new List<String>{ '[]' }; // Return an empty JSON array if no policy IDs provided
        }
        
        // Query InsurancePolicyPayment__c related to Insurance_Policy__c
        List<Claim> claims = [
            SELECT Id,Name,ActualAmount,ApprovedAmount,EstimatedAmount,AccountId,PolicyNumberId,
            LossType,lossDate,Severity,Status,FnolChannel,ClaimReason
            FROM Claim 
            WHERE PolicyNumberId IN :policyIds
        ];
        
        // Map to group payments by policyId
        Map<Id, List<Claim>> claimsByPolicy = new Map<Id, List<Claim>>();
        
        // Organize payments by policy
        for (Claim clm : claims) {
            if (!claimsByPolicy.containsKey(clm.PolicyNumberId)) {
                claimsByPolicy.put(clm.PolicyNumberId, new List<Claim>());
            }
            claimsByPolicy.get(clm.PolicyNumberId).add(clm);
        }
        
        // Query InsurancePolicyPayment__c related to Insurance_Policy__c
        List<Insurance_Policy_Payment__c> payments = [
            SELECT Id,Insurance_Policy__c, Name, Fee__c, Institution__c, CreatedById, LastModifiedById, OwnerId,
                   Payment_Amount__c, Payment_Date__c, Payment_Method__c, Payment_Status__c, Payor__c, Total_Payment__c
            FROM Insurance_Policy_Payment__c 
            WHERE Insurance_Policy__c IN :policyIds
        ];
        
        // Map to group payments by policyId
        Map<Id, List<Insurance_Policy_Payment__c>> paymentsByPolicy = new Map<Id, List<Insurance_Policy_Payment__c>>();
        
        // Organize payments by policy
        for (Insurance_Policy_Payment__c payment : payments) {
            if (!paymentsByPolicy.containsKey(payment.Insurance_Policy__c)) {
                paymentsByPolicy.put(payment.Insurance_Policy__c, new List<Insurance_Policy_Payment__c>());
            }
            paymentsByPolicy.get(payment.Insurance_Policy__c).add(payment);
        }

        // Query InsurancePolicyCoverage related to InsurancePolicy
        List<InsurancePolicyCoverage> coverages = [
            SELECT Id, CoverageName, PremiumAmount, LimitAmount, InsurancePolicyId
            FROM InsurancePolicyCoverage
            WHERE InsurancePolicyId IN :policyIds
        ];

        // Map to group coverages by policyId
        Map<Id, List<InsurancePolicyCoverage>> coveragesByPolicy = new Map<Id, List<InsurancePolicyCoverage>>();
        for (InsurancePolicyCoverage cov : coverages) {
            if (!coveragesByPolicy.containsKey(cov.InsurancePolicyId)) {
                coveragesByPolicy.put(cov.InsurancePolicyId, new List<InsurancePolicyCoverage>());
            }
            coveragesByPolicy.get(cov.InsurancePolicyId).add(cov);
        }
        
        // Query InsurancePolicy for details
        List<InsurancePolicy> policies = [SELECT Id,PolicyName,Name,PolicyType,PolicyTerm,status,EffectiveDate,ExpirationDate,RenewalDate,
                                          StandardPremiumAmount,StandardTaxAmount,StandardFeeAmount,PremiumFrequency,Payment_Method__c
                                          FROM InsurancePolicy WHERE Id IN :policyIds];
        
        // Construct the response
        for (InsurancePolicy policy : policies) {
            PolicyDetail policyDetail = new PolicyDetail();
            policyDetail.Id = policy.Id;
            policyDetail.Name = policy.PolicyName;
            policyDetail.policyName = policy.Name;
            policyDetail.PolicyType = policy.PolicyType;
            policyDetail.PolicyTerm = policy.PolicyTerm;
            policyDetail.status = policy.status;
            policyDetail.EffectiveDate = policy.EffectiveDate;
            policyDetail.ExpirationDate = policy.ExpirationDate;
            policyDetail.RenewalDate = policy.RenewalDate;
            policyDetail.PremiumAmount = policy.StandardPremiumAmount;
            policyDetail.TaxAmount = policy.StandardTaxAmount;
            policyDetail.FeeAmount = policy.StandardFeeAmount;
            policyDetail.PaymentMethod = policy.Payment_Method__c;
            policyDetail.BillingFrequency = policy.PremiumFrequency;
            policyDetail.claims = new List<ClaimDetail>();
            policyDetail.payments = new List<PaymentDetail>();
            policyDetail.coverages = new List<CoverageDetail>();
            
            if (paymentsByPolicy.containsKey(policy.Id)) {
                for (Insurance_Policy_Payment__c payment : paymentsByPolicy.get(policy.Id)) {
                    PaymentDetail paymentDetail = new PaymentDetail();
                    paymentDetail.Id = payment.Id;
                    paymentDetail.name = payment.Name;
                    paymentDetail.fee = payment.Fee__c;
                    paymentDetail.institution = payment.Institution__c;
                    paymentDetail.insurancePolicyId = payment.Insurance_Policy__c;
                    paymentDetail.owner = payment.OwnerId;
                    paymentDetail.paymentAmount = payment.Payment_Amount__c;
                    paymentDetail.paymentDate = payment.Payment_Date__c;
                    paymentDetail.paymentMethod = payment.Payment_Method__c;
                    paymentDetail.paymentStatus = payment.Payment_Status__c;
                    paymentDetail.payor = payment.Payor__c;
                    paymentDetail.totalPayment = payment.Total_Payment__c;
                    
                    policyDetail.payments.add(paymentDetail);
                }
            } 

            if (coveragesByPolicy.containsKey(policy.Id)) {
                for (InsurancePolicyCoverage cov : coveragesByPolicy.get(policy.Id)) {
                    CoverageDetail coverageDetail = new CoverageDetail();
                    coverageDetail.Id = cov.Id;
                    coverageDetail.CoverageName = cov.CoverageName;
                    coverageDetail.PremiumAmount = cov.PremiumAmount;
                    coverageDetail.LimitAmount = cov.LimitAmount;
                    coverageDetail.InsurancePolicyId = cov.InsurancePolicyId;

                    policyDetail.coverages.add(coverageDetail);
                }
            }
            
            if (claimsByPolicy.containsKey(policy.Id)) {
                for (Claim clm : claimsByPolicy.get(policy.Id)) {
                    ClaimDetail claimDetail = new ClaimDetail();
                    claimDetail.Id = clm.Id;
                    claimDetail.ActualAmount = clm.ActualAmount;
                    claimDetail.ClaimNumber = clm.Name;
                    claimDetail.EstimatedAmount = clm.EstimatedAmount;
                    claimDetail.AccountId = clm.AccountId;
                    claimDetail.PolicyNumberId = clm.PolicyNumberId;
                    claimDetail.LossType = clm.LossType;
                    claimDetail.lossDate = clm.lossDate;
                    claimDetail.Severity = clm.Severity;
                    claimDetail.Status = clm.Status;
                    claimDetail.FnolChannel = clm.FnolChannel;
                    claimDetail.ClaimReason = clm.ClaimReason;
                    
                    policyDetail.claims.add(claimDetail);
                }
            }
            
            policyDetails.add(policyDetail);
        }
        
        // Convert the result to JSON string and return to flow
        List<String> jsonResponse = new List<String>();
        jsonResponse.add(JSON.serialize(policyDetails));
        System.debug(jsonResponse);
        return jsonResponse;
    }
}