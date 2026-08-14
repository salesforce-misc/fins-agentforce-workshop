/**
 * @description This class contains an invokable method to retrieve details for a given Account,
 * including related Financial Accounts and Assets/Liabilities, and return them as a JSON string.
 * This is designed to be used in processes like Salesforce Flow.
 */
public without sharing class BankingAccountDetailsService {

    // Wrapper class for the main Account details
    public class AccountDetail {
        @InvocableVariable(label='Account ID')
        public String Id;

        @InvocableVariable(label='Account Name')
        public String name;

        @InvocableVariable(label='Assets Under Management')
        public Decimal assetsUnderManagement;

        @InvocableVariable(label='Primary Contact Title')
        public String title;

        @InvocableVariable(label='Last Interaction Date')
        public Date lastInteractionDate;

        // Child list of Financial Accounts
        @InvocableVariable(label='Financial Account Details')
        public List<FADetail> financialAccounts;

        // Child list of Assets and Liabilities
        @InvocableVariable(label='Asset Details')
        public List<AssetDetail> assetsAndLiabilities;
    }

    // Wrapper class for Financial Account (FA) details
    public class FADetail {
        @InvocableVariable(label='Financial Account ID')
        public String Id;

        @InvocableVariable(label='Financial Account Name')
        public String name;

        @InvocableVariable(label='Balance')
        public Decimal balance;

        @InvocableVariable(label='Record Type')
        public String recordType;

        @InvocableVariable(label='Status')
        public String status;

        @InvocableVariable(label='Ownership')
        public String ownership;

        @InvocableVariable(label='Joint Owner Name')
        public String jointOwnerName;

        @InvocableVariable(label='Account Type')
        public String accountType;
    }

    // Wrapper class for Asset and Liability details
    public class AssetDetail {
        @InvocableVariable(label='Asset ID')
        public String Id;

        @InvocableVariable(label='Asset Name')
        public String name;

        @InvocableVariable(label='Ownership')
        public String ownership;

        @InvocableVariable(label='Description')
        public String description;

        @InvocableVariable(label='Amount')
        public String amount;
        
        @InvocableVariable(label='Asset Type')
        public String assetType;
    }

    /**
     * @description Invokable method that takes a list of Account IDs and returns a JSON string for each.
     * @param accountIds List of Account Ids to process.
     * @return List<String> A list of JSON strings representing the nested account details.
     */
    @InvocableMethod(label='BWAM - Get Account Details' description='Returns a JSON string of account and related financial details.')
    public static List<String> getAccountDetailsAsJSON(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<String>();
        }

        // We will process the first ID from the list, common for screen flow scenarios.
        Id accountId = accountIds[0];
        List<String> jsonResults = new List<String>();

        try {
            // 1. Query for the main Account and its direct lookups (Primary Contact)
            Account acc = [
                SELECT Id, Name, Assets_Under_Management__c, PersonTitle
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            // 3. Query for all related Financial Accounts through the standard FSC junction object.
            List<FinancialAccountParty> financialAccountPartyList = [
                SELECT
                    Id, Role, FinancialAccount.Id, FinancialAccount.Name,
                    FinancialAccount.TotalOutstandingAmount, FinancialAccount.Status,
                    FinancialAccount.Type
                FROM FinancialAccountParty
                WHERE AccountId = :accountId
                AND IsRoleActive = true
                AND FinancialAccountId != null
            ];

            // 4. Query for all related Party Financial Assets.
            List<PartyFinancialAsset> assetsList = [
                SELECT Id, Name, ValuationAmount, Type
                FROM PartyFinancialAsset
                WHERE PartyId = :accountId
            ];

            // --- Start Building the Response Structure ---

            // A. Populate the main AccountDetail object
            AccountDetail resultDetail = new AccountDetail();
            resultDetail.Id = acc.Id;
            resultDetail.name = acc.Name;
            resultDetail.assetsUnderManagement = acc.Assets_Under_Management__c ;
            resultDetail.title = acc.PersonTitle;
            resultDetail.lastInteractionDate = null;
            resultDetail.financialAccounts = new List<FADetail>();
            resultDetail.assetsAndLiabilities = new List<AssetDetail>();

            // B. Populate the list of Financial Account details
            if (!financialAccountPartyList.isEmpty()) {
                for (FinancialAccountParty faParty : financialAccountPartyList) {
                    FinancialAccount fa = faParty.FinancialAccount;
                    FADetail faDetail = new FADetail();
                    faDetail.Id = fa.Id;
                    faDetail.name = fa.Name;
                    faDetail.balance = fa.TotalOutstandingAmount;
                    faDetail.recordType = null;
                    faDetail.status = fa.Status;
                    faDetail.ownership = faParty.Role;
                    faDetail.accountType = fa.Type;
                    // Placeholder for joint owner, can be enhanced with another query if needed
                    faDetail.jointOwnerName = null; 
                    resultDetail.financialAccounts.add(faDetail);
                }
            }

            // C. Populate the list of Asset and Liability details
            if (!assetsList.isEmpty()) {
                for (PartyFinancialAsset asset : assetsList) {
                    AssetDetail assetDtl = new AssetDetail();
                    assetDtl.Id = asset.Id;
                    assetDtl.name = asset.Name;
                    assetDtl.ownership = null;
                    assetDtl.description = null;
                    assetDtl.amount = String.valueOf(asset.ValuationAmount);
                    assetDtl.assetType = asset.Type;
                    resultDetail.assetsAndLiabilities.add(assetDtl);
                }
            }

            // 5. Serialize the final, nested object into a JSON string
            jsonResults.add(JSON.serialize(resultDetail));

        } catch (Exception e) {
            // In case of an error (e.g., no account found), handle it gracefully.
            // Here we could throw an AuraHandledException for a flow, or just log the error.
            System.debug('Error in AccountDetailsToJSON: ' + e.getMessage() + ' Stacktrace: ' + e.getStackTraceString());
            // Return an empty JSON object string to prevent flow from crashing.
            jsonResults.add('{}');
        }

        return jsonResults;
    }
}
