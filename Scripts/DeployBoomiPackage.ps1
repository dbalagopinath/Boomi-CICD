<#
   
    .DESCRIPTION
        This script will deploy the package for the pacakage ID in the CreatePackageResponse.json by connecting to Boomi platform via Atomsphere API 
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
$path = $folder + "\Responses\*.json"

$files = Get-ChildItem $path

foreach ($file in $files) {

$body = Get-Content $file 

$x = $body | ConvertFrom-Json

$packageId = $x.packageId

echo "This is pacakge id : $packageId"

$Environment_Id = $args[0]

$payload = @"
{
    "environmentId" : "27db8ca4-dd55-4d21-a253-013966f5a76a",
    "packageId" : "$packageId",
    "notes" : "Package deployment via CICD"
}
"@


$body = $payload

echo $body

$response_filename = "Deployment_"+$x.componentId+".json"

echo "this is file name $response_filename "

try{

$response = Invoke-RestMethod 'https://api.boomi.com/api/rest/v1/trainingdamerlabalagopina-Q58IZ4/DeployedPackage' -Method 'POST' -Headers $headers -Body $body

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

