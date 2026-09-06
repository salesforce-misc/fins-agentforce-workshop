public with sharing class GetPolicyholderDetails {

    @InvocableMethod(
        label='Get Policyholder Details'
        description='Returns a structured JSON summary of an account holder including active insurance policies, premium information, and renewal flags. Designed for Agentforce producer call prep.'
        category='Insurance'
    )
    public static List<Response> execute(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(processRequest(req));
        }
        return responses;
    }

    private static Response processRequest(Request req) {
        Response res = new Response();
        try {
            if (String.isBlank(req.customerName)) {
                res.isSuccess = false;
                res.errorMessage = 'customerName is required.';
                return res;
            }

            List<Account> matches = [
                SELECT Id, Name, Phone, BillingCity, BillingState, BillingPostalCode
                FROM Account
                WHERE Name = :req.customerName
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (matches.isEmpty()) {
                res.isSuccess = false;
                res.errorMessage = 'No account found with name: ' + req.customerName;
                return res;
            }
            Account acct = matches[0];

            List<InsurancePolicy> policies = [
                SELECT Id, Name, PolicyName, PolicyType, Status,
                       PremiumAmount, PreviousPremium, PremiumFrequency,
                       EffectiveDate, ExpirationDate
                FROM InsurancePolicy
                WHERE NameInsuredId = :acct.Id
                AND Status = 'In Force'
                WITH SYSTEM_MODE
                ORDER BY ExpirationDate ASC
            ];

            res.policyholderDetails = buildJson(acct, policies);
            res.customerName = acct.Name;
            res.accountId = acct.Id;
            res.isSuccess = true;

        } catch (Exception e) {
            res.isSuccess = false;
            res.errorMessage = e.getMessage();
            res.errorType = e.getTypeName();
        }
        return res;
    }

    private static String buildJson(Account acct, List<InsurancePolicy> policies) {
        PolicyholderData data = new PolicyholderData();
        data.name = acct.Name;
        data.phone = acct.Phone;
        data.city = acct.BillingCity;
        data.state = acct.BillingState;
        data.postalCode = acct.BillingPostalCode;
        data.activePolicyCount = policies.size();
        data.policies = new List<PolicyData>();

        for (InsurancePolicy p : policies) {
            PolicyData pd = new PolicyData();
            pd.policyName = String.isNotBlank(p.PolicyName) ? p.PolicyName : p.Name;
            pd.policyType = p.PolicyType;
            pd.status = p.Status;
            pd.premiumAmount = p.PremiumAmount;
            pd.premiumFrequency = p.PremiumFrequency;
            if (p.PreviousPremium != null && p.PreviousPremium > 0 && p.PremiumAmount != null) {
                pd.premiumChangePct = ((p.PremiumAmount - p.PreviousPremium) / p.PreviousPremium * 100).setScale(1);
            }
            if (p.ExpirationDate != null) {
                pd.expirationDate = ((Datetime) p.ExpirationDate).format('yyyy-MM-dd');
            }
            data.policies.add(pd);
        }

        return JSON.serialize(data);
    }

    private class PolicyholderData {
        public String name;
        public String phone;
        public String city;
        public String state;
        public String postalCode;
        public Integer activePolicyCount;
        public List<PolicyData> policies;
    }

    private class PolicyData {
        public String policyName;
        public String policyType;
        public String status;
        public Decimal premiumAmount;
        public String premiumFrequency;
        public Decimal premiumChangePct;
        public String expirationDate;
    }

    public class Request {
        @InvocableVariable(
            label='customerName'
            description='Full name of the policyholder (e.g. "Kiran Singh"). Used to look up the account.'
            required=true
        )
        public String customerName;
    }

    public class Response {
        @InvocableVariable(
            label='policyholderDetails'
            description='Structured JSON summary of the policyholder and their active insurance policies, ready for agent narration.'
        )
        public String policyholderDetails;

        @InvocableVariable(
            label='customerName'
            description='Echo of the customerName input. Use to set the AccountName variable.'
        )
        public String customerName;

        @InvocableVariable(
            label='accountId'
            description='Salesforce Account Id of the policyholder. Use to set the AccountId variable for downstream actions.'
        )
        public String accountId;

        @InvocableVariable(label='isSuccess' description='Whether the action completed without errors.')
        public Boolean isSuccess;

        @InvocableVariable(label='errorMessage' description='Error details if the action failed.')
        public String errorMessage;

        @InvocableVariable(label='errorType' description='Exception type name if the action failed.')
        public String errorType;
    }
}