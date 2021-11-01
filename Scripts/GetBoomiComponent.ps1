<#
   
    .DESCRIPTION
        This script will fetch the Boomi component XML by connecting to Boomi platform via Atomsphere API 
        note: provided the component ID in the CreatePackageRequest.json in the Requests directory.
    
    .Author
        Bala Gopinath.D 
#>



#pointing to the parent directory from the current directory 
$folder = Get-Location | split-path

#pointing to the Requests directory
$path = $folder + "\Requests\CreatePackageRequest.json"

#Fetch the request json data
$componet_Ids  = Get-Content $path | ConvertFrom-Json

#Fetch the componentID data
$componet_Ids = $componet_Ids.componentId


foreach ($componet_Id in $componet_Ids) {


echo "componet_Id : $componet_Id"


#API related headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Basic ZGFnb3BpbmF0aEBkZWxvaXR0ZS5jb206U2lyaXNoYUAx")
$url = 'https://api.boomi.com/api/rest/v1/trainingdamerlabalagopina-Q58IZ4/Component/'+$componet_Id

echo $url

#calling API
[xml]$component_xml = Invoke-WebRequest $url -Method 'GET' -Headers $headers 

#wirintg the response to Responses directory
$filename = $componet_Id+".xml"
$filename =$folder+"\Responses\"+ $filename
echo $filename
$component_xml.Save($filename)

}