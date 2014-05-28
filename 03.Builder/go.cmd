@echo off
echo.
echo.    kvm upgrade
call     "%~dp0..\kvm" upgrade
echo.
echo.    kpm restore --source https://www.myget.org/F/aspnetvnext
call     kpm restore --source https://www.myget.org/F/aspnetvnext
echo.
echo.    k web
call     k web
