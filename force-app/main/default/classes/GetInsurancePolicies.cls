public with sharing class GetInsurancePolicies {

    @InvocableMethod(
        label='Get Insurance Policies'
        description='Returns a formatted summary of active insurance policies for a named account holder. Designed for the Agentforce Account Briefing subagent.'
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
            if (String.isBlank(req.accountId)) {
                res.isSuccess = false;
                res.errorMessage = 'accountId is required.';
                return res;
            }

            List<Account> matches = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :req.accountId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (matches.isEmpty()) {
                res.isSuccess = false;
                res.errorMessage = 'No account found with Id: ' + req.accountId;
                return res;
            }

            List<InsurancePolicy> policies = [
                SELECT PolicyName, PolicyType, Status,
                       PremiumAmount, PremiumFrequency,
                       EffectiveDate, ExpirationDate
                FROM InsurancePolicy
                WHERE NameInsuredId = :matches[0].Id
                AND Status = 'In Force'
                WITH SYSTEM_MODE
                ORDER BY ExpirationDate ASC
            ];

            res.policySummary = formatPolicies(matches[0].Name, policies);
            res.isSuccess = true;

        } catch (Exception e) {
            res.isSuccess = false;
            res.errorMessage = e.getMessage();
            res.errorType = e.getTypeName();
        }
        return res;
    }

    private static String formatPolicies(String accountName, List<InsurancePolicy> policies) {
        if (policies.isEmpty()) {
            return accountName + ' has no active policies.';
        }
        String out = accountName + ' — Active Policies (' + policies.size() + '):\n';
        for (Integer i = 0; i < policies.size(); i++) {
            InsurancePolicy p = policies[i];
            String name = String.isNotBlank(p.PolicyName) ? p.PolicyName : 'Policy ' + (i + 1);
            out += (i + 1) + '. ' + name + ' (' + p.PolicyType + ')';
            if (p.PremiumAmount != null) {
                out += ' — $' + p.PremiumAmount.setScale(0) + '/' + p.PremiumFrequency;
            }
            if (p.ExpirationDate != null) {
                out += ' — Expires: ' + ((Datetime) p.ExpirationDate).format('M/d/yyyy');
            }
            out += '\n';
        }
        return out;
    }

    public class Request {
        @InvocableVariable(
            label='accountId'
            description='Salesforce Account Id of the policyholder.'
            required=true
        )
        public String accountId;
    }

    public class Response {
        @InvocableVariable(
            label='policySummary'
            description='Formatted plain-text summary of the account holder\'s active insurance policies.'
        )
        public String policySummary;

        @InvocableVariable(label='isSuccess' description='Whether the action completed without errors.')
        public Boolean isSuccess;

        @InvocableVariable(label='errorMessage' description='Error details if the action failed.')
        public String errorMessage;

        @InvocableVariable(label='errorType' description='Exception type name if the action failed.')
        public String errorType;
    }
}