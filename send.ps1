# Script sends selected file to server. 
# It demands '.sh' extension
# Reference to workdir

$address = "konrad@192.168.56.105:/home/konrad"                 # Destination address
$files = $args                    

if ($files.length -eq 0) {
    scp -r $pwd\'*.sh' $address
} else {
    foreach ($file in $files) {
        $extension = [IO.Path]::GetExtension($files)            # Valid file extension           
        if ($extension -eq ".sh") {   
            scp $pwd\$file $address                             # Demand passwd for each file
        } else {
            Write-Error 'Plik bez rozszerzenia .sh'
        }
    }
}