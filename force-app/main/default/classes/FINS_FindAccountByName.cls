public with sharing class FINS_FindAccountByName {
    public FINS_FindAccountByName() {}
    
    public class Request {
        @InvocableVariable(label='Name')
        public String name;
    }

    public static Integer damerauLevenshteinDistance(String s1, String s2) {
        Integer m = s1.length();
        Integer n = s2.length();
        
        List<List<Integer>> dp = new List<List<Integer>>();
        
        for (Integer i = 0; i <= m; i++) {
            List<Integer> row = new List<Integer>();
            for (Integer j = 0; j <= n; j++) {
                row.add(0);
            }
            dp.add(row);
        }
        
        for (Integer i = 0; i <= m; i++) {
            dp.get(i).set(0, i);
        }
        
        for (Integer j = 0; j <= n; j++) {
            dp.get(0).set(j, j);
        }
        
        for (Integer i = 1; i <= m; i++) {
            for (Integer j = 1; j <= n; j++) {
                Integer cost = s1.substring(i - 1, i) == s2.substring(j - 1, j)? 0 : 1;
                dp.get(i).set(j, Math.min(Math.min(dp.get(i - 1).get(j) + 1, dp.get(i).get(j - 1) + 1), dp.get(i - 1).get(j - 1) + cost));
            }
        }
        
        return dp.get(m).get(n);
    }
    
    public static integer hammingDistance(string s1, string s2) {
        integer distance = 0;
        if (s1.length() > s2.length()) {
            string temp = s2;
            s2 = s1;
            s1 = temp;
        }
        for (integer i = 0; i < s1.length(); i++) {
            if (s1.substring(i, i + 1)!= s2.substring(i, i + 1)) {
                distance++;
            }
        }
        return distance;
    }
    
    
    public static List<String> getFragments(String potentialName)
    {
        if (String.isBlank(potentialName)) return null;
        
        List<String> fragments = new List<String>();
        List<String> chunks = potentialName.split(' ');
        
        while (chunks.size() >= 2) // starting with one word should yield an empty result
        {
            String fragment = '';
            if (!fragments.isEmpty()) fragment += '%'; //No leading wildcard
            fragment += chunks.remove(0);
            fragment += chunks.get(0);
            if (chunks.size() > 1) fragment += '%'; // No trailing wildcard
            fragments.add(fragment);
        }
        System.debug('fragments  = ' + fragments);
        return fragments;
    }
    
    
    @InvocableMethod(label='Find Account by Name')
    public static List<List<Account>>  findAccountByName(List<Request> requests) {
        List<List<Account>> retvals = new  List<List<Account>>();
        
        for (Request request : requests) {
            List<Account> accounts = [
                SELECT FIELDS(STANDARD)
                FROM Account
                WHERE Name = :request.name];
            if (accounts.size() == 0) {
                List<String> partialMatches = new List<String>();
                for (String fragment : request.name.split(' '))
                {
                    partialMatches.add('%' + fragment + '%');
                }
                List<Account> fAccounts = [SELECT FIELDS(STANDARD) FROM Account WHERE Name LIKE :partialMatches];
                for (Account a: fAccounts) {
                    if (damerauLevenshteinDistance(a.Name, request.name) <= 3)
                        accounts.add(a);
                }
                
            }
            retvals.add(accounts);
        }
        return retvals;
    }
}