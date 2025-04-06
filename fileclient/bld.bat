@echo off

cd %~dp0
chcp 65001
set VERSION=%1
echo "build %VERSION%..."

rem 处理版本号，将版本号写入到pubspec.yaml文件中
powershell -Command "(Get-Content pubspec.yaml) -replace 'version: .*', 'version: %VERSION%' | Set-Content pubspec.yaml"

set HTTPS_PROXY=http://10.0.2.22:7890
del /Q /S /F ..\dist\myfileclient_windows_x64
call flutter build windows --release
mkdir ..\dist\myfileclient_windows_x64
copy /Y cfg.json ..\dist\myfileclient_windows_x64
xcopy /E /K /Y build\windows\x64\runner\Release\* ..\dist\myfileclient_windows_x64
cd ..\dist
"C:\Program Files\7-Zip\7z.exe" a "myfileclient_windows_x64.7z" myfileclient_windows_x64

cd %~dp0
set path=%path%;"C:\Program Files (x86)\Inno Setup 6"
ISCC.exe /F"myfileclient_windows_x64" setup.iss