###########################################################################
# Created by Anthony Gil, Informatica 
# Use at your own risk.No warranty implied or otherwise
# This should help you install a Secure Agent on Linux using Python 2 and 3
# Feel free to modify and use.... but beware, I am not a programmer. 
###########################################################################
# Secure Agent Silent Install Information 
#       https://knowledge.informatica.com/s/article/HOW-TO-Install-the-Informatica-Cloud-Secure-Agent-in-Silent-Mode?language=en_US

# Informatica Cloud REST API 
#       https://developer.informatica.com/tpn/v2.0/reference/welcome#rest-api-versions-1


# requires libnsl
import requests
import json
import subprocess
import os
import time
import getpass

#only issue with support Python2 and Python3 is the input.. so... Quick and dirty overwriting of it. 
try:
    input = raw_input
except NameError:
    pass

os.system("clear")
print("**********************************************************")
print("******************    Installing IICS   ******************")
print("**********************************************************")
print('')

#url = "https://dm-us.informaticacloud.com/ma/api/v2/user/login"
url = ''
installDir = "" # make sure directory exists or is at least writable 
username = ""
password = ""
region = ""

while password == "" or username == "" or installDir == "": 
    try: 
        print("**********************************************************")
        print("****************    Enter Credentials   ******************")
        print("**********************************************************")
        print('')
        username = input("Username: ")
        assert isinstance(username, str)
        password = getpass.getpass("Password")
        installDir = input('Install Directory: ')
        assert isinstance(installDir, str)
    except Exception as error:
        print('ERROR', error)

    while region == "": 
        try: 
            print("**********************************************************")
            print("*******************    Enter Region   ********************")
            print("**********************************************************")
            print('')
            print("Please enter authentication region (us, em, ap)")
            print("us for North America")
            print("em for Europe")
            print("ap for Asia / Pacific")
            print("")
            region = input("Region: ")
            assert isinstance(region, str)
        except Exception as error:
            print('ERROR', error)

url = 'https://dm-'+region+'.informaticacloud.com/ma/api/v2/user/login'
        
if installDir[-1] != '/':
    installDir = installDir + '/'

payload = {
    "username": username,
    "password": password
}
headers = {
    "Accept": "application/json",
    "Content-Type": "application/json"
}
print('')
print("**********************************************************")
print("********************    Logging In   *********************")
print("**********************************************************")
print('')

response = requests.request("POST", url, json=payload, headers=headers)
resObj = json.loads(response.text)
print(resObj)

print('')
print("**********************************************************")
print("*****************    Getting Installer   *****************")
print("**********************************************************")
print('')


url = resObj['serverUrl'] + '/api/v2/agent/installerInfo/linux64'

headers = {
    "icSessionId": resObj['icSessionId'],
    "Accept": "application/json",
    "Content-Type": "application/json"
}

response = requests.request("GET", url, headers=headers)
resObj = json.loads(response.text)
print(resObj)

print('')
print("**********************************************************")
print("***************    Downloading Installer   ***************")
print("**********************************************************")
print('')



response = requests.request("GET", resObj['downloadUrl'], headers=headers)

open('agent64_install_ext.bin', 'wb').write(response.content)

args = ("chmod", "+x", "agent64_install_ext.bin")
popen = subprocess.Popen(args, stdout=subprocess.PIPE)
popen.wait()
output = popen.stdout.read()
print(output)
print("File downloaded successfully")
print("File made executable")

print('')
print("**********************************************************")
print("********************    Installing   *********************")
print("**********************************************************")
print('')
args = ("./agent64_install_ext.bin", "-i", "silent", "-DUSER_INSTALL_DIR="+installDir)
popen = subprocess.Popen(args, stdout=subprocess.PIPE)
popen.wait()
output = popen.stdout.read()
#print(output)
x = 0
while x <10:
    if os.path.isfile(installDir+"apps/agentcore/infaagent") == False:
        x+=1
        time.sleep(3)
    else:
        x=10
os.system("rm install.py agent64_install_ext.bin")
os.chdir(installDir+"apps/agentcore/")

serviceStart = os.system("./infaagent startup")
if serviceStart != 0:
    print("SecureAgent failed with non-zero (0) exit code")
    print("Please check logs for errors")
else:
    print("Successfully Started the service")
    x=0
    while x<10:
        status = os.popen("./consoleAgentManager.sh getStatus").read()
        print(status)
        if status.strip() != 'NOT_CONFIGURED':
            print('Waiting for the Agent services to be running')
            time.sleep(1)
            x+=1
        else:
            login = os.system("./consoleAgentManager.sh configureToken " + username + " " + resObj['installToken'])
            print("")
            print("If output shows error, please configure manually with the following commands")
            print("cd "+installDir+"apps/agentcore/")
            print("./consoleAgentManager.sh configureToken " + username + " " + resObj['installToken'])
            x=10

print('')
print("**********************************************************")
print("********************    Installed!   *********************")
print("**********************************************************")
print('')

x=0
status = os.popen("./consoleAgentManager.sh getStatus").read()
while status.strip() != 'NOT_CONFIGURED' and status.strip() != 'INITIALIZING' and status.strip() != 'READY' and x<10:
    print('Waiting for Deployment......Current Status: ' + status)
    x+=1
    time.sleep(1)
    status = os.popen("./consoleAgentManager.sh getStatus").read()

print(status)
