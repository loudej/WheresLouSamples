
cd "%~dp0..\packages\Microsoft.AspNet.Loader.IIS.Interop.*\tools"
mkdir "%~dp0\bin"
copy AspNet.Loader.dll "%~dp0\bin\AspNet.Loader.dll"
cd "%~dp0"
"C:\Program Files (x86)\IIS Express\iisexpress.exe" /port:5000 /path:.
