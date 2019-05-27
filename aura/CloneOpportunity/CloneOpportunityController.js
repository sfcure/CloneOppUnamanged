({
    
	doInit: function( component, event, helper ) {
        var action = component.get("c.getPageLayoutFields");
        action.setCallback(this, function(response) {
        	var state = response.getState();
            console.log(response);
			if (state === "SUCCESS") {
                component.set("v.layoutSections", response.getReturnValue() );
                let lstFields = [];
                for(let section of response.getReturnValue()){
                    for(let field of section.lstFields){
                        if(field != undefined && field.fieldName != undefined && ( field.type =='DOUBLE' || field.type == 'CURRENCY') ){
                        	lstFields.push(field.fieldName);	    
                        }    
                    }
                }
                
                component.set("v.currencyNumberFields", lstFields);
            }
            else if (state === "INCOMPLETE") {
                console.log( 'ERROR' );
            }
            else if (state === "ERROR") {
                var errors = response.getError();
				console.log( errors );
            }
        });
        $A.enqueueAction(action);
    },  
    
    validateFieldsAndhideCustomDockFooter: function(component, event, helper) {
    	component.set("v.isDataChanged", true);	  
        console.log(event.getParam('draftValues'));
        helper.validate(component, event);
    },
    
    cloneOpportunity: function(component, event, helper) {
        // stop the form from submitting since we are going to clone the opportunity 
        // so it will be done in the server side action
        event.preventDefault();       
        var fields = event.getParam("fields");
        let oppUpdate = component.get("v.oppUpdate");
        console.table(JSON.parse(JSON.stringify(fields)));
        let currencyNumberFields = component.get("v.currencyNumberFields");
        Object.keys(oppUpdate).forEach(function(key) {
            if(key != 'CreatedById' && currencyNumberFields.indexOf(key) != -1){
                fields[key] = oppUpdate[key];
            }		    
        });
        //fields["Id"] = component.get("v.recordId");
        console.table(JSON.parse(JSON.stringify(fields)));
       	
        helper.cloneOppAndGetLineItems(component, fields);
        
    },
    
    handleCloneLineItems: function(component, event, helper){
        helper.cloneOppLineItems(component, event);  
    },
    
    handleColumnSorting : function(component, event, helper) {
        // assign the latest attribute with the sorted column fieldName and sorted direction
    	component.set("v.sortedBy", event.getParam("fieldName"));
    	component.set("v.sortedDirection", event.getParam("sortDirection")); 
        helper.sortData(component, event.getParam("fieldName"), event.getParam("sortDirection"));
    },
    
    /**
     * Handling opp line item row action i.e. deleting a row
     * */
    handleRowAction: function (component, event, helper) {
        var action = event.getParam('action');
        var row = event.getParam('row');
        console.log(action, row);
        switch (action.name) {
            case 'delete':
                helper.deleteRow(component, row);
                break;
        }
    },
    
    recordLoaded : function(component, event, helper) {
  		var recordUi = event.getParam("recordUi");
        
        var oppUpdate = {};
        let currencyNumberFields = component.get("v.currencyNumberFields");
        Object.keys(recordUi.record.fields).forEach(function(key) {
            if(currencyNumberFields.indexOf(key) != -1){
            	let fieldObj = recordUi.record.fields[key];
        		oppUpdate[key] = fieldObj.value;
            }
        });
        console.table(JSON.parse(JSON.stringify(oppUpdate)));
        component.set("v.oppUpdate", oppUpdate);
        oppUpdate['CreatedById'] = recordUi.record.fields['CreatedById'].value;
        component.set("v.oppUpdate", oppUpdate);
        component.set("v.dataLoadComplete", true);
	},
    
    handleInputFieldChange : function(component, event){
    	var fieldName = event.getParam("fieldName");
        var value = event.getParam("value");
        var oppUpdate = component.get("v.oppUpdate");
        oppUpdate[fieldName] = value;
		component.set("v.oppUpdate", oppUpdate);  
        console.log(JSON.stringify(oppUpdate));
    },
    
    handleCancel : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    },
    
    navigateToOpp : function( component, event, helper ) {
        helper.navigateToRecord(component.get("v.clonedOppRecordId"));
    },
})