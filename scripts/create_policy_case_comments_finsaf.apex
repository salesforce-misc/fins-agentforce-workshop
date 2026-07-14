List<Case> seededCases = [
    SELECT Id, Subject
    FROM Case
    WHERE SourceId = '0YTam000000AxeqGAC'
      AND CreatedBy.Username = 'fins@agent.force'
      AND CreatedDate = TODAY
];

Map<String, String> commentsBySubject = new Map<String, String>{
    'Account profile update needed after move to a new residence' =>
        'Internal review notes: customer identity was verified through standard authentication. Address change affects correspondence preferences, paper suppression settings, and future policy notice routing. Monitor the next outbound billing cycle to confirm downstream document generation reflects the updated profile.',
    'Portal access and household contact maintenance request' =>
        'Internal review notes: possible mismatch between household relationship records and portal user mapping. Digital support should confirm if each household member has a distinct contact and login pairing before re-enabling shared alerts. Consider escalated troubleshooting if account notification sync does not refresh within one business day.',
    'Request to add newly purchased vehicle to existing auto coverage' =>
        'Internal review notes: customer request likely requires same-day endorsement handling due to lienholder evidence-of-insurance requirement. Underwriting should verify VIN details, replacement timing, and whether temporary overlap with the traded vehicle is allowable under current policy terms.',
    'Policy change request for driver removal and garaging location update' =>
        'Internal review notes: hold endorsement processing until proof of separate insurance and out-of-state residency are received for the removed driver. Seasonal garaging may impact rating territory and underwriting classification, so premium recalculation will be needed before finalizing the change.',
    'Escalation requested on open claim for hail damage settlement' =>
        'Internal review notes: claims servicing delay is creating customer frustration and possible repair storage cost exposure. Supervisor follow-up should focus on estimate approval status, document indexing, and final ownership of the claim work item. Recommend callback within one business day to prevent further escalation.',
    'Question on claim reimbursement for rental reimbursement benefit' =>
        'Internal review notes: reimbursement dispute appears tied to misunderstanding of covered versus optional rental charges. Keep a clear benefits breakdown on file in case the customer reopens the matter or requests formal escalation through claims accounting.',
    'Follow-up on supplemental claim documents and injury paperwork' =>
        'Internal review notes: uploaded documents may have been received but not yet associated to the claims work queue. Claims operations should confirm whether the affidavit needs notarization and communicate the precise next review milestone once the documents are indexed.',
    'Review of annuity allocation options before upcoming retirement' =>
        'Internal review notes: customer is clearly moving from growth-oriented positioning toward preservation and income stability. Investment servicing should prepare product-specific transfer constraints, fixed-account availability, and any surrender implications before the next client callback.',
    'Inquiry about cash value movement into a fixed option' =>
        'Internal review notes: likely suitable for investment servicing rather than general billing or claims support. Validate whether there are blackout windows, minimum transfer amounts, or tax-reporting implications before providing final instructions to the policyholder.',
    'Beneficiary update needed after recent marriage' =>
        'Internal review notes: beneficiary change is straightforward but should be documented carefully because spouse and contingent child designations were both requested. Retain image or form evidence in the event of future estate or claims disputes.',
    'Clarification request on trust beneficiary designation wording' =>
        'Internal review notes: trust naming conventions must match legal documents exactly to reduce downstream probate or claims delays. Keep the trust-certification requirement visible in the case summary in case the customer follows up after submitting incomplete paperwork.',
    'Partial withdrawal request from policy cash value' =>
        'Internal review notes: customer weighed withdrawal versus policy loan and selected withdrawal after impact explanation. Retain servicing notes about tax-reporting and death-benefit implications in case the customer later questions the reduction in policy values.',
    'Request for rollover or exchange guidance on existing value' =>
        'Internal review notes: transaction may require coordination with external receiving institution and product eligibility review. Verify whether outstanding drafts or surrender charges could delay processing before committing to a customer timeline.',
    'Autopay failed and premium payment is now overdue' =>
        'Internal review notes: this case carries retention risk because the customer is concerned about lapse. Billing team should confirm the grace-period save, replacement payment posting, and future autopay schedule synchronization with the new banking instructions.',
    'Refund question after premium overpayment and cancellation adjustment' =>
        'Internal review notes: customer wants transparency into earned-premium proration and refund timing. Maintain refund calculation detail in the file in case accounting follow-up is requested or the customer disputes the final returned amount.'
};

List<CaseComment> commentsToInsert = new List<CaseComment>();
for (Case c : seededCases) {
    if (commentsBySubject.containsKey(c.Subject)) {
        commentsToInsert.add(new CaseComment(
            ParentId = c.Id,
            CommentBody = commentsBySubject.get(c.Subject),
            IsPublished = false
        ));
    }
}

insert commentsToInsert;
System.debug('Inserted internal case comments: ' + commentsToInsert.size());
