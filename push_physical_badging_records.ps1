# Usage: .\push_physical_badging_records.ps1 -tenantId "<Tenant Id>" -appId "<AAD App Id>" -appSecret "<AAD App Secret>" -jobId "<Job Id>" -jsonFilePath "<JSON_FILE_PATH>"

param
(   
    [Parameter(mandatory = $true)]
    [string] $tenantId,
    [Parameter(mandatory = $true)]
    [string] $appId,
    [Parameter(mandatory = $true)]
    [string] $appSecret,
    [Parameter(mandatory = $true)]
    [string] $jobId,
    [Parameter(mandatory = $true)]
    [string] $jsonFilePath
)

# Access Token Config
$oAuthTokenEndpoint = "https://login.windows.net/$tenantId/oauth2/token"
$resource = 'https://microsoft.onmicrosoft.com/4e476d41-2395-42be-89ff-34cb9186a1ac'

# End point config
$eventApiUrl = "https://webhook.ingestion.office.com"
$eventApiEndpoint = "api/signals/physicalbadging"

function GetAccessToken () {
	Write-Host -fore green "******Getting Access Token******"
    # Token Authorization URI
    $uri = "$($oAuthTokenEndpoint)?api-version=1.0"

    # Access Token Body
    $formData = 
    @{
        client_id     = $appId;
        client_secret = $appSecret;
        grant_type    = 'client_credentials';
        resource      = $resource;
        tenant_id     = $tenantId;
    }

    # Parameters for Access Token call
    $params = 
    @{
        URI         = $uri
        Method      = 'Post'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = $formData
    }

    $response = Invoke-RestMethod @params -ErrorAction Stop
	Write-Host -fore green "******Access Token Acquired******"
    return $response.access_token
}

function RetryCommand {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1, Mandatory = $false)]
        [int]$Maximum = 15
    )

    Begin {
        $cnt = 0
    }

    Process {
        do {
            $cnt++
            try {
                $ScriptBlock.Invoke()
                return
            }
            catch {
                Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
                Start-Sleep 60
                if ($cnt -lt $Maximum) {
                    Write-Output "Retrying"
                }
            }
            
        } while ($cnt -lt $Maximum)

        throw 'Execution failed.'
    }
}

function WriteErrorMessage($errorMessage) {
    $Exception = [Exception]::new($errorMessage)
    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
        $Exception,
        "errorID",
        [System.Management.Automation.ErrorCategory]::NotSpecified,
        $TargetObject
    )
    $PSCmdlet.WriteError($ErrorRecord)
}

function PushPhysicalBadgingRecords ($access_token) {
    $nvCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty) 
    $nvCollection.Add('jobid', $jobId)
    $uriRequest = [System.UriBuilder]"$eventApiUrl/$eventApiEndpoint"
    $uriRequest.Query = $nvCollection.ToString()

    $url = $uriRequest.Uri.OriginalString

    try{
		$json = Get-Content $jsonFilePath
    }catch{
        WriteErrorMessage("Error reading from file. Please check if path is correct")
        return
    }
	
	$headers = @{
		"Accept"="application/json"
		"Authorization"="Bearer $access_token"
		"Content-Type"="application/json"
	} 
	
    try {
		$result = Invoke-WebRequest -Uri $url -Method POST -Body $json -Headers $headers -TimeoutSec 300
    }
    catch {
		WriteErrorMessage($_)
        return
    }

	$status_code = [int]$result.StatusCode
    if ($status_code -eq 200 -or $status_code -eq 201) {
		Write-Host -fore green "******Upload Successful******"
		Write-Output $result.Content
    }
    elseif ($status_code -eq 0 -or $status_code -eq 501 -or $status_code -eq 503) {
        throw "Service unavailable."
    }
    else {
        WriteErrorMessage("Failure with StatusCode [{0}] and ReasonPhrase [{1}]" -f $result.StatusCode, $result.ReasonPhrase)
    }
}

RetryCommand -ScriptBlock {
    $access_token = GetAccessToken
    PushPhysicalBadgingRecords($access_token)
}
