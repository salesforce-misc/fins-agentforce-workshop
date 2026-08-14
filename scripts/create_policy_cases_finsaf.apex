Id policyId = '0YTam000000AxeqGAC';
Id ownerId = [SELECT Id FROM User WHERE Username = 'fins@agent.force' LIMIT 1].Id;

List<Case> casesToInsert = new List<Case>();

casesToInsert.add(new Case(
    Subject = 'Account profile update needed after move to a new residence',
    Description = 'Policyholder called to report a recent relocation from Sacramento to Walnut Creek and needs the primary mailing address updated across all linked service communications. Customer also wants paper statements turned off, email notifications enabled for billing and claims updates, and the preferred phone number changed to a new mobile device. The customer mentioned that prior correspondence is still being sent to the old residence and wants assurance that future underwriting and policy notices will use the new address immediately.',
    Priority = 'Medium',
    Status = 'Closed - Resolved',
    Origin = 'Phone',
    Comments = 'Validated caller identity and confirmed move date. Address, phone, and communication preferences were updated after verifying the impacted records. Advised customer to allow one billing cycle for all downstream documents to reflect the new profile settings.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Portal access and household contact maintenance request',
    Description = 'Customer sent a web inquiry explaining that the spouse listed on the household profile is no longer receiving shared account notifications in the service portal. They want both household members to retain online access, receive claim alerts, and be able to review policy documents independently. The customer also asked for guidance on whether each person needs a unique login and whether contact permissions can be managed separately.',
    Priority = 'Low',
    Status = 'In Progress',
    Origin = 'Web',
    Comments = 'Case opened for digital support and household profile review. Need to confirm current portal user mappings and whether duplicate contact records are affecting notification delivery. Pending coordination with customer support operations to validate access entitlements.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Request to add newly purchased vehicle to existing auto coverage',
    Description = 'Insured emailed that they purchased a 2026 Subaru Outback over the weekend and need to replace the 2018 vehicle currently shown on the policy. They want full coverage effective immediately because the dealership financed the vehicle and requires updated evidence of insurance. Customer also asked whether the multi-policy discount will remain in place and whether the old vehicle can stay insured for two more days until the title transfer is completed.',
    Priority = 'High',
    Status = 'New',
    Origin = 'Email',
    Comments = 'Needs policy endorsement processing and updated ID cards once underwriting confirms replacement timeline. Verify lienholder requirements and ensure temporary overlapping coverage is permitted under policy rules.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Policy change request for driver removal and garaging location update',
    Description = 'Customer requested removal of an adult child from the household driver list after the child moved to another state and obtained separate insurance. At the same time, the customer wants the garaging address updated because one insured vehicle is now kept at a vacation property several months each year. They are asking whether these changes will affect premium, eligibility, or renewal underwriting review.',
    Priority = 'Medium',
    Status = 'Waiting for Customer',
    Origin = 'Email',
    Comments = 'Requested proof of new insurance for removed driver and clarification on seasonal garaging dates. Waiting on customer documents before underwriting can finalize the policy change.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Escalation requested on open claim for hail damage settlement',
    Description = 'Customer reported that a hail damage claim has been open for more than three weeks and they still have not received a final estimate approval or settlement timeline. They indicated the body shop is holding the repair appointment and storage fees may begin if authorization is delayed further. The customer is frustrated that prior calls produced inconsistent answers on whether supplemental photos were received and whether an adjuster has completed the review.',
    Priority = 'High',
    Status = 'Escalated',
    Origin = 'Phone',
    Comments = 'Customer requested supervisor involvement due to delay and conflicting status updates. Escalated to claims operations for immediate review of estimate approval, document receipt, and repair authorization timeline.',
    SourceId = policyId,
    OwnerId = ownerId,
    IsEscalated = true
));

casesToInsert.add(new Case(
    Subject = 'Question on claim reimbursement for rental reimbursement benefit',
    Description = 'Policyholder submitted receipts for a seven-day rental vehicle after an accident and wants confirmation that reimbursement was issued correctly. The customer noted that the payment received appears lower than expected and asked whether taxes, airport fees, and additional driver charges are covered under the existing endorsement. They also want to know if any remaining amount will be paid separately or if the current reimbursement is considered final.',
    Priority = 'Medium',
    Status = 'Closed',
    Origin = 'Email',
    Comments = 'Claims review confirmed daily reimbursement limit was applied correctly and excluded non-covered optional charges. Closure response sent with line-item explanation and benefits summary showing how the final reimbursable amount was calculated.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Follow-up on supplemental claim documents and injury paperwork',
    Description = 'Customer uploaded additional medical and repair documents connected to an active accident claim and wants to verify they were successfully linked to the file. They are concerned because the portal still shows the claim as awaiting documents even though the upload completed yesterday. Customer also asked whether the injury affidavit needs notarization and whether the adjuster can provide a revised timeline once the new records are reviewed.',
    Priority = 'High',
    Status = 'In Progress',
    Origin = 'Web',
    Comments = 'Documents appear to have been received but indexing into the claim work queue may be delayed. Claims servicing team to verify attachment association and provide updated review ETA to the customer.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Review of annuity allocation options before upcoming retirement',
    Description = 'Customer wants help understanding current annuity allocation percentages, recent market performance impact, and whether a more conservative investment mix is available without triggering surrender charges. They are approaching retirement within the next eighteen months and want to discuss rebalancing strategies that protect principal while still maintaining some growth exposure. The customer asked for a clear explanation of available fixed account options and transfer timing rules.',
    Priority = 'Medium',
    Status = 'On Hold',
    Origin = 'Phone',
    Comments = 'Service case created to coordinate with investment servicing specialist. Awaiting current allocation snapshot and product servicing guidelines before responding with permitted transfer options and timing restrictions.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Inquiry about cash value movement into a fixed option',
    Description = 'Policyholder sent an email asking whether part of the cash value associated with the policy can be reallocated from market-based subaccounts into a fixed option because of increasing volatility. They asked whether the transfer can be performed online, whether there are minimum transfer amounts, and how long the change would take to appear on the next statement. Customer emphasized that preserving value is more important than growth at this stage.',
    Priority = 'Low',
    Status = 'Response Received',
    Origin = 'Email',
    Comments = 'Initial response sent outlining that the request may require product-specific servicing review. Customer replied confirming desire to proceed if no tax consequences are created, so follow-up with investment support is required.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Beneficiary update needed after recent marriage',
    Description = 'Customer requested a change of primary beneficiary on the policy following a recent marriage and wants to replace a previously listed sibling with the new spouse. They also want to keep two children listed as contingent beneficiaries with equal shares. The customer asked whether the update can be processed electronically, whether witness signatures are required, and how long it takes before the new designation is officially reflected.',
    Priority = 'High',
    Status = 'Closed - Resolved',
    Origin = 'Email',
    Comments = 'Beneficiary change form was received, signatures were validated, and records were updated to reflect the new primary and contingent designations. Confirmation letter sent with processing effective date and instructions for retaining copies with estate documents.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Clarification request on trust beneficiary designation wording',
    Description = 'Customer wants to confirm that a recently established family trust can be named correctly as a contingent beneficiary without creating probate complications. They provided the trust name informally in a prior conversation but now want exact guidance on title formatting, trustee naming, and whether additional trust pages must be submitted. Customer is concerned that an incomplete designation could delay future claim processing for heirs.',
    Priority = 'Medium',
    Status = 'Closed',
    Origin = 'Phone',
    Comments = 'Reviewed trust naming requirements and documented exact wording standards. Customer was advised which certification pages are required, and a follow-up packet was sent for future beneficiary designation updates.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Partial withdrawal request from policy cash value',
    Description = 'Customer wants to take a partial withdrawal from available cash value to help cover home renovation expenses and is asking how this would affect death benefit, future policy charges, and annual tax reporting. They specifically requested a net amount estimate after any processing deductions and want to know whether funds can be wired directly to a personal bank account within the same week. The customer is not sure whether a policy loan would be more appropriate than a withdrawal.',
    Priority = 'High',
    Status = 'Closed - Resolved',
    Origin = 'Phone',
    Comments = 'Explained differences between withdrawal and policy loan and provided estimated impact to policy values. Customer elected to proceed with a partial withdrawal after reviewing projected values, and servicing confirmation was issued after processing completion.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Request for rollover or exchange guidance on existing value',
    Description = 'Customer submitted a service request asking whether funds associated with the policy can be moved into another financial product through a rollover or tax-advantaged exchange. They want to understand surrender implications, timing, required forms, and whether the transfer must be initiated by the receiving institution. Customer also asked if current pending premium drafts would interfere with the transaction timeline.',
    Priority = 'Medium',
    Status = 'New',
    Origin = 'Web',
    Comments = 'Requires transaction servicing review and product eligibility validation before next steps can be communicated. Need to confirm whether the requested movement is allowed under the current policy type and existing premium schedule.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Autopay failed and premium payment is now overdue',
    Description = 'Customer noticed that the monthly premium draft did not process from the checking account on file and is worried the policy may lapse if payment is not corrected quickly. They stated the account was recently closed after a bank merger and want to update to a new account while also confirming the exact amount currently due. Customer requested assurance that coverage remains active during the grace period and wants written confirmation once the payment issue is resolved.',
    Priority = 'High',
    Status = 'Closed',
    Origin = 'Phone',
    Comments = 'Banking information was updated and replacement payment was successfully taken during the grace period. Confirmed policy remained active with no lapse and sent written verification of reinstated autopay setup.',
    SourceId = policyId,
    OwnerId = ownerId
));

casesToInsert.add(new Case(
    Subject = 'Refund question after premium overpayment and cancellation adjustment',
    Description = 'Customer believes they overpaid after a mid-term policy cancellation and wants a detailed explanation of the returned premium calculation. They noted that the amount credited to the original payment method appears lower than expected once fees and unused premium were considered. Customer is requesting a breakdown of proration, any earned premium retention, and when the final refund balance will settle.',
    Priority = 'Low',
    Status = 'Closed',
    Origin = 'Email',
    Comments = 'Billing reviewed earned premium, cancellation timing, and payment application history. Refund calculation letter issued with prorated premium explanation and confirmation that no further balance remains pending.',
    SourceId = policyId,
    OwnerId = ownerId
));

Database.SaveResult[] results = Database.insert(casesToInsert, false);
Integer successCount = 0;
for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        successCount++;
        System.debug('Inserted Case Id: ' + results[i].getId() + ' | Subject: ' + casesToInsert[i].Subject);
    } else {
        for (Database.Error err : results[i].getErrors()) {
            System.debug('Failed Case Subject: ' + casesToInsert[i].Subject + ' | Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
        }
    }
}
System.debug('Total inserted cases: ' + successCount + ' out of ' + casesToInsert.size());
