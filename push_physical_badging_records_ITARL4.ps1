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
    [string] $jsonFilePath,
    [Parameter(mandatory = $false)]
    [Int] $retryTimeout = 60
)

# Access Token Config
$oAuthTokenEndpoint = "https://login.microsoftonline.us/$tenantId/oauth2/token"
$resource = 'https://gsgotrs.onmicrosoft.com/66ace435-1e6f-4305-8abc-96f365388077'

# End point config
$eventApiURl = "https://webhook-itarl4.ingestion.office365.us"
$eventApiEndpoint = "api/signals/physicalbadging"

$chunkSize = 50000

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
        [int]$Maximum = 5
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
                Write-Host ("Will retry in [{0}] seconds" -f $retryTimeout)
                Start-Sleep $retryTimeout
                if ($cnt -lt $Maximum) {
                    Write-Host "Retrying"
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

    try {
        $allRecords = Get-Content $jsonFilePath | ConvertFrom-Json
    }
    catch {
        WriteErrorMessage("Error reading from file. Please check if path is correct. File is not being used elsewhere and file is a valid json data")
        return
    }
    
    for ($i = 0; $i -lt $allRecords.count; $i += $chunksize) {
        $Chunks += , @($allRecords[$i..($i + $chunksize - 1)]);
    }
    
    $headers = @{
        "Accept"        = "application/json"
        "Authorization" = "Bearer $access_token"
        "Content-Type"  = "application/json"
    } 
    
    $chunkCount = 0
    foreach ($chnk in $Chunks) {
        $chunkCount = $chunkCount + 1
        Write-Host -fore yellow "Processing chunk $chunkCount of $($Chunks.Count) with $($chnk.Length) records"
        $jsonChunk = $chnk | ConvertTo-Json
        try {
            $result = Invoke-WebRequest -Uri $url -Method POST -Body $jsonChunk -Headers $headers -TimeoutSec 400
        }
        catch {
            WriteErrorMessage($_)
        }
        
        $status_code = [int]$result.StatusCode
        if ($status_code -eq 200 -or $status_code -eq 201 -or $status_code -eq 207) {
            Write-Host -fore green "******Upload Successful******"
            Write-Host $result.Content
        }
        elseif ($status_code -eq 0 ) {
            throw "Service unavailable."
        }
        else {
            $errorstring = "Failure with StatusCode [{0}] and ReasonPhrase [{1}]" -f $result.StatusCode, $result.ReasonPhrase
            WriteErrorMessage($errorstring)
            throw $errorstring
        }
    }
}

RetryCommand -ScriptBlock {
    $access_token = GetAccessToken
    PushPhysicalBadgingRecords($access_token)
}
