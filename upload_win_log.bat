REM remove "/log=upload.log" ?
call upload_config.bat
winscp.com /log=upload.log /command ^
    "open ftpes://%USER%:%PASS%@%HOST%" ^
    "synchronize -criteria:time -transfer=auto -filemask=""| teaching/;things/;archive/"" remote ""%SOURCEFOLDER%\log\"" ""%TARGETFOLDER%\log\""" ^
    "close" ^
    "exit"