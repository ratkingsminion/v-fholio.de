REM remove "/log=upload.log" ?
call upload_config.bat
winscp.com /log=upload.log /command ^
    "open ftpes://%USER%:%PASS%@%HOST%" ^
    "synchronize -criteria:checksum -transfer=auto -filemask=""| teaching/;things/;archive/"" remote ""%SOURCEFOLDER%"" ""%TARGETFOLDER%""" ^
    "close" ^
    "exit"