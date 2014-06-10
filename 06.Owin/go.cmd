@echo off
echo.
echo.    kvm upgrade
call     "%~dp0..\kvm" upgrade
echo.
echo.    kpm restore --source https://www.myget.org/F/aspnetvnext --source https://www.nuget.org/api/v2/
call     kpm restore --source https://www.myget.org/F/aspnetvnext --source https://www.nuget.org/api/v2/
echo.
echo.    k run
call     k run
