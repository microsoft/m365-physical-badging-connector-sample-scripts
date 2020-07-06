## JSON Schema

JSON schema below details all the fields to be sent as part of Physical badging records you will share with us. Please make sure you follow this as a reference while forming JSON payload. 

Schema:
```
{
	"title" : "Physical Badging Signals",
	"description" : "Access signals from physical badging systems",
	"DataType" : {
		"description" : "Identify what is the data type for input signal",
		"type" : "string",
	},
	"type" : "object",
	"properties": {
		"UserId" : {
			"description" : "Unique identifier AAD Id resolved by the source system",
			"type" : "string",
		},
		"AssetId": {
			"description" : "Unique ID of the physical asset/access point",
			"type" : "string",
		},
		"AssetName": {
			"description" : "friendly name of the physical asset/access point",
			"type" : "string",
		},
		"EventTime" : {
			"description" : "timestamp of access",
			"type" : "string",
		},
		"AccessStatus" : {
			"description" : "what was the status of access attempt - Success/Failure",
			"type" : "string",
		},
	}
	"required" : ["UserId", "AssetId", "EventTime" "AccessStatus"]
}
```
