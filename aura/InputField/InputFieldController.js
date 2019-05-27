({
	doInit : function(component, event, helper) {
        let name = component.get("v.name");
        let opp = component.get("v.oppRecord");
        console.log(name);
        console.log(JSON.stringify(opp));
        if(opp != undefined && opp[name] != undefined){
            component.set("v.value", opp[name]);	
        }
	},
    
    onChange : function(component, event){
        var compEvent = component.getEvent("inpFieldChangedEvt");
        var fieldName = component.get("v.name");
        var value = event.getParam("value")
        compEvent.setParams({"fieldName" : fieldName, "value" : value });
        compEvent.fire();
    }
})