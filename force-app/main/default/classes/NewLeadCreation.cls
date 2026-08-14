public class NewLeadCreation {
    
    @InvocableMethod(label='Create and Display Lead' description='Creates a new lead record and returns its details')
    public static List<LeadOutput> createAndDisplayLead(List<LeadInput> leadInputs) {
        List<LeadOutput> leadOutputs = new List<LeadOutput>();
        
        for(LeadInput leadInput : leadInputs) {
            Lead newLead = new Lead();
            newLead.FirstName = leadInput.firstName;
            newLead.LastName = leadInput.lastName;
            newLead.Email = leadInput.email;
            // Set other lead fields as needed
            
            insert newLead;
            
            LeadOutput output = new LeadOutput();
            output.leadId = newLead.Id;
            output.firstName = newLead.FirstName;
            output.lastName = newLead.LastName;
            output.email = newLead.Email;
            // Set other output fields as needed
            
            leadOutputs.add(output);
        }
        
        return leadOutputs;
    }
    
    // Inner class for input parameters
    public class LeadInput {
        @InvocableVariable(label='First Name' description='First name of the lead')
        public String firstName;
        @InvocableVariable(label='Last Name' description='Last name of the lead')
        public String lastName;
        @InvocableVariable(label='Email' description='Email of the lead')
        public String email;
        // Add more fields as needed
    }
    
    // Inner class for output parameters
    public class LeadOutput {
        @InvocableVariable(label='Lead ID' description='ID of the created lead')
        public Id leadId;
        @InvocableVariable(label='First Name' description='First name of the created lead')
        public String firstName;
        @InvocableVariable(label='Last Name' description='Last name of the created lead')
        public String lastName;
        @InvocableVariable(label='Email' description='Email of the created lead')
        public String email;
        // Add more fields as needed
    }
}