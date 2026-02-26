## Description

### Purpose

Get EC2 instance Status, pull IIS Logs from S3 bucket and parse for error 500

### Assumptions
Some assumptions were made to produce this script. 

The IIS Logs of all instances are archived as **.zip** files to a specific S3 bucket (this can be specified by the user), with the InstanceID being the folder. 

	Example: *bucketname/folder/*
	iislogspowershell/i-xxxxxxxxxxxxxxxx/
		
It is also assumed that the archiving process is completed by another existing automation/script. 
## Getting Started

### Dependencies
- Requires [AWSPowershell](https://www.powershellgallery.com/packages/AWSPowerShell/)

- Require AWS Authentication -
	- [Using AWS Account SSO ](https://docs.aws.amazon.com/powershell/v5/userguide/creds-idc.html#login-con-creds) (Recommended)
```
	Invoke-AWSLogin
```
	- [AWS IAM Access Key](https://docs.aws.amazon.com/powershell/v5/userguide/specifying-your-aws-credentials.html#managing-profiles)  

- Requires correct permission where the script is executed (Does not require administrator PowerShell session)

- Bypass *PowerShell execution policy* (this requires administrator permissions)
	- Example - [Unblock a script without changing the policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.5#example-7-unblock-a-script-to-run-it-without-changing-the-execution-policy)
	- Example - [Bypass Policy for the current session](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.5#example-6-set-the-execution-policy-for-the-current-powershell-session)
```
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
```

### Installation

Download the script files and copy them into a folder with correct access and permission. Navigate to the folder in PowerShell and execute:

```
. .\s3IISLogParser.ps1
```

Now you can use the functions below to parse the IIS Logs.
### Usage

 - **Get-InstanceStatus500 -InstanceId**
		Pulls IIS logs from s3 bucket for the instance, counts and displays status 500 entries as well as instances status
```
Get-InstanceStatus500 -BucketName iislogsbucket -InstanceId i-xxxxxxxxxxxxxxxx
```
 ![[Pasted image 20260227023857.png]]
 - **Get-500Errors -LogPath**
	Parses IIS logs on local drive, counts and displays status 500 entries
		
```
Get-500Errors -LogPath "C:\temp\iislogs"
```
![[Pasted image 20260227023413.png]]

 - Get-S3Logs
	Pulls the logfiles for the specified EC2 Instance from s3

## Limitations
- There is currently no dedupe, log files with the same entries will be counted and listed. 

- Won't process logs with partially missing data, no error will be displayed.

- Files with correct log entries but missing the standard #Fields header line will not be processed. 

- Pulls and processes all files in the source/local folder

- The script does not automatically clean up the working directories

- The script does not warn or fail when no file is downloaded from s3 (Examples: Incorrect folder name (InstanceID) or the bucket being empty). However, it does warn when no zip files are processed.

- The script currently defaults to *iislogsbucket* as the s3 bucket

## Future Plans
1. Improve error catching

2. Further integrate the script with AWS native monitoring and alerting (CloudWatch, Event Bridge, SSM and SNS) As outlined in the description.

3. Allow users to specify date ranges (with a default of 24 hours)

4. Download from S3 will overwrite exiting files of the same name in the download folder

5. Self clean up download folder with option to clean up all working folders automatically
