<#
   
    .DESCRIPTION
        This script will perform a clean up on the Responses folder.
    
    .Author
        Bala Gopinath.D 
#>


#pointing to the parent directory from the current directory 
$folder = Get-Location | split-path

#pointing to the Requests diryector
$path = $folder + "\Responses\"

echo "Deleteing...."

Get-ChildItem -Path $path -Include *.* -File -Recurse | foreach { $_.Delete()}

echo "Deleteing completed...."