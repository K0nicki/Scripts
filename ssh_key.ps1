# Generate ssh a pair of authentication keys in order to not entering 
# password each time when sending files to server

$USER = 'konrad'
$ADDR = '192.168.56.105'                        
$SSH_PATH = $USER + '@' + $ADDR                                     # VM USER@ADDRESS
$SCRIPT_PATH = $PSScriptRoot + '\' + $MyInvocation.MyCommand.Name   # WORKDIR\SCRIPT_NAME


# Check state of the OpenSSH server service
function isOpenSSH {

  # Save information in .log file
  $LOG_PATH = "$PSScriptRoot\OpenSSH.log"

  Get-Service >$LOG_PATH

  # Read content, looking for ssh-agent
  $state = Get-Content $LOG_PATH | %{ $_.Split(" ")[2]; } | Select-String ssh-agent

  # Remove log file
  Remove-Item $LOG_PATH

  # Make the decision
  if(!$state) {
    return 0
  } else {
    return 1
  }
}

# Install OpenSSH
function install {
  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
}

# Configure OpenSSH Client 
function configure {

  # Start automatically
  Set-Service ssh-agent -StartupType Automatic

  # Start the service
  Start-Service ssh-agent -PassThru
}

# generate RSA Key-Pair
function generateKeys {

  cd $home\.ssh

  # Generate public and private keys
  ssh-keygen.exe -t rsa
}

# Require root privilage
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  # Start new session with administrator privileges
  Start-Process powershell.exe -Verb RunAs -ArgumentList ("-noprofile -noexit -file $SCRIPT_PATH -elevated" -f ($myinvocation.MyCommand.Definition))
  Break
} else {
  # As administrator:
  
  $state = isOpenSSH
  if ($state -ne 1 ) {
    install
  }

  configure

  generateKeys

  # Send public key into the server
  cat .\id_rsa.pub | ssh $SSH_PATH 'cat >>.ssh/authorized_keys && chmod 600 .ssh/authorized_keys'

  # Close powershell terminal
  stop-process -Id $PID       # In $PID variable is Powershell terminal Process ID
}