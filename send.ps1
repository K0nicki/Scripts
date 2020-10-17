# Script sends selected file to server. 
# Reference to workdir

# Usage: send [-ext extension] [-addr address] files (in win tab mode: ".\file" :) )

[CmdletBinding(DefaultParameterSetName='args')]
param (
    [Parameter()][string]$ext = "sh",                                           # Default extension for scripts
    [Parameter()][string]$addr = "konrad@192.168.56.105:/home/konrad",          # My VM address
    [Parameter(ValueFromRemainingArguments, ParameterSetName='args')]$files
)

# Cut path
function cutPath {
    param (
        $file
    )

    if ($file.SubString(0,2) -eq ".\") {
        return $file.SubString(2)                      
    } else {
        return $file
    }
}

# Validate extension and cut path 
function remakeFiles {
    param (
        $files
    )

    if ($files -is [array]) {
            
        $checked_files = New-Object string[] $files.length          
        $counter = 0

        foreach ($file in $files.split(" ")) {
            $extension = [IO.Path]::GetExtension($file)             # Validate file extension    
            if ($extension -eq ".$ext") {
                $file = cutPath $file
                $checked_files[$counter] = "$pwd\$file"
                $counter++
            }
        }
        return $checked_files
    } else {
        Write-Error "Illegal argument exception"
    }
}

# Transform string into array of strings
function toArray {
    param (
        $files
    )

    $countString = ($files.ToCharArray() | Where-Object {$_ -eq ' '} | Measure-Object).Count

    if ($countString -eq 0) {
        return @($files," ")
    } else {    
        return $files.split(" ")               
    }
}

# Upload files
function upload {
    param ($array)
    
    if ($null -eq $array[0]) {
        Write-Host "None of files fulfil the requirements"
    } else {
        cmd.exe /c scp -r $checked_files $addr                     # Upload all indicated files
    }
}

# Upload all files w/ appropriate extension in the workdir
function uploadAll {
    cmd.exe /c scp -r $pwd\*.$ext $addr                             # Upload all files w/ selected extension
}

# Validate files
function checkFiles {
    param (
        $files
    )
    $filesArr = toArray $files
    
    $checked_files = remakeFiles $filesArr          

    # Upload files
    upload $checked_files
}

# Upload files into the server
function run {
    param (
        $files
    )

    if ($files.length -eq 0) {
        uploadAll
    } else {
        checkFiles $files
    }
}

run $files
