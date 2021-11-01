<#
   
    .DESCRIPTION
        This script will create the package for the component provided in the CreatePackageRequest.json request by connecting to Boomi platform via Atomsphere API 
        note: provided the component ID in the CreatePackageRequest.json in the Requests directory must be a valid one.
    
    .Author
        Bala Gopinath.D 
#>


#API related headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "Basic ZGFnb3BpbmF0aEBkZWxvaXR0ZS5jb206U2lyaXNoYUAx")


#pointing to the parent directory from the current directory 
$folder = Get-Location | split-path

#pointing to the Requests directory
$path = $folder + "\Requests\CreatePackageRequest.json"

#Fetch the request json data
$body  = Get-Content $path | ConvertFrom-Json

#Fetch the componentID data
$componet_Ids = $body.componentId

$packageVersion = $body.packageVersion

foreach ($componet_Id in $componet_Ids) {

$response_filename = $componet_Id+".json"

echo "response file name : $response_filename"

$datetime = Get-Date -Format “yyyy-MM-ddTHH:mm:ss”

$body =  @"
{
    "componentId" : "$componet_Id",
    "packageVersion" : "$packageVersion",
    "notes" : "Deployment using Azure DevOps",
    "createdDate": "$datetime"
}
"@
echo $body

#$response_filename = "CreatePackageResponse.json"

try{

$response = Invoke-RestMethod 'https://api.boomi.com/api/rest/v1/trainingdamerlabalagopina-Q58IZ4/PackagedComponent' -Method 'POST' -Headers $headers -Body $body

$filename =$folder+"\Responses\" + $response_filename

$response | ConvertTo-Json | Out-File $filename

}
catch{

echo "In Catch"

if($_.ErrorDetails.Message)

 {
   $filename =$folder+"\Responses\" + $response_filename
    $_.ErrorDetails.Message | Out-File $filename

     throw $_.ErrorDetails.Message
 }

}

}

