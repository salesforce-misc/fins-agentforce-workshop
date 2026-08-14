public with sharing class GetInsuranceClaims {

    @InvocableMethod(
        label='Get Insurance Claims'
        description='Returns a formatted summary of recent and open insurance claims for a named account holder. Designed for the Agentforce Account Briefing subagent.'
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

            List<Case> cases = [
                SELECT CaseNumber, Subject, Status, Description, CreatedDate, ClosedDate
                FROM Case
                WHERE AccountId = :matches[0].Id
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];

            res.claimsSummary = formatClaims(matches[0].Name, cases);
            res.isSuccess = true;

        } catch (Exception e) {
            res.isSuccess = false;
            res.errorMessage = e.getMessage();
            res.errorType = e.getTypeName();
        }
        return res;
    }

    private static String formatClaims(String accountName, List<Case> cases) {
        if (cases.isEmpty()) {
            return accountName + ' has no recent claims or service cases.';
        }
        String out = accountName + ' — Recent Claims/Cases (' + cases.size() + '):\n';
        for (Integer i = 0; i < cases.size(); i++) {
            Case c = cases[i];
            out += (i + 1) + '. Case #' + c.CaseNumber + ' — ' + c.Subject;
            out += ' | Status: ' + c.Status;
            out += ' | Reported: ' + c.CreatedDate.format('M/d/yyyy');
            if (c.ClosedDate != null) {
                out += ' | Closed: ' + c.ClosedDate.format('M/d/yyyy');
            }
            if (String.isNotBlank(c.Description)) {
                String summary = c.Description.length() > 100 ? c.Description.substring(0, 100) + '...' : c.Description;
                out += '\n   ' + summary;
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
            label='claimsSummary'
            description='Formatted plain-text summary of the account holder\'s recent and open insurance claims or service cases.'
        )
        public String claimsSummary;

        @InvocableVariable(label='isSuccess' description='Whether the action completed without errors.')
        public Boolean isSuccess;

        @InvocableVariable(label='errorMessage' description='Error details if the action failed.')
        public String errorMessage;

        @InvocableVariable(label='errorType' description='Exception type name if the action failed.')
        public String errorType;
    }
}