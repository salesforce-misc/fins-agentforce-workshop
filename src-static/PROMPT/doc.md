## Insurance Prompt Builder Workshop Overview

In this workshop, you will build two practical generative AI automations for an insurance business using **Prompt Builder**, **Flow Builder**, and **Financial Services Cloud** data. Both exercises are designed for a Salesforce admin and focus on common service operations: routing inbound service requests and summarizing policy-related service history.

These exercises assume **Email-to-Case** is already configured and that your org uses **Financial Services Cloud**, including the **InsurancePolicy** object. They also assume that Cases related to a policy can be identified through an existing relationship field. If your org uses a different field name than the one shown in this guide, substitute your own field when configuring the flows.

We will explore:

- **Prompt Templates** to classify inbound requests and summarize related service activity
- **Flow Builder** to orchestrate prompt execution and update records automatically
- **JSON output** so a flow can reliably interpret AI results
- **Autolaunched Flows** to run policy summaries from the record page
- **Testing** to validate both routing and summarization outcomes

---

### 1. Route Inbound Email Cases with Prompt Builder

In this exercise, you will build a generative AI-assisted case routing process for an insurance carrier. When a new Case is created from **Email-to-Case**, a record-triggered flow will invoke a prompt template that analyzes the case **Subject** and **Description** and returns structured JSON. The flow will then use that response to classify and route the case.

The routing categories for this exercise are:

- `Account Management`
- `Policy Management`
- `Claims`
- `Sales`

#### 1.1 Create Fields for AI Routing Output

First, create a few fields on the **Case** object so you can store the AI result and make the routing transparent for service teams.

1. In **Setup**, open **Object Manager**.
2. Select **Case**.
3. Click **Fields & Relationships** and then click **New**.
4. Create a **Text** field with these values:
   - **Field Label**: `AI Case Category`
   - **Length**: `100`
5. Create a second **Long Text Area** field with these values:
   - **Field Label**: `AI Routing Reason`
   - **Visible Lines**: `4`
   - **Length**: `1000`
6. Create a third **Checkbox** field with these values:
   - **Field Label**: `AI Routed`
   - **Default Value**: unchecked

> Screenshot placeholder: Case custom fields for AI routing output

If your org already has a queue-routing pattern, you can reuse existing fields instead of creating new ones.

---

#### 1.2 Create the Case Routing Prompt Template

Next, create a prompt template that classifies an inbound insurance service request and returns JSON that a flow can parse.

1. In **Setup**, use **Quick Find** to search for and select **Prompt Builder**.
2. Click **New Prompt Template**.
3. Choose the prompt template type that supports use in **Flow**.
4. Enter these values:
   - **Template Name**: `Insurance Case Routing`
   - **API Name**: `Insurance_Case_Routing`
   - **Description**: `Classifies inbound insurance email cases into a service routing category and returns structured JSON for Flow`
5. Save the prompt template.

For the prompt instructions, use a prompt similar to the one below:

```text
You are assisting an insurance operations team with triaging inbound email cases.

Review the case subject and description and classify the request into exactly one of these categories:
- Account Management
- Policy Management
- Claims
- Sales

Use these definitions:
- Account Management: profile updates, billing contacts, communication preferences, beneficiary or household updates, login/access support, general account maintenance
- Policy Management: coverage questions, renewals, cancellations, endorsements, ID cards, declarations, underwriting follow-up, policy changes
- Claims: loss reporting, claim status, claim documents, claim payment questions, adjuster follow-up, incident details
- Sales: quote requests, new policy inquiries, cross-sell, upsell, product comparisons, requests to speak with a producer or agent about buying coverage

Return valid JSON only.

Use this JSON structure:
{
  "category": "",
  "confidence": "",
  "reason": "",
  "suggestedQueueDeveloperName": ""
}

Rules:
- The category must be exactly one of the four allowed values.
- The confidence must be High, Medium, or Low.
- The reason must be one short sentence.
- suggestedQueueDeveloperName must be one of:
  - Account_Management
  - Policy_Management
  - Claims
  - Sales
- Do not include markdown fences or extra commentary.

Case Subject: {!$Input:Case.Subject}
Case Description: {!$Input:Case.Description}
```

6. Add the necessary prompt inputs so the template can receive Case data from Flow.
7. Save and, if required in your org, activate or make the template available for use.

> Screenshot placeholder: Prompt Builder template showing instructions and JSON response shape

This prompt design keeps the output deterministic enough for a flow to interpret while still using AI to understand natural-language insurance requests.

---

#### 1.3 Build the Record-Triggered Flow

Now create the flow that runs whenever a new case arrives from Email-to-Case.

1. In **Setup**, search for and select **Flows**.
2. Click **New Flow**.
3. Select **Record-Triggered Flow**.
4. Configure the start conditions:
   - **Object**: `Case`
   - **Trigger the Flow When**: `A record is created`
   - **Condition Requirements**: add a condition that identifies inbound Email-to-Case records in your org
5. Set the flow to run **After the record is saved**.
6. Click **Done**.

If your org distinguishes Email-to-Case using **Origin = Email**, use that condition. If your implementation uses another field or logic, use that instead.

> Screenshot placeholder: Start element for new case routing flow

Add the core flow logic:

1. Click the **+** icon after **Start** and add an **Action**.
2. Search for the prompt template action for **Insurance Case Routing** and select it.
3. Set the prompt inputs so the template receives:
   - **Subject** from the new Case record
   - **Description** from the new Case record
4. Store the prompt response in an output variable.
5. Add an **Assignment**, **Transform**, or parsing step based on the prompt action output available in your org so you can access:
   - `category`
   - `confidence`
   - `reason`
   - `suggestedQueueDeveloperName`
6. Add a **Get Records** element to retrieve the target **Group** record for the queue returned by the prompt.
7. Add an **Update Records** element to update the Case with:
   - **OwnerId** = queue Id from the **Group** record
   - **AI Case Category** = parsed `category`
   - **AI Routing Reason** = parsed `reason`
   - **AI Routed** = `True`

Use a **Decision** element before assigning the owner if you want to handle null or malformed JSON safely. For example, route low-confidence or invalid responses to a fallback operations queue.

> Screenshot placeholder: Flow canvas showing prompt action, queue lookup, and case update

---

#### 1.4 Add a Fallback Branch

It is a good practice to define what happens if the model returns an unexpected result.

1. Add a **Decision** element after the prompt action.
2. Create one outcome for a valid response where `category` is populated and `suggestedQueueDeveloperName` matches one of the expected values.
3. Create a default outcome for fallback handling.
4. In the fallback path, update the case with:
   - **AI Routing Reason** = `AI routing could not confidently determine a category.`
   - **AI Routed** = `False`
5. Optionally assign the case to a general triage queue for manual review.

> Screenshot placeholder: Decision element for valid AI response versus fallback route

---

#### 1.5 Test Case Routing

Now test the end-to-end routing experience.

1. Save the flow as:
   - **Flow Label**: `Route Email Cases with AI`
2. Click **Activate**.
3. Create four test inbound cases that reflect realistic insurance scenarios. You can use Email-to-Case, or create test cases manually if needed.

Use examples like these:

1. **Claims**
   - **Subject**: `Need help with claim after windshield damage`
   - **Description**: `I submitted a claim for my auto policy after road debris cracked my windshield and I want to know the next steps and deductible.`
2. **Policy Management**
   - **Subject**: `Please add my new vehicle to my policy`
   - **Description**: `I replaced my old car and need to update coverage on my active auto policy before the weekend.`
3. **Account Management**
   - **Subject**: `Update mailing address and communication preferences`
   - **Description**: `I moved to a new address and also want paperless statements for all of my policies.`
4. **Sales**
   - **Subject**: `Interested in bundling home and auto coverage`
   - **Description**: `I currently have auto insurance and want a quote for homeowners insurance to see if I can save by bundling.`

For each test case, verify the following:

- The flow runs when the Case is created
- The **AI Case Category** field is populated with the expected category
- The **AI Routing Reason** explains the classification
- The Case owner is updated to the expected queue

> Screenshot placeholder: Case record after routing showing AI category, reason, and queue owner

**Successful outcome:** New inbound email cases are automatically classified and routed to the right insurance service team with a visible explanation of why the routing decision was made.

---

### 2. Summarize Recent Cases for an Insurance Policy

In this exercise, you will build a policy-level summary experience for service users. An **Autolaunched Flow** will collect recent Cases related to an **InsurancePolicy** record, send those details to a prompt template, and write the generated summary back to the policy. You will also add a button so users can run the summary directly from the policy record.

This is useful when a service rep is reviewing a policy before a renewal call, investigating repeat service issues, or preparing for a high-touch customer conversation.

#### 2.1 Create a Field to Store the Summary

First, create a field on **InsurancePolicy** to store the generated summary.

1. In **Setup**, open **Object Manager**.
2. Search for and select **InsurancePolicy**.
3. Click **Fields & Relationships** and then click **New**.
4. Create a **Long Text Area** field with these values:
   - **Field Label**: `Recent Case Summary`
   - **Visible Lines**: `8`
   - **Length**: `32000`
5. Save the field.

If you want to track when the summary was last refreshed, also create a **Date/Time** field named `Case Summary Last Generated`.

> Screenshot placeholder: InsurancePolicy fields including Recent Case Summary

---

#### 2.2 Create the Policy Case Summary Prompt Template

Now create the prompt template that will turn recent policy-related cases into a concise insurance service summary.

1. In **Setup**, open **Prompt Builder**.
2. Click **New Prompt Template**.
3. Choose the prompt template type that can be invoked from **Flow**.
4. Enter these values:
   - **Template Name**: `Insurance Policy Case Summary`
   - **API Name**: `Insurance_Policy_Case_Summary`
   - **Description**: `Summarizes recent cases related to an insurance policy for service and operations users`
5. Save the template.

Use prompt instructions similar to the following:

```text
You are helping an insurance service representative prepare for a policy conversation.

Review the insurance policy details and the recent related cases. Create a concise summary for an internal user.

Your summary must include:
1. A one-paragraph overall summary of recent service activity
2. The most common themes or issues
3. Any open issues that may need follow-up
4. Any signs of customer frustration, urgency, or repeat contact

Write in clear professional language for an insurance operations user.
Do not invent facts that are not present in the source data.

Insurance Policy:
{!$Input:PolicyContext}

Recent Related Cases:
{!$Input:CaseContext}
```

6. Configure prompt inputs for:
   - `PolicyContext`
   - `CaseContext`
7. Save and activate the prompt template if needed.

> Screenshot placeholder: Policy case summary prompt template in Prompt Builder

---

#### 2.3 Build the Autolaunched Flow

Next, build the flow that gathers policy data, retrieves recent cases, calls the prompt, and writes the summary back to the policy record.

1. In **Setup**, open **Flows**.
2. Click **New Flow**.
3. Select **Autolaunched Flow (No Trigger)**.
4. Click **Create**.
5. Create a **Text** input variable with these values:
   - **API Name**: `recordId`
   - **Available for input**: checked

This allows the flow to run from an **InsurancePolicy** record page.

> Screenshot placeholder: Autolaunched flow input variable for recordId

Add the policy retrieval logic:

1. Add a **Get Records** element for **InsurancePolicy**.
2. Filter where **Id** equals the `recordId` input variable.
3. Store the policy record.

Add the recent case retrieval logic:

1. Add a **Get Records** element for **Case**.
2. Filter for Cases related to the current policy using your org's relationship field.
3. Sort by **Created Date** descending.
4. Limit the results to a recent set such as the most recent `5` or `10` cases.
5. Store the returned records.

If your org uses a custom lookup such as `InsurancePolicy__c` on Case, use that field. If it uses a standard FSC relationship or an intermediary model, adjust the query logic accordingly.

Now prepare the data for the prompt:

1. Add a **Text Template** or **Assignment** step to build a readable policy context string that includes useful details such as:
   - Policy number
   - Policy type
   - Status
   - Effective date
   - Expiration date
   - Named insured, if available
2. Add a second **Text Template** or loop-based concatenation step to build a case context string from the recent cases. Include values such as:
   - Case number
   - Created date
   - Status
   - Subject
   - Description
   - Priority, if used in your org

Then invoke the prompt:

1. Add an **Action** element and select the **Insurance Policy Case Summary** prompt template action.
2. Pass the policy context text into `PolicyContext`.
3. Pass the recent case context text into `CaseContext`.
4. Store the generated summary output.

Finally, update the policy:

1. Add an **Update Records** element.
2. Update the current **InsurancePolicy** record with:
   - **Recent Case Summary** = prompt output
3. If you created the timestamp field, also set:
   - **Case Summary Last Generated** = current date/time

> Screenshot placeholder: Autolaunched flow canvas showing policy lookup, case lookup, prompt action, and record update

Save the flow with these values:

- **Flow Label**: `Generate Insurance Policy Case Summary`
- **API Name**: `Generate_Insurance_Policy_Case_Summary`

Activate the flow.

---

#### 2.4 Add a Button to the InsurancePolicy Record

Now expose the flow to users from the policy record page.

1. In **Setup**, open **Object Manager**.
2. Select **InsurancePolicy**.
3. Click **Buttons, Links, and Actions**.
4. Click **New Action**.
5. Configure the action:
   - **Action Type**: `Flow`
   - **Flow**: `Generate Insurance Policy Case Summary`
   - **Label**: `Generate Case Summary`
6. Save the action.

Next, add the action to the page layout or Lightning record page:

1. Open **Page Layouts** or **Lightning App Builder**, depending on how your org surfaces actions.
2. Add **Generate Case Summary** to the visible policy actions.
3. Save and activate the page if needed.

Also consider adding the **Recent Case Summary** field to the page so the user can see the generated output immediately after running the flow.

> Screenshot placeholder: InsurancePolicy record page with Generate Case Summary action visible

---

#### 2.5 Test Policy Summarization

You are now ready to test the policy summary experience.

1. Open an **InsurancePolicy** record that already has several related Cases.
2. Review the related list to confirm there is enough recent service activity to summarize.
3. Click **Generate Case Summary**.
4. Wait for the flow to complete.
5. Refresh the record if needed.
6. Review the **Recent Case Summary** field.

Validate that the generated summary:

- Mentions recent service themes accurately
- Identifies open or unresolved issues
- Reflects repeat contacts or urgency when present
- Uses details only from the related Cases

Test with at least two different policies:

1. A policy with multiple recent service cases, such as billing questions, endorsement requests, and claim follow-up
2. A policy with little or no recent activity, to confirm the summary remains concise and does not invent details

> Screenshot placeholder: InsurancePolicy record showing generated recent case summary

**Successful outcome:** A user can open any policy record, run a single action, and quickly understand recent support history before helping the customer.

---

### 3. Wrap-Up

In this workshop, you built two insurance-focused generative AI automations:

1. A **record-triggered flow** that classifies and routes inbound Email-to-Case requests using a prompt template with **JSON output**
2. An **autolaunched flow** that summarizes recent policy-related cases and writes the result back to the **InsurancePolicy** record

These patterns are useful starting points for many Financial Services Cloud use cases. Once they are working, you can extend them with more sophisticated routing logic, confidence thresholds, escalation rules, policy-specific prompts, or richer summary formats for service and underwriting teams.
