@echo off
echo.
echo.    kvm upgrade
call     "%~dp0..\kvm" upgrade
echo.
echo.    kpm restore
call     kpm restore
echo.
echo.    k web --server Kestrel 
call     k web --server Kestrel
