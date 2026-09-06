public with sharing class GetRenewalPriorities {

    private static final Integer DEFAULT_LOOK_AHEAD_DAYS = 90;
    private static final Integer MAX_RESULTS = 20;

    @InvocableMethod(
        label='Get Renewal Priorities'
        description='Returns a prioritized list of insurance policies expiring within the look-ahead window, sorted by premium change percentage. Designed for Agentforce renewal triage.'
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
            Integer parsedDays = null;
            if (String.isNotBlank(req.lookAheadDays)) {
                try { parsedDays = Integer.valueOf(req.lookAheadDays); } catch (TypeException e) { parsedDays = null; }
            }
            Integer lookAheadDays = (parsedDays != null && parsedDays > 0)
                ? parsedDays
                : DEFAULT_LOOK_AHEAD_DAYS;

            List<InsurancePolicy> policies = queryPolicies(lookAheadDays);

            if (policies.isEmpty()) {
                res.renewalPriorities = 'No active policies are expiring within the next ' + lookAheadDays + ' days.';
                res.isSuccess = true;
                return res;
            }

            List<AccountRenewalSummary> summaries = buildAccountSummaries(policies);
            summaries.sort();
            res.renewalPriorities = formatOutput(summaries, lookAheadDays);
            res.isSuccess = true;

        } catch (Exception e) {
            res.isSuccess = false;
            res.errorMessage = e.getMessage();
            res.errorType = e.getTypeName();
        }
        return res;
    }

    private static List<InsurancePolicy> queryPolicies(Integer lookAheadDays) {
        DateTime today = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        DateTime cutoff = DateTime.newInstance(Date.today().addDays(lookAheadDays), Time.newInstance(23, 59, 59, 0));
        return [
            SELECT Id, Name, PolicyName, PolicyType, Status,
                   PremiumAmount, PreviousPremium,
                   EffectiveDate, ExpirationDate,
                   NameInsuredId, NameInsured.Name
            FROM InsurancePolicy
            WHERE Status = 'In Force'
            AND ExpirationDate >= :today
            AND ExpirationDate <= :cutoff
            WITH SYSTEM_MODE
            ORDER BY ExpirationDate ASC
        ];
    }

    private static List<AccountRenewalSummary> buildAccountSummaries(List<InsurancePolicy> policies) {
        Map<Id, AccountRenewalSummary> byAccount = new Map<Id, AccountRenewalSummary>();

        for (InsurancePolicy p : policies) {
            if (p.NameInsuredId == null) continue;

            if (!byAccount.containsKey(p.NameInsuredId)) {
                AccountRenewalSummary s = new AccountRenewalSummary();
                s.accountId = p.NameInsuredId;
                s.accountName = p.NameInsured?.Name != null ? p.NameInsured.Name : 'Unknown';
                s.policyCount = 0;
                s.soonestExpiry = (Datetime) p.ExpirationDate;
                s.highestPremiumChangePct = 0;
                byAccount.put(p.NameInsuredId, s);
            }

            AccountRenewalSummary s = byAccount.get(p.NameInsuredId);
            s.policyCount++;

            if ((Datetime) p.ExpirationDate < s.soonestExpiry) {
                s.soonestExpiry = (Datetime) p.ExpirationDate;
            }

            Decimal changePct = calculatePremiumChangePct(p.PremiumAmount, p.PreviousPremium);
            if (Math.abs(changePct) > Math.abs(s.highestPremiumChangePct)) {
                s.highestPremiumChangePct = changePct;
            }
        }

        return byAccount.values();
    }

    private static Decimal calculatePremiumChangePct(Decimal current, Decimal prior) {
        if (prior == null || prior == 0 || current == null) return 0;
        return ((current - prior) / prior * 100).setScale(1);
    }

    private static String formatOutput(List<AccountRenewalSummary> summaries, Integer lookAheadDays) {
        Integer cap = Math.min(summaries.size(), MAX_RESULTS);
        String out = 'Renewal Priorities (next ' + lookAheadDays + ' days):\n\n';
        for (Integer i = 0; i < cap; i++) {
            AccountRenewalSummary s = summaries.get(i);
            String direction = s.highestPremiumChangePct > 0 ? '+' : '';
            out += (i + 1) + '. ' + s.accountName
                + ' | Soonest Expiry: ' + s.soonestExpiry.format('M/d/yyyy')
                + ' | Premium Change: ' + direction + s.highestPremiumChangePct + '%'
                + ' | Policies Expiring: ' + s.policyCount
                + '\n';
        }
        return out;
    }

    private class AccountRenewalSummary implements Comparable {
        public Id accountId;
        public String accountName;
        public Integer policyCount;
        public Datetime soonestExpiry;
        public Decimal highestPremiumChangePct;

        public Integer compareTo(Object other) {
            AccountRenewalSummary that = (AccountRenewalSummary) other;
            Decimal absThis = Math.abs(this.highestPremiumChangePct);
            Decimal absThat = Math.abs(that.highestPremiumChangePct);
            if (absThis > absThat) return -1;
            if (absThis < absThat) return 1;
            return 0;
        }
    }

    public class Request {
        @InvocableVariable(
            label='Look Ahead Days'
            description='Number of days from today to look ahead for expiring policies. Defaults to 90 if not provided.'
            required=false
        )
        public String lookAheadDays;
    }

    public class Response {
        @InvocableVariable(
            label='Renewal Priorities'
            description='Formatted numbered list of accounts with expiring policies sorted by premium change %, one row per account, ready for agent narration.'
        )
        public String renewalPriorities;

        @InvocableVariable(label='Success' description='Whether the action completed without errors.')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message' description='Error details if the action failed.')
        public String errorMessage;

        @InvocableVariable(label='Error Type' description='Exception type name if the action failed.')
        public String errorType;
    }
}