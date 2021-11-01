# Write your PowerShell commands here.

Write-Host "Initiating Integration Unit Test"

<#
   
    .DESCRIPTION
        This script will invoke the Boomi processes to unit test using the Execution Request and Execution Record Atomsphere API's for Integration process
    .Author
        Bala Gopinath.D 
#>


#API related headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "Basic ZGFnb3BpbmF0aEBkZWxvaXR0ZS5jb206U2lyaXNoYUAx")

Function check-path-exits
{
    param($path_check)

    if(Test-Path -Path $path_check)
        {
            Write-Host "folder already exists at $path_check"
        }
    else
        {
            New-Item -Path $path_check -ItemType Directory        
        }
}


Function Archive-Inputs
{
		check-path-exits $input_folder_path
        check-path-exits $Integration_folder
        Get-ChildItem -Path $report_path -Recurse -Include $include | Copy-Item -Destination $Integration_folder #copy all the payloads with the filter
        check-path-exits $Test_Results_folder
        Get-ChildItem -Path $report_path -Recurse -Include "*.csv" | Copy-Item -Destination $Test_Results_folder #copy test result doc
}

#Function to archive the test results
Function call-Arch-Test-Results
{
    param($arch_path,$report_path)
    $Release_Number = $env:RELEASE_RELEASENAME
    $folder_name = "$arch_path\$Release_Number"
	$path_param = "Integration"
	$report_path = $report_path +$path_param+"\"
	$input_folder_path = $folder_name +"\Inputs\"
	$Integration_folder = $input_folder_path+ "Integration\"
	$Test_Results_folder = $folder_name+ "\Test_Results\"
	$include = @('*.json')

	check-path-exits $folder_name
    Archive-Inputs

    
}

#Function to update the Integration test report
Function call-UpdateIntegration-Report
{
    Param ($path_variable)
    $outfile_csv = $current_dir+ "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\$path_variable\IntegrationTestingReport.csv"
    $csvfile_csv = Import-Csv $outfile_csv
    $TestCases = $csvfile_csv.TestCaseName
    
	$Export_CSV_file_path = $current_dir+ "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\Integration\IntegrationTestingReport.csv"
	
    $Response_file_Path =  $current_dir+ "\_CICD-Boomi-CI\BoomiPackageResponse\Responses\unit_test\"
    
	#updating the actual status column for each test case in the Integration unit test report 
    foreach($TestCase in $TestCases)
    {
    
        foreach($row in $csvfile_csv)
        
        {
            if($row.TestCaseName -eq $TestCase )
            {
                $Respone_file = $Response_file_Path + $TestCase
                $Respone_file = Get-Content $Respone_file | ConvertFrom-Json
                $row.Actual_Result = $Respone_file.result.status
            }
        }
    
    }
    
    #updating the compated result column , by comparing the Expected result with Actual result
    foreach($line in $csvfile_csv)
    {
         if($line.Expected_Result -eq $line.Actual_Result)
            {
                $line.Compared_Result = $true
            }
         else
            {
                $line.Compared_Result = $false
            }
    
    }
    
    
    try #Checking the compared result column, if any of the value in Compared Result column fails the test case fails
        {
        
            foreach($record in $csvfile_csv)
                {
                    if ($record.Compared_Result -eq $true )
                        {
                            continue
                        }
    
                    elseif($record.Compared_Result -eq $false)
                        {
                            throw "Expected result and Actual result are not same....."
                        }
                  
                }
            $csvfile_csv | Export-Csv -Path $Export_CSV_file_path -NoTypeInformation
        
        }
    catch
        {
            $csvfile_csv | Export-Csv -Path $Export_CSV_file_path -NoTypeInformation
            throw "Expected result and Actual result are not same....."
    
    }
}



#function to get the status of the execution
Function call-Execution-Record
{
    
 $Exection_record_url = "https://api.boomi.com/api/rest/v1/trainingdamerlabalagopina-Q58IZ4/ExecutionRecord/async/$request_id"
 $Exection_record = Invoke-RestMethod -Uri $Exection_record_url -Method 'GET' -Headers $headers
 return $Exection_record

}



#function to run the unit test cases 
Function Unit-Test
{

Param ($path,$payloadName)

$outfile_csv = $path+"IntegrationTestingReport.csv"
$csvfile_csv = Import-Csv $outfile_csv

$testcases = $csvfile_csv.TestCaseName

foreach($testcase in $testcases){

$data = $path + $testcase

if (-not (Test-Path -Path $data)) {

     Write-Host 'The file does not exist'
     throw "The file $data does not exist"

 }

else{


$body_req = Get-Content $data 

$body_req = $body_req | ConvertFrom-Json 

$atom_Id =  $body_req.atomId
$processId = $body_req.processId
$min = $body_req.tof
$min = $min * 60
$DynamicProcessProperties =  $body_req.DynamicProcessProperties | ConvertTo-Json
$ProcessProperties = $body_req.ProcessProperties | ConvertTo-Json -Depth 4


$body = "{
	`"@type`": `"ExecutionRequest`",
    `"atomId`": `"$atom_Id`",
    `"processId`": `"$processId`",
    `"DynamicProcessProperties`":$DynamicProcessProperties ,
    `"ProcessProperties`" : $ProcessProperties
}"


Write-Host "$counter . -  Running Unit Test for test case $testcase "

$Execution_request_Id = Invoke-RestMethod 'https://api.boomi.com/api/rest/v1/trainingdamerlabalagopina-Q58IZ4/ExecutionRequest' -Method 'POST' -Headers $headers -Body $body
$request_id =  $Execution_request_Id.requestId

while($true){

    $Exection_record_invoke = call-Execution-Record


    if ($Exection_record_invoke.responseStatusCode -ne 200)
    {                
        Start-Sleep $min
        $Exection_record_invoke =  call-Execution-Record

    }
    elseif($Exection_record_invoke.result.status -ne "INPROCESS")
    {
        $save_response = $current_dir+"\_CICD-Boomi-CI\BoomiPackageResponse\Responses\unit_test\"+$testcase
        $Exection_record_invoke | ConvertTo-Json | Out-File $save_response
        break
    
    }
    


    }

    $counter = $counter + 1
}


}


}


try
{
	$current_dir = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
	Write-Host "Current :  $current_dir"
    $counter = 1 #Increments the value for each test case run, better understanding the script execution
	$UnitTest_Repost_arch_path = "C:\Users\dagopinath\Documents\Unit_Test_Arch" #path for archiving the unit test results
    $Unit_test_path = $current_dir+ "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\Integration\" #path for the integration test report
	$Unit_test_path_param= "Integration"
	$Unit_test_Report_File = $current_dir+ "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\"
    Unit-Test $Unit_test_path $Unit_test_payload_Name # calling the Unit test function to execute the test cases
    call-UpdateIntegration-Report $Unit_test_path_param # calling the update function to update the results
    call-Arch-Test-Results $UnitTest_Repost_arch_path $Unit_test_Report_File
    Write-Host "##vso[task.setvariable variable=IntegrationUnitTestResult;]$true"
    Write-Host "Set environment variable to $($env:IntegrationUnitTestResult)"
	
	

}
catch{

    #echo "in catch"
    $ErrorMessage = $_.Exception.Message
    echo $ErrorMessage
	$build_Integration_Unit_test = "false"
    Write-Host "##vso[task.setvariable variable=IntegrationUnitTestResult;]$false"
    Write-Host "Set environment variable to $($env:IntegrationUnitTestResult)"
    #throw "Unit testing failed beacuse $ErrorMessage"

}