/* *
* Test class for validating the methods from CloneOpportunityController class
* */

@isTest
class CloneOpportunityControllerTest {
    
    @testSetup
    static void createTestData() {
        
        // Get the pricebook id
        Id pricebookId = Test.getStandardPricebookId();
        
         
        Pricebook2 pbk1 = new Pricebook2 ( Name='Test Pricebook Entry 1', Description='Test Pricebook Entry 1', isActive=true);
        insert pbk1;
        
        //Create your product
        Product2 prod = new Product2(
             Name = 'Product X',
             ProductCode = 'Pro-X',
             isActive = true
        );
        insert prod;
        
        //Create your pricebook entry
        PricebookEntry pbEntry = new PricebookEntry(
             Pricebook2Id = pricebookId,
             Product2Id = prod.Id,
             UnitPrice = 100.00,
             IsActive = true
        );
        insert pbEntry;
        
        
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Prospects'];
        
        Account acc = new Account (
            Name = 'Test',
            BillingCountry = 'United Kingdom',
            RecordTypeId = rt.Id
        );
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            CloseDate = System.today(),
            StageName = '5% - Prospecting',
            AccountId = acc.Id,
            Amount = 250.0,
            ForecastCategoryName = 'Pipeline',
            Type = 'Renewal'
        );
        insert opp;
        
        //create your opportunity line item.  
        OpportunityLineItem oli = new OpportunityLineItem(
        
             OpportunityId = opp.Id,
             Quantity = 5,
             PricebookEntryId = pbEntry.Id,
             TotalPrice = 5 * pbEntry.UnitPrice,
             ServiceDate = Date.today()             
        );
        insert oli;
    }
    
    
    @isTest
    static void getOpportunityLineItems_test() {
        
        Opportunity opp = [SELECT Id, StageName, Amount, CloseDate, AccountId FROM Opportunity LIMIT 1];
        
        Test.startTest();
        
        String clonedOppRes = CloneOpportunityController.cloneOpportunityAndReturnProducts(opp, opp.Id);
        
        System.assertNotEquals( null, clonedOppRes );
        
        List<Opportunity> lstOpportunity = [SELECT Id, Amount FROM Opportunity ORDER BY CreatedDate];
        
        System.assertEquals(2, lstOpportunity.size());
        
        String clonedOppId = lstOpportunity[1].Id;
        
        Map<Id, OpportunityLineItem> mapOppLineItems = new Map<Id, OpportunityLineItem>([SELECT Id, UnitPrice, Quantity, Description, ServiceDate FROM OpportunityLineItem ]);
        
        System.assertNotEquals( null, CloneOpportunityController.cloneOpportunityLineItems( opp.Id, clonedOppId, new List<Id>(mapOppLineItems.keySet()), new List<OpportunityLineItem>() ) );
        
        System.assertEquals( 1, [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :clonedOppId].size() );
        
        System.assertNotEquals( null, CloneOpportunityController.getPageLayoutFields() );
        
        System.assertEquals( 'text', CloneOpportunityController.getColumnType( Schema.DisplayType.PICKLIST ) );
        System.assertEquals( 'number', CloneOpportunityController.getColumnType( Schema.DisplayType.DOUBLE ) );
        System.assertEquals( 'date-local', CloneOpportunityController.getColumnType( Schema.DisplayType.DATE ) );
        System.assertEquals( 'date', CloneOpportunityController.getColumnType( Schema.DisplayType.DATETIME ) );
        System.assertEquals( 'location', CloneOpportunityController.getColumnType( Schema.DisplayType.ADDRESS ) );
        
        Test.stopTest();
    }
}