#!/usr/bin/env python3

# Change file formats in all given files to unix
import sys
import subprocess

# Check if dos2unix command is installed
def test_dos2unix() :
    result = subprocess.run(["whereis","dos2unix"], stdout=subprocess.PIPE).stdout.decode('utf-8')
    result = result.split(":", 1)[1]
    if result == "\n" :
        return 1
    else :
        return 0

check = test_dos2unix()

if check != 0 :
    subprocess.call(["sudo","apt","install","dos2unix","-y"])                   # Install dos2unix
    check = 0
else :
    if len(sys.argv) == 1 :
        files = [f for f in os.listdir('.') if os.path.isfile(f)]               # If there is no parameters, get all files in workdir
        for f in files:
            if (f[0] != ".") and ("./"+f != sys.argv[0]) and f.endswith('.sh'): # Change only not hidden *.sh files without itself
                subprocess.run(["dos2unix",f])
    else :
        for index in range(1, len(sys.argv)):                               
            subprocess.run(["dos2unix", sys.argv[index]])