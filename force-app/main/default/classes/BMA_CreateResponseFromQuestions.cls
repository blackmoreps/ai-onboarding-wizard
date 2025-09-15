public class BMA_CreateResponseFromQuestions {
  
    public class IntakeWrapper {
        @InvocableVariable(required=true)
        public Id intakeId;
        @InvocableVariable(required=true)
        public Id projectId;
    }

    @InvocableMethod(label='Create BMA Responses and Choices from Intake')
    public static void BMA_CreateResponseFromQuestions(List<IntakeWrapper> flowInputs) {
        if (flowInputs == null || flowInputs.isEmpty()) return;

        Id intakeId = flowInputs[0].intakeId;
        Id projectId = flowInputs[0].projectId;
         
        //Query  BMA Project
        bma_Project__c projects = [
            SELECT Id, Account__c, Cloud__c, Starter_Type__c
            FROM bma_Project__c
            WHERE Id = :projectId
            LIMIT 1
        ];
        String projectCloud = projects.Cloud__c;
        String projectStarterType = projects.Starter_Type__c;

       
        //Query  BMA Intake
        bma_Intake__c intakes = [
            SELECT Id, Account__c, Cloud__c, Starter_Type__c
            FROM bma_Intake__c
            WHERE Id = :intakeId
            LIMIT 1
        ];
        
       

        // Step 1: Query all BMA Sections for the Intake
        List<bma_Section__c> sections = [
            SELECT Id, Starter_Type__c ,Cloud__c 
            FROM bma_Section__c Where Cloud__c Includes (:projectCloud) And Starter_Type__c =:projectStarterType
            
        ];

        Set<Id> sectionIds = new Set<Id>();
        for (bma_Section__c sec : sections) {
            sectionIds.add(sec.Id);
        }

        if (sectionIds.isEmpty()) return;

        // Step 2: Query all BMA Questions under the Sections
        List<bma_Question__c> questions = [
            SELECT Id, Section__c,Object__c, Field__c,Screen__c,Answer_Type__c,Question__c
            FROM bma_Question__c 
            WHERE Section__c IN :sectionIds
        ];

        Map<Id, bma_Response__c> questionIdToResponseMap = new Map<Id, bma_Response__c>();
        List<bma_Response__c> responsesToInsert = new List<bma_Response__c>();

        for (bma_Question__c question : questions) {
            bma_Response__c response = new bma_Response__c(
                Question__c = question.Id,
                Intake__c = intakeId,
                Object__c =question.Object__c,
                Field__c =question.Field__c,
                Section__c = question.Section__c,
                Screen__c = question.Screen__c, 
                Answer_Type__c = question.Answer_Type__c, 
                Account__c = intakes.Account__c,
                Question1__c = question.Question__c
                
            );
            responsesToInsert.add(response);
            System.debug('Response: '+ response);
        }

        insert responsesToInsert;

        // Step 3: Map questionId to newly inserted response
        Integer i = 0;
        for (bma_Question__c question : questions) {
            questionIdToResponseMap.put(question.Id, responsesToInsert[i]);
            i++;
        }

        // Step 4: Query all Question Choices for all Questions
        List<bma_Question_Choice__c > allChoices = [
            SELECT Id, Question__c, Selected__c, Sequence__c,Value__c 
            FROM bma_Question_Choice__c 
            WHERE Question__c IN :questionIdToResponseMap.keySet()
        ];

        List<bma_Response_Choice__c> responseChoicesToInsert = new List<bma_Response_Choice__c>();

        for (bma_Question_Choice__c choice : allChoices) {
            bma_Response__c response = questionIdToResponseMap.get(choice.Question__c);
            if (response != null) {
                responseChoicesToInsert.add(new bma_Response_Choice__c(
                    Response__c = response.Id,
                    Question_Choice__c  = choice.Id,
                    Selected__c = choice.Selected__c,
                    Sequence__c = choice.Sequence__c,
                    Value__c = choice.Value__c
                ));
            }
        }

        insert responseChoicesToInsert;
        System.debug('Response Choice: '+ responseChoicesToInsert);
    }



}