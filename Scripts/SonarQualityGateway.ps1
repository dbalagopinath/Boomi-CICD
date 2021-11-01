$folder = Get-Location | split-path

$SonarToken = "e121b36f2e7d7457e455692d7b884812478c525b"

$token = [System.Text.Encoding]::UTF8.GetBytes($SonarToken + ":")
$base64 = [System.Convert]::ToBase64String($token)
 
$basicAuth = [string]::Format("Basic {0}", $base64)
$headers = @{ Authorization = $basicAuth }

$response_filename = "SonarQube_Gateway_Status_Report.json"
 
$result = Invoke-RestMethod -Method Get -Uri http://localhost:9000/api/qualitygates/project_status?projectKey=Boomi_CICD_Analysis -Headers $headers
$result | ConvertTo-Json | Write-Host
 
if ($result.projectStatus.status -eq "OK") {

    Write-Host "Quality Gate Succeeded"
}
else
{
    $filename =$folder+"\Responses\" + $response_filename
    $result | ConvertTo-Json | Out-File $filename
    throw "Quality gate failed"
}