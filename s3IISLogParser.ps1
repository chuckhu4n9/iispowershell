#This function pulls the IIS Logs from S3 buckets. Default bucket is set to iislogspowershell for testing purposes. The function requires InstanceID as input
function Get-S3Logs {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $false)]
        [string]$BucketName = "iislogspowershell"
    )

    # Define paths relative to current location for the download folder and the extract folder
    $localZipPath = ".\S3DL\$InstanceId"
    $extractPath = ".\ExtractedLogs\$InstanceId"

    try {
        # Ensure directories exist
        if (-not (Test-Path $localZipPath)) { New-Item -ItemType Directory -Path $localZipPath | Out-Null }
        if (-not (Test-Path $extractPath)) { New-Item -ItemType Directory -Path $extractPath | Out-Null }

        # Download from S3
        Write-Host "Downloading logs for $InstanceId from $BucketName..." -ForegroundColor Cyan
        Read-S3Object -BucketName $BucketName -KeyPrefix $InstanceId -Folder $localZipPath

        # Extract the files
        $zipFiles = Get-ChildItem -Path $localZipPath -Filter "*.zip" -File
        
        if ($zipFiles.Count -eq 0) {
            Write-Warning "No zip files found in $localZipPath"
            return
        }

        foreach ($file in $zipFiles) {
            try {
                Expand-Archive -Path $file.FullName -DestinationPath $extractPath -Force
                Write-Host "Successfully extracted: $($file.Name)" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to extract $($file.Name): $($_.Exception.Message)"
            }
        }

        Write-Host "Process complete. Logs located in: $extractPath" -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred during the S3 download process: $($_.Exception.Message)"
    }
}



function Get-500Errors {
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Enter the path to your log files or the folder containing them.")]
        [string]$LogPath
    )

    # If the path is a directory, append the *.log filter automatically
    if (Test-Path -Path $LogPath -PathType Container) {
        $SearchPath = Join-Path -Path $LogPath -ChildPath "*.log"
    }
    else {
        $SearchPath = $LogPath
    }

    try {
        # Get all log files in the specified path
        $logFiles = Get-ChildItem -Path $SearchPath -ErrorAction Stop
    }
    catch {
        Write-Host "Could not find any files at: $SearchPath" -ForegroundColor Red
        return
    }

    $errorFiles = 0
    Write-Host "Analyzing IIS logs in: $SearchPath" -ForegroundColor Cyan

    $errorEntries = foreach ($file in $logFiles) {
        try {
            $IISLogFileRaw = [System.IO.File]::ReadAllLines($file.FullName) 
            
            # IIS logs usually have headers on line 4 (index 3)
            $headers = $IISLogFileRaw[3].Split(" ")
            $headers = $headers | Where-Object { $_ -ne "#Fields:" -and $_ -ne "" } 

            # Validation for the header count
            if ($headers.Count -lt 1) {
                throw "Log file missing #Fields header."
            }

            # Import individual files for parsing
            Import-Csv -Path $file.FullName -Delimiter ' ' -Header $headers |
                # Filter out the comment lines and then find 500 status codes
                Where-Object { $_.date -notlike "#*" -and $_.'sc-status' -eq "500" } |
                Select-Object @{
                    Name="Timestamp"; 
                    Expression={[datetime]::Parse($_.date + " " + $_.time)}
                }, 'cs-uri-stem', 'c-ip', 'sc-status', 'sc-substatus', 'sc-win32-status'
        }
        catch {
            Write-Host "An unexpected error occurred with $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
            $errorFiles++
        }
    }

    # Display individual error entries
    if ($null -ne $errorEntries) {
        Write-Host "`n--- 500 Error Entries Found ---" -ForegroundColor Yellow
        $errorEntries | Format-Table -AutoSize
    }

    # Count and display total 500 errors
    $errorCount = ($errorEntries | Measure-Object).Count
    Write-Host "`n--- Summary ---" -ForegroundColor Cyan
    Write-Host "Total 500 errors found across all logs: $errorCount"
    Write-Host "Log files not processed: $errorFiles"
}


function Get-InstanceStatus500 {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InstanceId,

        [Parameter(Mandatory = $false)]
        [string]$BucketName = "iislogspowershell"
    )
    
     Get-S3Logs $InstanceId $BucketName
     $extractPath = ".\ExtractedLogs\$InstanceId"
     Get-500Errors $extractPath

    # Get all status info
    $statuses = Get-EC2InstanceStatus -InstanceId $InstanceId

    $statuses | ForEach-Object {
        $status = $_
        # Fetch the name tag for this specific instance
        $instance = Get-EC2Instance -InstanceId $status.InstanceId
        $nameTag = ($instance.Instances.Tags | Where-Object { $_.Key -eq "Name" }).Value

        [PSCustomObject]@{
            Name           = $nameTag
            InstanceId     = $status.InstanceId
            InstanceState  = $status.InstanceState.Name
            InstanceHealth = $status.InstanceStatus.Status
            SystemHealth   = $status.SystemStatus.Status
        }
    } | Format-Table -AutoSize
     

}