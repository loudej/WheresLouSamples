@echo off
echo.
echo.    kvm upgrade
call     "%~dp0..\kvm" upgrade
echo.
echo.    kpm restore --source https://www.myget.org/F/aspnetvnext
call     kpm restore --source https://www.myget.org/F/aspnetvnext
echo.
echo.    k run
call     k run
echo.
echo.    k run --display:font:color Purple
call     k run --display:font:color Purple
echo.
echo.    set DISPLAY:FONT:SIZE=24pt
         set DISPLAY:FONT:SIZE=24pt  
echo.    k run
call     k run
