public with sharing class CaseRoutingInvocable {

    // Input wrapper for Flow
    public class Request {
        @InvocableVariable(required=true)
        public String jsonString;

        @InvocableVariable(required=true)
        public Id caseId;
    }

    // Output wrapper for Flow
    public class Response {
        @InvocableVariable
        public String category;
    }

    // JSON structure wrapper
    public class RoutingPayload {
        public String category;
        public String reason;
    }

    @InvocableMethod(label='Update Case from JSON' description='Parses JSON and updates Case fields')
    public static List<Response> updateCaseFromJson(List<Request> requests) {

        List<Response> responses = new List<Response>();
        Map<Id, Case> casesToUpdate = new Map<Id, Case>();

        // Collect Case IDs
        Set<Id> caseIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.caseId != null) {
                caseIds.add(req.caseId);
            }
        }

        // Query cases once (bulkified)
        Map<Id, Case> existingCases = new Map<Id, Case>(
            [SELECT Id, Type, Routing_Reason__c FROM Case WHERE Id IN :caseIds]
        );

        for (Request req : requests) {
            Response res = new Response();

            if (req == null || req.caseId == null || String.isBlank(req.jsonString)) {
                responses.add(res);
                continue;
            }

            try {
                RoutingPayload payload = (RoutingPayload) JSON.deserialize(
                    req.jsonString,
                    RoutingPayload.class
                );

                if (payload != null && existingCases.containsKey(req.caseId)) {
                    Case c = existingCases.get(req.caseId);

                    if (!String.isBlank(payload.category)) {
                        c.Type = payload.category;
                        res.category = payload.category;
                    }

                    if (!String.isBlank(payload.reason)) {
                        c.Routing_Reason__c = payload.reason;
                    }

                    casesToUpdate.put(c.Id, c);
                }

            } catch (Exception e) {
                // Optionally add logging here
                // e.g., System.debug('JSON parse error: ' + e.getMessage());
            }

            responses.add(res);
        }

        // Perform DML once
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate.values();
        }

        return responses;
    }
}