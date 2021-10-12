# Author: Anthony Gil, Informatica
# Notes: This is to be used at your own risk.  Not warranty implied or otherwise.  Feel free to modify and redistribute. 
# To be blunt.. I am not a progammer.

# Secure Agent Silent Install Information 
#       https://knowledge.informatica.com/s/article/HOW-TO-Install-the-Informatica-Cloud-Secure-Agent-in-Silent-Mode?language=en_US

# Informatica Cloud REST API 
#       https://developer.informatica.com/tpn/v2.0/reference/welcome#rest-api-versions-1

##################################################################
#########################  BEGIN SCRIPT  #########################
##################################################################

#check to see if Admin, if not Admin, open new window with elevated privs. 
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
    Clear-Host
   
    # Some sytems arent setup with connecting ot TLS 1.2 sites.. This enables. 
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   
   ##################################################################
   #####################  SETTING UP VARIABLES  #####################
   ##################################################################
   
   $installer = 'C:\infaSAinstaller.exe' #Path to downloads folder and file name for installer... Fails if directory doesnt exist.
   $installDir = 'C:\Program Files\Informatica Cloud Secure Agent' #Default install dir
   $username = '' #Change to your username (for the org you want to install the SA into)
   $password  = '' #password for the username you chose
   #$loginUrl = ''
   $region = ''

   while (($username -eq '') -or ($password -eq '')) {
    Write-Output "No Username/Password set, please enter now: "
    $username = Read-Host "Please Enter Username: "
    $password = Read-Host "Please enter Password: " -AsSecureString
    $password = ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)))
   }

   while (($region -ne 'us') -and ($region -ne 'em') -and ($region -ne 'ap')) {
    Write-Output "Please enter authentication region (us, em, ap)"
    Write-Output "us for North America"
    Write-Output "em for Europe"
    Write-Output "ap for Asia / Pacific"
    Write-Output ""
    $region = Read-Host "Please enter region: "
   }

$loginUrl = 'https://dm-'+$region+'.informaticacloud.com/ma/api/v2/user/login'
  
        
   Write-Output '##################################################################'
   Write-Output '######################  Logging into IICS  #######################'
   Write-Output '##################################################################'
   $headers=@{}
   $headers.Add("Accept", "application/json")
   $headers.Add("Content-Type", "application/json")
   
   $response = Invoke-WebRequest -Uri $loginUrl -Method POST -Headers $headers -ContentType 'application/json' -Body "{`"username`":`"$username`",`"password`":`"$password`"}" 
   if ($response.StatusCode -ne 200) {
       Write-Output "Something happened: Did not get a 200 OK message from the Informatica API"
       Write-Output $response
       Write-Output $loginUrl
       exit
       }
   $response = $response | ConvertFrom-Json
   
   Write-Output 'Logged in successfully as:'
   Write-Output ''
   Write-Output $response
   Write-Output ''
   Write-Output '##################################################################'
   Write-Output '#################  Getting Install Information  ##################'
   Write-Output '##################################################################'
   $headers.Add("icSessionId", $response.icSessionId)
   $serverUrl = $response.serverUrl
   $endpoint = '/api/v2/agent/installerInfo/win64' # Windows Version hardcoded...  
   $response = Invoke-WebRequest -Uri $serverUrl$endpoint  -Method GET -Headers $headers 
   if ($response.StatusCode -ne 200) {
       Write-Output "Something happened: Did not get a 200 OK message from the Informatica API"
       Write-Output $response
       Write-Output $serverUrl$endpoint
       exit
       }
   $response = $response | ConvertFrom-Json
   
   Write-Output 'Succesfully got Secure Agent install information'
   Write-Output ''
   Write-Output $response
   Write-Output ''
   
   Write-Output '##################################################################'
   Write-Output '##############  Downloading Secure Agent Installer  ##############'
   Write-Output '##################################################################'
   $download = Invoke-WebRequest -Uri $response.downloadUrl -OutFile $installer
   
   Write-Output 'Succesfully Downloaded Secure Agent'
   Write-Output ''
   Write-Output 'File Location '$installer
   Write-Output "StatusCode: "$download.StatusCode
   Write-Output ''
   Write-Output '##################################################################'
   Write-Output '###################  Installing Secure Agent  ####################'
   Write-Output '##################################################################'
   $arg1 = '-i'
   $arg2 = 'silent'
   $arg3 = "-DUSER_INSTALLATION_DIR=`"$installDir`""
   & $installer $arg1 $arg2 $arg3
   while (!(Test-Path "$installDir\apps\agentcore\consoleAgentManager.bat")) { 
       Start-Sleep 10
       Write-Output "Waiting for IICS to be installed..."
    }
   
   
   Write-Output ''
   Write-Output '##################################################################'
   Write-Output '####################  Starting Secure Agent  #####################'
   Write-Output '##################################################################'
   
   $service = "InformaticaCloudSecureAgent"
   $status = Get-Service $service
   while(!($status.Status -eq 'Running')){
       Start-Sleep 10
       $status = Get-Service $service
       Write-Output 'Waiting for Informatica Cloud Secure Agent Service to be running...'
       Write-Output $status
       if($status.Status -eq 'Stopped'){
           Start-Service -Name $service
           }
   }
   Start-Sleep 10
   Write-Output 'Informatica Cloud Secure Agent service is running!'
   Write-Output ''
   Write-Output $status
   
   
   $installToken = $response.installToken
   
   try {
       Write-Output ''
       Write-Output '##################################################################'
       Write-Output '###################  Configuring Secure Agent  ###################'
       Write-Output '##################################################################'
       & "$installDir\apps\agentcore\consoleAgentManager.bat" configureToken $username $installToken
   }
   catch {
   
   Write-Output 'First try failed.'
   Write-Output 'Sleeping for 3 Minutes to get Services running.' #This is overkill, but if automated, not a big deal. 
       Start-Sleep 180
       & "$installDir\apps\agentcore\consoleAgentManager.bat" configureToken $username $installToken
   }
   Write-Output ''
   if($LASTEXITCODE -eq 255){
       Write-Output 'Error:  The configuration did not complete. Please manually configure.'
   } else {
        Write-Output 'Congrats!  The Secure Agent is installed.  Please wait while we upload the engines (approx 30 min).'
        Remove-Item $installer
   }
   
