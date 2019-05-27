public class CloneOpportunityController {
    
    @AuraEnabled 
    public static List<LayoutSection> getPageLayoutFields() {
        
        List<LayoutSection> lstSections = new List<LayoutSection>();
        Map<String, Schema.SObjectField> mapOpportunityFields = Schema.SObjectType.Opportunity.fields.getMap();
        try {
            // Provide the page layout name here
            // You can give multiple page layout names here as well
            List<String> componentNameList = new List<String>{'Opportunity-Metric Opportunity Layout'};
            // Retrieve page layout details 
            List<Metadata.Metadata> components = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, componentNameList);
            Metadata.Layout contLayout = (Metadata.Layout) components.get(0);
            
            // We are going to find the fields names and will keep them according to columns so 
            // we can show them as per page layout 
            for( Metadata.LayoutSection ls : contLayout.layoutSections ) {
                
                LayoutSection section = new LayoutSection( ls.label, ls.layoutColumns.size() );
                      
                List<LayoutColumn> lstColumns = new List<LayoutColumn>();
                Integer maxFieldsInColumn = 0;
                for( Metadata.LayoutColumn lc : ls.layoutColumns ) {
                    
                    LayoutColumn column = new LayoutColumn();
                    // check if there are fields available in that column
                    if( lc.layoutItems != null ) { 
                        // Get the max number of fields in a column to preserve the alignment 
                        if( maxFieldsInColumn < lc.layoutItems.size() ) {
                            maxFieldsInColumn = lc.layoutItems.size();
                        }
                        for( Metadata.LayoutItem li : lc.layoutItems ) {
                            System.debug(li.field);
                            System.debug(mapOpportunityFields.get( li.field ));
                            if(li.field != null && li.behavior != Metadata.UiBehavior.ReadOnly){
                                Schema.DescribeFieldResult desribeResult = mapOpportunityFields.get( li.field ).getDescribe();
                            	// Pass the LayoutItem object in the LayoutField consturctor	    
                            	column.lstFields.add( new LayoutField( li, desribeResult.getType(), desribeResult.getLabel() ) );
                            }
                        }
                    }
                    // No need to add a column in the section if there is no field available 
                    if( column.lstFields.size() > 0 ) {
                    	lstColumns.add( column );
                    }
                }
                
                // Now, we need to arrange the fields in section so we can use them in the iteration 
                // on the component so we will have to arrange them in the order 
                if( maxFieldsInColumn > 0 ) {
                    for( Integer i = 0; i < maxFieldsInColumn; i++ ) {
                        for( Integer j = 0; j < lstColumns.size(); j++ ){
                            if( lstColumns[j].lstFields.size() > i ) {
                            	section.lstFields.add( lstColumns[j].lstFields[i] );    
                            }    
                            else {
                                section.lstFields.add( new LayoutField() );
                            }
                        }    
                    }    
                }
                
                lstSections.add( section );
            }
        }
        catch( Exception e ){
            System.assert(false, e.getLineNumber() + ' : ' + e.getMessage() );
        }
        return lstSections;
    }
    
    
    /**
     * Method which will clone an opportunity with it's products 
     * @param opp : Opportunity record which needs to be cloned
     * @param sourceOppRecordId : Id of the source opportunity, we had to pass it expicitly 
     *                            since it's not coming in the opp param which has page-layout field values
     * */
    @AuraEnabled
    public static String cloneOpportunityAndReturnProducts(Opportunity opp, String sourceOppRecordId) {
        
        System.debug(' opp : ' + opp);
        System.debug(' sourceOppRecordId : ' + sourceOppRecordId);
        
        try {
            Set<String> lstPopulatedFields = opp.getPopulatedFieldsAsMap().keySet();
            Map<String, Schema.SObjectField> mapOpportunityFields = Schema.SObjectType.Opportunity.fields.getMap();
            System.debug('mapOpportunityFields >> ' + mapOpportunityFields);
            //Check for the required fields for the opportunity sObject
            // if they are not the part of the populated fields then add them in query explicitly
            List<String> lstOpportunityFields = new List<String>();
            for( String fieldName : mapOpportunityFields.keySet() ){
                Schema.DescribeFieldResult desribeResult = mapOpportunityFields.get( fieldName ).getDescribe();
                // Check if field is required and not was populated from the page-layout
                if( desribeResult.isCreateable() && 
                   !desribeResult.isNillable() && 
                   !desribeResult.isDefaultedOnCreate() && 
                   !lstPopulatedFields.contains( fieldName.toLowerCase() ) ) { 
                    
                       lstOpportunityFields.add( fieldName.toLowerCase() ); // Add to the query field list    
                }
            }
            
            System.debug( ' >>>> lstOpportunityFields >>> ' + lstOpportunityFields );
            
            // Construct dynamic query from the fetched fields
            String queryForOpp = 'SELECT ' + String.join( lstOpportunityFields, ', ' ) + ' FROM Opportunity WHERE Id = \'' + sourceOppRecordId + '\'';
            system.debug(queryForOpp);
            Opportunity sourceOpp = Database.query( queryForOpp );
            
           
            // Deep clone the opportunity 
            Opportunity clonedOpp = sourceOpp.clone( false, true, false, false );
            
            //Pouplate cloned opportunity fields from the record passed in the method parameter 
            // Get all the values in fieldName and value map
            Map<String, Object> oppFieldsToValue = opp.getPopulatedFieldsAsMap();
            for(String fieldApiName : oppFieldsToValue.keySet()){
                if(fieldApiName != 'Id'){
                    clonedOpp.put(fieldApiName, oppFieldsToValue.get(fieldApiName));  
                }
            }
            
            // Insert the cloned opportunity record 
            if(Schema.SObjectType.Opportunity.isCreateable()){
                insert clonedOpp;
                System.debug('Opportunity record is inserted ' + clonedOpp);
            }
            
           	Map<String, Schema.SObjectField> mapOpportunityProductDescribedFields = Schema.SObjectType.OpportunityLineItem.fields.getMap();
            List<Column> lstColumns = new List<Column>();
            
            // Compulsary fields on the layout 
            // User doesn't have ability to remove them however they can make these fields non-editable
            
            lstColumns.add(new Column('Product', 'Product2.Name', 'text', false, false, true));    
            lstColumns.add(new Column('Quantity', 'Quantity', 'number', true, false, true));    
            lstColumns.add(new Column('Sales Price', 'UnitPrice', 'currency', true, false, true));    
            lstColumns.add(new Column('Line Description', 'Description', 'text', true, false, false));  
            
            List<String> fieldsInQuery = new List<String>();
            for(Column c : lstColumns){
                if(!fieldsInQuery.contains(c.fieldName.toLowerCase())){
                    fieldsInQuery.add(c.fieldName.toLowerCase());    
                }       
            }
            // Construct dynamic query from the fetched fields
            String queryForOppLineItem = 'SELECT ' + String.join(fieldsInQuery, ', ' ) + ' FROM OpportunityLineItem WHERE OpportunityId = \'' + sourceOppRecordId + '\'';
            
            List<OpportunityLineItem> sourceOppLineItems = Database.query( queryForOppLineItem );
            
            String dataColumnJson = '{ "clonedOppId": "' + clonedOpp.Id + '", "columns": ' + JSON.serialize(lstColumns) + ', "data":' + JSON.serialize(sourceOppLineItems) + '}'; 
            
            System.debug('dataColumnJson : ' + dataColumnJson);
            
            return dataColumnJson;
        }
        catch(Exception e) {
            System.debug(e.getLineNumber() + ' : ' + e.getMessage());
            throw new AuraHandledException(e.getLineNumber() + ' : ' + e.getMessage() );
        }
    }
    
    
     /**
     * Method which will clone all opportunity line items 
     * @param sourceOppRecordId : Record id of the source opportunity
     * @param clonedOppRecordId : Id of the target opportunity record
     * @param lstSourceLineItemIds : Id of line items from the source opportunity
     * @param lstLineItemsChanges :  List of OpportunityLineItem object which has updated values                        
     * */
    @AuraEnabled
    public static Id cloneOpportunityLineItems(Id sourceOppRecordId, Id clonedOppRecordId, List<Id> lstSourceLineItemIds, List<OpportunityLineItem> lstLineItemsChanges){
        
        try{
            System.debug(' sourceOppRecordId : ' + sourceOppRecordId );
            System.debug(' clonedOppRecordId : ' + clonedOppRecordId );
            System.debug(' lstSourceLineItemIds : ' + lstSourceLineItemIds );
            System.debug(' lstLineItemsChanges : ' + lstLineItemsChanges );
            
            // Query opportunity line items from the source opportunity and 
            // use the fields which has been configured at custom metadata level
            List<String> lstFieldsInQuery = new List<String>{ 'product2id', 'quantity', 'pricebookentryid', 'unitprice' };
                                                                  
            Map<String, Schema.SObjectField> mapOpportunityProductDescribedFields = Schema.SObjectType.OpportunityLineItem.fields.getMap();
            
            for( String fieldName : mapOpportunityProductDescribedFields.keySet() ){
                Schema.DescribeFieldResult desribeResult = mapOpportunityProductDescribedFields.get( fieldName ).getDescribe();
                // Add to the query field list  
                if( desribeResult.isCreateable() && !lstFieldsInQuery.contains(fieldName.toLowerCase() ) && fieldName.toLowerCase() != 'totalprice' ){
                    lstFieldsInQuery.add( fieldName.toLowerCase() );
                }
            }         
          
            System.debug(lstFieldsInQuery);
            //Check for the required fields on opportunity line item object
            // if they are not the part of the lstFieldsInQuery then add them in query explicitly
            for( String fieldName : mapOpportunityProductDescribedFields.keySet() ){
                Schema.DescribeFieldResult desribeResult = mapOpportunityProductDescribedFields.get( fieldName ).getDescribe();
                if( desribeResult.isCreateable() && 
                   !desribeResult.isNillable() && 
                   !desribeResult.isDefaultedOnCreate() && 
                   !lstFieldsInQuery.contains( fieldName.toLowerCase() ) ) { 
                       // Add to the query field list   
                       lstFieldsInQuery.add( fieldName.toLowerCase() );  
                }
            }
            
            System.debug(' INCLUDING REQUIRED FIELDS : ' + lstFieldsInQuery);
            
            Map<Id, OpportunityLineItem> mapUpdatedOppLineItems = new Map<Id, OpportunityLineItem>();
            if(lstLineItemsChanges != NULL){
                mapUpdatedOppLineItems.putAll(lstLineItemsChanges);
            }
            
            //Query all the opportunity line items from the query 
            // Construct dynamic query from the fetched fields
            String queryForOppLineItem = 'SELECT ' + String.join( lstFieldsInQuery, ', ' ) + ' FROM OpportunityLineItem WHERE Id IN :lstSourceLineItemIds';
            List<OpportunityLineItem> lstSourceOppLineItems = Database.query(queryForOppLineItem);
            
            List<OpportunityLineItem> lstClonedOpportunityLineItems = new List<OpportunityLineItem>();
            //Update source opp line items with updated values
            for(OpportunityLineItem sourceOli : lstSourceOppLineItems){
                
                OpportunityLineItem clonedOppLineItem = sourceOli.clone( false, true, false, false );
                System.debug(' clonedOppLineItem : ' + clonedOppLineItem );
                clonedOppLineItem.OpportunityId = clonedOppRecordId;
                
                if(mapUpdatedOppLineItems.containsKey(sourceOli.Id)){
                    //Find the populated values on the sObject
                    Map<String, Object> mapFieldsToValue = mapUpdatedOppLineItems.get(sourceOli.Id).getPopulatedFieldsAsMap(); 
                    for (String fieldName : mapFieldsToValue.keySet()) {
                        if(fieldName != 'Id'){
                            System.debug(' fieldName : ' + fieldName + ' => value : ' + mapFieldsToValue.get(fieldName));
                            clonedOppLineItem.put(fieldName, mapFieldsToValue.get(fieldName));
                        }
                    }
                }    
                //Adding to the list 
                lstClonedOpportunityLineItems.add(clonedOppLineItem);
                
            }
            
            insert lstClonedOpportunityLineItems;
            return clonedOppRecordId;
        }
        catch(Exception e) {
            System.debug(e.getLineNumber() + ' : ' + e.getMessage());
            throw new AuraHandledException( e.getLineNumber() + ' : ' + e.getMessage() );
        }
    }  
    
    
    /**
     * This method is returning the allowed types for the column
     * Lightning data table supported types are being retuned based on the Schema.DisplayType enum
     */
    public static String getColumnType(Schema.DisplayType fieldType){
        String columnType = 'text';
        switch on fieldType {
            when STRING, PICKLIST, TEXTAREA, MULTIPICKLIST  {
                columnType = 'text';
            }
            when DOUBLE, LONG, INTEGER {
                columnType = 'number';
            }
            when DATETIME {
                columnType = 'date';
            }
            when DATE {
                columnType = 'date-local';
            }
            when ADDRESS {
                columnType = 'location';
            }
            when else { 
                columnType = String.valueOf(fieldType).toLowerCase();    
            }
        } 
        return columnType;
    }
    
   
    
    //Wrapper class for generating the JSON for Lightning:dataTable columns
    public class Column {
        String label;
        String fieldName;
        String type;
        Boolean editable;
        Boolean sortable;
        Boolean required;
        Map<String, String> cellAttributes;   // To control the cell behaviour
        
        public Column(String label, String fieldName, String type, Boolean editable, Boolean sortable, Boolean required){
            this.label = required ? '*' + label : label;
            this.fieldName = fieldName;
            this.type = type;
            this.editable = editable;
            this.sortable = sortable;
            this.required = required;
            this.cellAttributes = new Map<String, String>{'alignment'=>'left'};
        }
        
    }
    
     public class LayoutSection {   
	@AuraEnabled public String label;
    	@AuraEnabled public List<LayoutField> lstFields;
        @AuraEnabled public Integer totalColumns;
        public LayoutSection( String label, Integer totalColumns ) {
	    	this.label = label;
            this.totalColumns = totalColumns;
            this.lstFields = new List<LayoutField>();
        }
    }
    
    private class LayoutColumn {
    	private List<LayoutField> lstFields;    
        public LayoutColumn() {
            this.lstFields = new List<LayoutField>();
        }
    }
    
    public class LayoutField {
        @AuraEnabled public String fieldName;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isReadOnly;
        @AuraEnabled public String type;
        @AuraEnabled public String label;
        
        public LayoutField() {}
        
        public LayoutField( Metadata.LayoutItem li, Schema.DisplayType type, String label ) {
        	
            this.fieldName = li.field;
            if( li.behavior == Metadata.UiBehavior.Required ) {
                this.isRequired = true;
            }
            else if( li.behavior == Metadata.UiBehavior.ReadOnly ) {
                this.isReadOnly = true;
            }   
            this.type = String.valueOf(type);
            this.label = label;
        }
    }
}