# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

# m365-physical-badging-connector-sample-scripts
This repository includes sample scripts for pushing organization's physical badging records, to be consumed by Microsoft's Insider Risk Management compliance solution. 

This repository includes a powershell script, a postman script ans a sample file containing physical badging records. You can send up to 100K records per API call.

## Creating AAD APP

Create you AAD APP https://docs.microsoft.com/en-us/azure/kusto/management/access-control/how-to-provision-aad-app

 Note the following
 - APP_ID (aka Application ID or Client)
 - APP_SECRET (aka client secret)
 - TENANT_ID (aka directory ID)

## Create your job on M365 Compliance portal

Provide required details at Physical Badging Connector and create a job and note the **JOB_ID**

## Run the powershell script
```powershell
.\push_physical_badging_records.ps1 -tenantId "<Tenant Id>" -appId "<AAD App Id>" -appSecret "<AAD App Secret>" -jobId "<Job Id>" -jsonFilePath "<JSON_FILE_PATH>"
```

JSON_FILE_PATH must be the local file path for the json data file.

If the last line reads **Upload Successful**, the script execution was successful.

The script would retry  over a period of about 15 mins if it encounters any transient failures.

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
		"User UPN" : {
			"description" : "Unique identifier AAD Id resolved by the source system",
			"type" : "string",
		},
		"Asset ID": {
			"description" : "Unique ID of the physical asset/access point",
			"type" : "string",
		},
		"AssetName": {
			"description" : "friendly name of the physical asset/access point",
			"type" : "string",
		},
		"Time" : {
			"description" : "timestamp of access",
			"type" : "string",
		},
		"AccessStatus" : {
			"description" : "what was the status of access attempt - Success/Failure",
			"type" : "string",
		},
	}
	"required" : ["User UPN", "Asset ID", "Time" "AccessStatus"]
}
```

## Common Errors and resolution

1. JOB_ID might be incorrect. Make sure it matches the one configured on M365 Compliance portal

> RetryCommand : Failure with StatusCode [Forbidden] and ReasonPhrase [jobId and corresponding appId do not match.]
> 

2. APP_ID or TENANT_ID might be incorrect.

> RetryCommand : {"error":"unauthorized_client","error_description":"AADSTS700016: Application with identifier '689412fa-4b24-475a-ab39-32eca848b6f2' was 
> not found in the directory '85ee0691-54d7-49f1-b879-3ce53c2a8549'. This can happen if the application has not been installed by the administrator of the 
> tenant or consented to by any user in the tenant. You may have sent your authentication request to the wrong tenant.}