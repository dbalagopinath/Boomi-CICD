# Write your PowerShell commands here.

Write-Host "Initiating API Unit Test"

<#
   
    .DESCRIPTION
        This script will invoke the APi listed in the API IntegrationTestingReport.csv file and will update the actual results and performs a check to verify if the expected and actual results are matching. If not, it marks the unit testing as failed
    .Author
        Bala Gopinath.D 
#>

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
     Get-ChildItem -Path $report_path -Recurse -Exclude $Exclude | Copy-Item -Destination $Integration_folder #copy all the payloads with the filter 
     check-path-exits $Test_Results_folder
     Get-ChildItem -Path $report_path -Recurse -Include "*.csv" | Copy-Item -Destination $Test_Results_folder #copy test result doc

}

#Function to archive the test results
Function call-Arch-Test-Results
{
    param($arch_path,$report_path)
    $Release_Number = $env:RELEASE_RELEASENAME
    $folder_name = "$arch_path\$Release_Number"
	$path_param = "API"
	$report_path = $report_path +$path_param+"\" #path where all the payloads and test results of Integration documents exists 
    $input_folder_path = $folder_name +"\Inputs\" #path for creation of the input folder inside the release folder
    $Integration_folder = $input_folder_path+ "API\" # path for creation of the integration folder for test payloads archive 
    $Test_Results_folder = $folder_name+ "\Test_Results\"
    $Exclude = @('*.csv') #file filter to read all the test paylaods 
	
	check-path-exits $folder_name
    Archive-Inputs

   
    
    
}

Function extractHeaders
{

param($decodeString)

$decodeString = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($decodeString))

$decodeString =  ConvertFrom-StringData -StringData $decodeString

return $decodeString

}

Function generate-BasicAuth
{
    param($username, $password)
    $auth = $username + ':' + $password
    $Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
    $authorizationInfo = [System.Convert]::ToBase64String($Encoded)
    $headers = @{"Authorization"="Basic $($authorizationInfo)"}
    return $headers    

}

Function check-Responses
{
                if($response.Headers.'Content-Type' -ne $null)
                    {
                        if ($response.Headers.'Content-Type'.Contains($row.Expected_Output_Type))
                        {
                            #Write-Host "In headers"
                            $row.Actual_Output_Type = $row.Expected_Output_Type
                        }
                    }
                else
                    {
                            #Write-Host "In headers is else"
                            $row.Actual_Output_Type = "None"
                    
                    }
                
               if ($response.StatusCode -eq $row.Expected_Status_Code)
                    {

                            #Write-Host "In StatusCode"
                            $row.Actual_Status_Code = $row.Expected_Status_Code
                    }                    
               else
                    {
                            #Write-Host "In StatusCode in else"
                            $row.Actual_Status_Code = $response.StatusCode
                    }

}

Function Api-unit-test
{

foreach($row in $csv)
    {
      

      if($row.Authorization_Type -eq "Basic" )
      {
            $headers= extractHeaders $row.Headers
            $url = $row.Resource_URL
            $method = $row.Method
            
        if( $row.Method -eq 'GET')
    
            {
                 try
                 {
                    Write-Host "$counter . -  GET API call Initiated "
                    $response = Invoke-WebRequest -Uri $url -Method $method -Headers $headers
                    check-Responses

                 }

                 catch [System.Net.WebException]
                 {
                    Write-Host "$counter . -  GET API call received $_.Exception.Response.StatusCode as status code "
                    $response = [PSCustomObject]@{StatusCode=[int]$_.Exception.Response.StatusCode;Headers=$_.Exception.Response.Headers}
                    check-Responses
                 }
                 catch
                    {
                        Write-Host "$counter . -  GET API call is failed because of $_.Exception.Message"
                    }
       
            }

        if($row.Method -eq "POST"){


            try
                {
                     Write-Host "$counter . -  POST API call Initiated "
                     $Payload_filename = $row.TestCaseName
                     $payload_file = $current_dir +"\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\API\" + $Payload_filename

                     if (-not (Test-Path -Path $payload_file))
                     
                     {
                         
                         throw "The file $Payload_filename does not exist"
                     }
                     else
                     {
                            
                        $body = Get-Content $Payload_file
                        
                        
                        $headers= extractHeaders $row.Headers
                        $url = $row.Resource_URL
                        $method = $row.Method
                        $response = Invoke-WebRequest -Uri $url -Method $method -Headers $headers -Body $body
                        check-Responses
                     }
                
                }
            
           
           catch [System.Net.WebException]
                 {
                 
                    Write-Host "$counter . -  POST API call received $_.Exception.Response.StatusCode as status code "                   
                    $response = [PSCustomObject]@{StatusCode=[int]$_.Exception.Response.StatusCode;Headers=$_.Exception.Response.Headers}
                    check-Responses
                 }
           catch
                {
                    Write-Host "$counter . -  POST API call is failed because of $_.Exception.Message"
                }
        
        }
      
      }

      if($row.Authorization_Type -eq "Oauth2.0" )
      {
            
            try
            
                {
                    Write-Host "$counter . -  Oauth API call Initiated "
            
                    $auth_headers = extractHeaders $row.Oauth_Token_Headers
                    $auth_token_headers = generate-BasicAuth $auth_headers.Username $auth_headers.Password
                    $access_token_url = $row.Access_Token_URL
                    $response_token = Invoke-WebRequest -Uri $access_token_url -Method POST -Headers $auth_token_headers
                    $response_token = $response_token.Content | ConvertFrom-Json
                    
                    
                    $headers  = @{"Authorization"="Bearer $($response_token.access_token)";"Accept"="*/*";"Content-Type"="application/xml"}
                    $url = $row.Resource_URL
                    $method =$row.Method

                    if($row.Method -eq 'GET')
                        {
                            Write-Host "$counter . - IN Oauth Get API call for Initiated for resource URL"
                            $response = Invoke-WebRequest -Uri $url -Method $method -Headers $headers
                            check-Responses
                        }
                    if($row.Method -eq "POST")
                        {
                             Write-Host "$counter . - IN Oauth POST API call for Initiated for resource URL"
							 
							 $Payload_filename = $row.TestCaseName
							 $payload_file = $current_dir+"\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\API\" + $Payload_filename


                             if (-not (Test-Path -Path $payload_file))
                             
                             {
                                 
                                 throw "The file $Payload_filename does not exist"
                             }
                             else
                             {
                                $req_body = Get-Content $payload_file
                                $response = Invoke-WebRequest -Uri $url -Method $method -Headers $headers -Body $req_body
                                check-Responses
                             }
                        }
        
                }
                catch [System.Net.WebException]
                 {
                    Write-Host "$counter . -  Oauth call received $_.Exception.Response.StatusCode as status code "  
                    $response = [PSCustomObject]@{StatusCode=[int]$_.Exception.Response.StatusCode;Headers=$_.Exception.Response.Headers}
                    check-Responses
                 }

                catch
                 {
                    Write-Host "$counter . -  Oauth API call is failed because of $_.Exception.Message"
                 }
           
      }

      $counter = $counter + 1
    
    
}

}

Function check-output-type
{
    foreach($row in $csv)
    {
                 If($row.Expected_Output_Type -eq $row.Actual_Output_Type){
                        
                        $row.Compared_Output_Type_Result = $true
                 }
                 if($row.Expected_Output_Type -ne $row.Actual_Output_Type){
                    
                        $row.Compared_Output_Type_Result = $false
                 }

                 if($row.Expected_Status_Code -eq $row.Actual_Status_Code){
                        
                        $row.Compared_Status_Code_Result = $true
                 }
                 if($row.Expected_Status_Code -ne $row.Actual_Status_Code){
                        
                        $row.Compared_Status_Code_Result = $false
                 }

             }
}        

Function check-compared-result
{
    foreach($row in $csv)
    {
           if( ($row.Compared_Output_Type_Result -eq $true) -and ($row.Compared_Status_Code_Result -eq $true)  )
                {
                    $row.Compared_Result = $true
                }
            else
                {
                    $row.Compared_Result = $false
                }

     }
}

Function call-UpdateApi-Report
{

$Export_CSV_file_path = $current_dir + "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\API\APITestingReport.csv"

try
    {
        foreach($row in $csv)
             {
                if($row.Compared_Result -eq $true)
                    {
                        continue
                    }
                elseif($row.Compared_Result -eq $false)
                    {
                         throw "Expected and Actual Results are not matching... "
                    }


             }
        $csv | Export-Csv -Path $Export_CSV_file_path -NoTypeInformation
    
    }

catch
    {
        $csv | Export-Csv -Path $Export_CSV_file_path -NoTypeInformation
        throw "Expected and Actual Results are not matching... "

    }

}

#Main executoin starts here..
try
{	
	$current_dir = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
	Write-Host "Current :  $current_dir"
	$csv_path = $current_dir + "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\API\APITestingReport.csv"
    $csv = Import-Csv $csv_path
	$Unit_test_path = $current_dir+ "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\API\"
	$Unit_test_Report_File = $current_dir+ "\_CICD-Boomi-CI\BoomiPackageResponse\Requests\UnitTest\"
	$UnitTest_Repost_arch_path = "C:\Users\dagopinath\Documents\Unit_Test_Arch"
    $counter = 1
    Write-Host "Initiating Unit test step"
    Api-unit-test
    Write-Host "Initiating Check output type step"
    check-output-type
    Write-Host "Initiating Compared results step"
    check-compared-result
    Write-Host "Initiating Update API report step"
    call-UpdateApi-Report
    Write-Host "Initiating Archieve step"
    call-Arch-Test-Results $UnitTest_Repost_arch_path $Unit_test_Report_File
    Write-Host "##vso[task.setvariable variable=APIUnitTestResult;]$true"
    Write-Host "Set environment variable to $($env:APIUnitTestResult)"
	
	
}
catch
{
    Write-Host "##vso[task.setvariable variable=APIUnitTestResult;]$false"
    Write-Host "Set environment variable to $($env:APIUnitTestResult)"
    $ErrorMessage = $_.Exception.Message
     Write-Host "Unit testing failed beacuse $ErrorMessage"
    #throw "Error : Unit testing failed beacuse $ErrorMessage"

    
}